import Foundation

struct RecommendationCatalog: Codable, Sendable {
    let profiles: [RecommendationProfile]
    var records: [String: RecommendationRecord]

    static func load(bundle: Bundle = .main) throws -> Self {
        guard let url = bundle.url(forResource: "recommendation-catalog", withExtension: "json") else {
            throw HFClientError.invalidResponse
        }
        let catalog = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        guard !catalog.profiles.isEmpty,
              Set(catalog.profiles.map(\.id)).count == catalog.profiles.count,
              catalog.profiles.allSatisfy({ profile in
                  catalog.records[profile.id]?.model.id == profile.id
                      && ModelUseCase.allCases.allSatisfy { (1...5).contains(profile.taskFit[$0.rawValue] ?? 0) }
                      && (1...5).contains(profile.speed)
                      && (1...5).contains(profile.quality)
                      && (profile.location == .cloud || (!profile.files.isEmpty && profile.minimumMemoryGB > 0))
              }) else { throw HFClientError.invalidResponse }
        return catalog
    }
}

struct RecommendationProfile: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let location: ModelDeployment
    let files: [String]
    let variant: String
    let minimumMemoryGB: Int
    let chineseFocused: Bool
    let freeToUse: Bool
    let speed: Int
    let quality: Int
    let taskFit: [String: Int]
    let strength: String
    let tradeoff: String

    var pageURL: URL { URL(string: "https://huggingface.co")!.appendingPathComponent(id) }
    var filesURL: URL { pageURL.appendingPathComponent("tree/main") }
    var ollamaCommand: String? {
        location == .local ? "ollama run hf.co/\(id):\(variant)" : nil
    }
}

struct RecommendationMetadata: Codable, Sendable {
    let id: String
    let gated: HFModel.AccessGate?
    let siblings: [ModelFile]?
    let inferenceProviderMapping: [String: Provider]?

    struct ModelFile: Codable, Sendable {
        let rfilename: String
        let size: Int64?
    }
    struct Provider: Codable, Sendable {
        let status: String?
        let task: String?
    }
    var providers: [String] {
        (inferenceProviderMapping ?? [:]).filter {
            $0.value.status == "live" && ["conversational", "text-generation"].contains($0.value.task ?? "")
        }.keys.sorted()
    }
}

struct RecommendationRecord: Codable, Sendable {
    let model: RecommendationMetadata
    let checkedAt: Date
    var unavailable = false

    func fileBytes(for profile: RecommendationProfile) -> Int64? {
        var total: Int64 = 0
        for name in profile.files {
            guard let size = model.siblings?.first(where: { $0.rfilename == name })?.size,
                  size > 0, size < 1_000_000_000_000 else { return nil }
            total += size
        }
        return profile.files.isEmpty ? nil : total
    }
}

struct ModelPick: Identifiable {
    let profile: RecommendationProfile
    let record: RecommendationRecord
    let score: Int
    let memoryGB: Int?
    let reason: String
    let preferenceReason: String
    var id: String { profile.id }
}

struct RecommendationOutcome {
    let picks: [ModelPick]
    let exclusions: [String: Int]
}

enum ModelRecommender {
    static func recommend(_ needs: UserRequirements, catalog: RecommendationCatalog) -> RecommendationOutcome {
        var picks: [ModelPick] = []
        var excluded: [String: Int] = [:]
        for profile in catalog.profiles {
            guard let record = catalog.records[profile.id] else { continue }
            let bytes = record.fileBytes(for: profile)
            // A conservative short-text estimate: model files + 5 GiB for macOS/runtime/context.
            // The curated floor can be higher for architectures with larger runtime overhead.
            let memory = bytes.map { max(profile.minimumMemoryGB, Int(ceil(Double($0) / 1_073_741_824 + 5))) }
            let reason: String?
            if needs.deployment != .either && needs.deployment != profile.location {
                reason = "Different run location"
            } else if needs.mustBeFree && !profile.freeToUse {
                reason = "No verified free hosted tier"
            } else if needs.needsChinese && !profile.chineseFocused {
                reason = "Outside the Chinese-focused shortlist"
            } else if record.unavailable || record.model.gated == .restricted {
                reason = "Currently unavailable or requires approval"
            } else if profile.location == .local && needs.macChip != .appleSilicon {
                reason = "Local shortlist requires Apple silicon"
            } else if profile.location == .local && (memory == nil || needs.memoryGB < memory!) {
                reason = "Insufficient memory or unverified model files"
            } else if profile.location == .cloud && record.model.providers.isEmpty {
                reason = "No active HF inference provider found"
            } else { reason = nil }
            if let reason { excluded[reason, default: 0] += 1; continue }

            let weights: (Int, Int)
            let preferenceReason: String
            switch needs.priority {
            case .speed:
                weights = (6, 1)
                preferenceReason = "Your speed preference favors lighter models in this shortlist."
            case .balanced:
                weights = (3, 3)
                preferenceReason = "Your preference balances response speed and answer quality."
            case .quality:
                weights = (1, 6)
                preferenceReason = "Your quality preference gives more weight to answer capability."
            }
            let score = (profile.taskFit[needs.useCase.rawValue] ?? 1) * 5
                + profile.speed * weights.0 + profile.quality * weights.1
            picks.append(ModelPick(profile: profile, record: record, score: score, memoryGB: memory,
                                  reason: profile.strength, preferenceReason: preferenceReason))
        }
        picks.sort {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.profile.speed != $1.profile.speed { return $0.profile.speed > $1.profile.speed }
            return $0.id < $1.id
        }
        return RecommendationOutcome(picks: Array(picks.prefix(3)), exclusions: excluded)
    }
}

enum RecommendationSync {
    static func refresh(_ profile: RecommendationProfile) async throws -> RecommendationRecord {
        let base = URL(string: "https://huggingface.co/api/models")!.appendingPathComponent(profile.id)
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        components.queryItems = profile.location == .local
            ? [URLQueryItem(name: "blobs", value: "true")]
            : [URLQueryItem(name: "expand[]", value: "inferenceProviderMapping"), URLQueryItem(name: "expand[]", value: "gated")]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else { throw HFClientError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else { throw HFClientError.http(response.statusCode) }
        let details = try JSONDecoder().decode(RecommendationMetadata.self, from: data)
        guard details.id == profile.id else { throw HFClientError.invalidResponse }
        return RecommendationRecord(model: details, checkedAt: Date())
    }

    static func cachedRecords() -> [String: RecommendationRecord] {
        guard let url = try? cacheURL(), let data = try? Data(contentsOf: url),
              let records = try? JSONDecoder().decode([String: RecommendationRecord].self, from: data) else { return [:] }
        return records
    }
    static func save(_ records: [String: RecommendationRecord]) throws {
        let url = try cacheURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(records).write(to: url, options: .atomic)
    }
    private static func cacheURL() throws -> URL {
        try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("ChooseMyLLM/Recommended-v1/records.json")
    }
}
