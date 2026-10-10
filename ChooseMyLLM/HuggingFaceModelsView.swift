import SwiftUI

struct HuggingFaceModelsView: View {
    let requirements: UserRequirements
    @AppStorage("selectedHFModelID") private var selectedID = ""
    @State private var search = ""
    @State private var sort = "downloads"
    @State private var task = "text-generation"
    @State private var chineseOnly = false
    @State private var query = HFQuery()
    @State private var refreshID = UUID()
    @State private var snapshot: HFSnapshot?
    @State private var isLoading = false
    @State private var source = ""
    @State private var notice: String?
    @State private var initialized = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Hugging Face model library", systemImage: "network")
                .font(.title3.bold())

            Text("Search public model repositories and choose one to keep. Hardware fit, speed, answer quality, and free cloud hosting are not verified by these results.")
                .font(.callout)
                .foregroundStyle(.secondary)

            if requirements.deployment == .cloud {
                Text("A Hub repository does not guarantee a hosted API. Check the model page for inference providers and pricing.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack {
                TextField("Search a model or author, e.g. Qwen", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { submitSearch() }
                Button("Search") { submitSearch() }
                    .buttonStyle(.borderedProminent)
                Button { submitSearch() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh from Hugging Face")
                .accessibilityLabel("Refresh models")
            }

            HStack {
                Picker("Sort", selection: $sort) {
                    Text("Downloads").tag("downloads")
                    Text("Likes").tag("likes")
                    Text("Recently updated").tag("lastModified")
                }
                Picker("Task", selection: $task) {
                    Text("Text generation").tag("text-generation")
                    Text("Image + text").tag("image-text-to-text")
                }
            }
            Toggle("Only models tagged Chinese (zh)", isOn: $chineseOnly)
                .font(.callout)
            Text("Press Search to apply. Missing language tags can exclude models that still support Chinese. Popularity is not a quality ranking.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !selectedID.isEmpty {
                HStack(alignment: .top) {
                    Label("Selected: \(selectedID)", systemImage: "checkmark.circle.fill")
                        .font(.callout)
                        .textSelection(.enabled)
                    Spacer()
                    Button("Clear") { selectedID = "" }
                }
                .padding(12)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }

            if isLoading { ProgressView("Contacting Hugging Face…").controlSize(.small) }
            if let notice {
                Label(notice, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if let snapshot {
                Text("\(source) · \(snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened)) · \(snapshot.models.count) models")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Applied search: \(snapshot.query.search.isEmpty ? "All models" : snapshot.query.search) · \(snapshot.query.task) · \(snapshot.query.sort)\(snapshot.query.chineseOnly ? " · zh" : "")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if snapshot.models.isEmpty && !isLoading {
                    ContentUnavailableView("No models found", systemImage: "magnifyingglass", description: Text("Try a shorter search or turn off the Chinese tag filter. Offline results only cover the bundled snapshot or a previously cached search."))
                }
                ForEach(snapshot.models) { model in
                    modelCard(model)
                }
                Text("Shows up to 30 results per search. Search terms and tag filters are sent to huggingface.co; your device and budget selections are not sent.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !isLoading {
                Button("Retry connection") { submitSearch() }
            }
        }
        .onAppear {
            guard !initialized else { return }
            initialized = true
            search = requirements.useCase == .coding ? "coder" : ""
            chineseOnly = requirements.needsChinese
            submitSearch()
        }
        .task(id: refreshID) {
            guard initialized else { return }
            await load(query)
        }
    }

    private func submitSearch() {
        query = HFQuery(search: String(search.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200)), sort: sort, task: task, chineseOnly: chineseOnly)
        refreshID = UUID()
    }

    private func load(_ requestedQuery: HFQuery) async {
        isLoading = true
        notice = nil
        snapshot = HuggingFaceClient.cached(requestedQuery)
        source = "Cached HF results"
        do {
            let latest = try await HuggingFaceClient.fetch(requestedQuery)
            try Task.checkCancellation()
            snapshot = latest
            source = "Live from Hugging Face"
            do { try HuggingFaceClient.save(latest) }
            catch { notice = "Live results loaded, but the offline cache could not be saved." }
        } catch {
            guard !Task.isCancelled else { return }
            if snapshot == nil {
                snapshot = HuggingFaceClient.bundled(requestedQuery)
                source = "Bundled HF snapshot"
            }
            notice = "Could not refresh: \(error.localizedDescription) Showing saved data when available."
        }
        isLoading = false
    }

    private func modelCard(_ model: HFModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.id)
                .font(.headline)
                .textSelection(.enabled)
            HStack(spacing: 18) {
                Label((model.downloads ?? 0).formatted(), systemImage: "arrow.down.circle")
                Label((model.likes ?? 0).formatted(), systemImage: "heart")
                if let total = model.safetensors?.total {
                    Text("HF parameters: \(total.formatted(.number.notation(.compactName)))")
                        .help("Reported safetensors count. Quantized or auxiliary tensors can differ from the advertised model size.")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text("License: \(model.license) · Updated \(String((model.lastModified ?? "Unknown").prefix(10)))")
                .font(.caption)
                .foregroundStyle(.secondary)
            if model.requiresAccess {
                Label("Access approval or license acceptance required on HF", systemImage: "lock")
                    .font(.caption)
            }
            Text("Memory fit and serving cost: not verified. Check the model card and the exact model files before use.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Link("View on Hugging Face ↗", destination: model.pageURL)
                Spacer()
                Button(selectedID == model.id ? "Selected" : "Choose model") {
                    selectedID = model.id
                }
                .disabled(selectedID == model.id)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(selectedID == model.id ? Color.accentColor : Color.primary.opacity(0.1))
        }
    }
}
