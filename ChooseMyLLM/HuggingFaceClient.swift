import Foundation
import CryptoKit

struct HFModel: Codable, Identifiable, Sendable {
    let id: String
    let downloads: Int?
    let likes: Int?
    let tags: [String]?
    let lastModified: String?
    let pipeline_tag: String?
    let safetensors: TensorInfo?
    let gated: AccessGate?

    struct TensorInfo: Codable, Sendable { let total: Int64? }
    enum AccessGate: Codable, Sendable {
        case open, restricted
        init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer()
            if let flag = try? value.decode(Bool.self) {
                self = flag ? .restricted : .open
            } else {
                let flag = try value.decode(String.self)
                self = flag == "false" ? .open : .restricted
            }
        }
        func encode(to encoder: Encoder) throws {
            var value = encoder.singleValueContainer()
            try value.encode(self == .restricted)
        }
    }

    var license: String {
        tags?.first(where: { $0.hasPrefix("license:") }).map { String($0.dropFirst(8)) } ?? "Not specified"
    }
    var requiresAccess: Bool { gated == .restricted }
    var pageURL: URL {
        URL(string: "https://huggingface.co")!.appendingPathComponent(id)
    }
}

struct HFQuery: Codable, Hashable, Sendable {
    var search = ""
    var sort = "downloads"
    var task = "text-generation"
    var chineseOnly = false

    var url: URL {
        var components = URLComponents(string: "https://huggingface.co/api/models")!
        var items = [
            URLQueryItem(name: "search", value: search.trimmingCharacters(in: .whitespacesAndNewlines)),
            URLQueryItem(name: "pipeline_tag", value: task),
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "direction", value: "-1"),
            URLQueryItem(name: "limit", value: "30")
        ]
        if chineseOnly { items.append(URLQueryItem(name: "filter", value: "zh")) }
        for field in ["downloads", "likes", "tags", "lastModified", "gated", "pipeline_tag", "safetensors"] {
            items.append(URLQueryItem(name: "expand[]", value: field))
        }
        components.queryItems = items
        return components.url!
    }
}

struct HFSnapshot: Codable, Sendable {
    let query: HFQuery
    let fetchedAt: Date
    let models: [HFModel]
}

enum HFClientError: LocalizedError {
    case http(Int)
    case invalidResponse
    var errorDescription: String? {
        switch self {
        case .http(429): "Hugging Face is rate limiting requests. Wait a moment, then retry."
        case .http(let status): "Hugging Face returned HTTP \(status). Please try again later."
        case .invalidResponse: "Hugging Face returned an unexpected response."
        }
    }
}

enum HuggingFaceClient {
    static func fetch(_ query: HFQuery, session: URLSession = .shared) async throws -> HFSnapshot {
        var request = URLRequest(url: query.url)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw HFClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw HFClientError.http(http.statusCode) }
        let models = try JSONDecoder().decode([HFModel].self, from: data)
        guard models.count <= 100,
              Set(models.map(\.id)).count == models.count,
              models.allSatisfy({ !$0.id.isEmpty && !$0.id.contains("..") }) else {
            throw HFClientError.invalidResponse
        }
        return HFSnapshot(query: query, fetchedAt: Date(), models: models)
    }

    static func cached(_ query: HFQuery, directory: URL? = nil) -> HFSnapshot? {
        guard let url = try? cacheURL(query, directory: directory),
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(HFSnapshot.self, from: data),
              snapshot.query == query else { return nil }
        return snapshot
    }

    static func save(_ snapshot: HFSnapshot, directory: URL? = nil) throws {
        let url = try cacheURL(snapshot.query, directory: directory)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
        // Bound this app-owned cache to the 20 most recently written searches.
        let files = try FileManager.default.contentsOfDirectory(at: url.deletingLastPathComponent(), includingPropertiesForKeys: [.contentModificationDateKey])
            .filter { $0.pathExtension == "json" }
            .sorted {
                ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast)
                    > ((try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast)
            }
        for file in files.dropFirst(20) { try? FileManager.default.removeItem(at: file) }
    }

    static func bundled(_ query: HFQuery, bundle: Bundle = .main) -> HFSnapshot? {
        guard let url = bundle.url(forResource: "hf-offline-models", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let seed = try? JSONDecoder().decode(HFSnapshot.self, from: data) else { return nil }
        var matches = seed.models.filter {
            ($0.pipeline_tag == query.task)
                && (query.search.isEmpty || $0.id.localizedCaseInsensitiveContains(query.search))
                && (!query.chineseOnly || ($0.tags ?? []).contains("zh"))
        }
        matches.sort {
            if query.sort == "lastModified" { return ($0.lastModified ?? "") > ($1.lastModified ?? "") }
            if query.sort == "likes" { return ($0.likes ?? 0) > ($1.likes ?? 0) }
            return ($0.downloads ?? 0) > ($1.downloads ?? 0)
        }
        return HFSnapshot(query: query, fetchedAt: seed.fetchedAt, models: matches)
    }

    private static func cacheURL(_ query: HFQuery, directory: URL?) throws -> URL {
        let root: URL
        if let directory { root = directory } else {
            root = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("ChooseMyLLM/HuggingFace-v1", isDirectory: true)
        }
        let key = SHA256.hash(data: Data(query.url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        return root.appendingPathComponent(key + ".json")
    }
}
