import SwiftUI
import AppKit

struct RecommendationResultsView: View {
    let requirements: UserRequirements
    @AppStorage("selectedHFModelID") private var selectedID = ""
    @State private var catalog: RecommendationCatalog?
    @State private var errorMessage: String?
    @State private var checking = false
    @State private var syncMessage = "Using saved HF data"
    @State private var showingBrowser = false
    @State private var setupPick: ModelPick?
    @State private var refreshID = UUID()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("\(requirements.useCase.rawValue) · \(requirements.deployment == .cloud ? "Cloud" : "\(requirements.memoryGB) GB Mac") · \(requirements.priority.rawValue)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Browse HF") { showingBrowser = true }
                    .buttonStyle(.borderless)
            }

            if let catalog {
                let result = ModelRecommender.recommend(requirements, catalog: catalog)
                if let first = result.picks.first {
                    recommendationCard(first, primary: true)
                    if result.picks.count > 1 {
                        Text("Also worth considering").font(.headline).padding(.top, 8)
                        ForEach(Array(result.picks.dropFirst())) { pick in
                            recommendationCard(pick, primary: false)
                        }
                    }
                } else {
                    ContentUnavailableView {
                        Label("No suitable match in this shortlist", systemImage: "slider.horizontal.3")
                    } description: {
                        Text(emptyMessage)
                    }
                }

                HStack(spacing: 8) {
                    if checking { ProgressView().controlSize(.small) }
                    Text(checking ? "Checking model availability on HF…" : syncMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Refresh") { refreshID = UUID() }.disabled(checking)
                        .buttonStyle(.borderless)
                }

                DisclosureGroup("How we chose these models") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("This is a checked shortlist of \(catalog.profiles.count) candidates, not all of Hugging Face. We exclude incompatible locations, memory requirements, access restrictions, and options without a verified free tier when free-only is selected.")
                        Text("HF supplies model files, their sizes, access status, and hosted-provider availability. Our own curated ratings determine task fit and the speed/quality tradeoff; they are not benchmark measurements. Downloads and likes do not decide the ranking.")
                        Text("Local memory estimates assume Apple silicon, the named quantization, short text conversations around 4K context, and 5 GiB of additional headroom. More context, images, and other apps can need more memory. The Chinese preference uses a curated shortlist rather than relying on incomplete HF tags.")
                        Text("Only model IDs are sent to HF for these checks. Your device details stay on this Mac.")
                        if !result.exclusions.isEmpty {
                            ForEach(result.exclusions.keys.sorted(), id: \.self) { reason in
                                Text("\(reason): \(result.exclusions[reason, default: 0]) excluded")
                            }
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                }
            } else if let errorMessage {
                ContentUnavailableView("Could not load recommendations", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                Button("Retry") { refreshID = UUID() }
            } else {
                ProgressView("Finding models for you…")
            }
        }
        .task(id: refreshID) { await loadAndRefresh() }
        .sheet(isPresented: $showingBrowser) {
            VStack(spacing: 0) {
                HStack {
                    Text("Explore Hugging Face").font(.headline)
                    Spacer()
                    Button("Done") { showingBrowser = false }.keyboardShortcut(.cancelAction)
                }.padding(20)
                Divider()
                ScrollView {
                    HuggingFaceModelsView(requirements: requirements).padding(24)
                }
            }.frame(width: 740, height: 620)
        }
        .sheet(item: $setupPick) { pick in
            ModelSetupView(pick: pick)
        }
    }

    private var emptyMessage: String {
        if requirements.deployment == .cloud && requirements.mustBeFree {
            return "We have not verified a free hosted tier for these HF models. Edit your preferences to allow paid cloud options or consider running a model locally."
        }
        if requirements.deployment == .local && requirements.macChip != .appleSilicon {
            return "This local shortlist is checked for Apple silicon Macs. Intel compatibility has not been assessed. You can edit your setup or browse HF manually."
        }
        return "No candidate meets all your selected conditions. Edit your preferences or browse HF for more options. We have kept your filters in place."
    }

    private func recommendationCard(_ pick: ModelPick, primary: Bool) -> some View {
        VStack(alignment: .leading, spacing: primary ? 18 : 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    if primary {
                        Label("START WITH THIS", systemImage: "sparkles")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                    }
                    Text(pick.profile.name).font(primary ? .title2.bold() : .headline)
                }
                Spacer()
                Text(pick.profile.location == .local ? "ON YOUR MAC" : "CLOUD")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.1), in: Capsule())
            }

            Text(pick.reason).font(.callout)
            if primary {
                Label(pick.preferenceReason, systemImage: "checkmark.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                if let memory = pick.memoryGB {
                    Label("Est. \(memory) GB+ RAM", systemImage: "memorychip")
                }
                Text(pick.profile.variant)
                Text(pick.profile.freeToUse ? "Free weights" : "Provider charges apply")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(pick.profile.tradeoff)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button(selectedID == pick.id ? "Selected · Setup" : "Choose & see setup") {
                    selectedID = pick.id
                    setupPick = pick
                }
                .buttonStyle(.borderedProminent)
                .controlSize(primary ? .large : .regular)
                Spacer()
                Link("Model page ↗", destination: pick.profile.pageURL)
                    .font(.callout)
            }
        }
        .padding(primary ? 26 : 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(primary ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.1))
        }
    }

    private func loadAndRefresh() async {
        do {
            var loaded = try RecommendationCatalog.load()
            for (id, record) in RecommendationSync.cachedRecords() {
                if let prior = loaded.records[id], record.model.id == id, record.checkedAt > prior.checkedAt {
                    loaded.records[id] = record
                }
            }
            catalog = loaded
            errorMessage = nil
            checking = true
            let profiles = loaded.profiles.filter { requirements.deployment == .either || $0.location == requirements.deployment }
            var refreshed = 0
            await withTaskGroup(of: SyncUpdate.self) { group in
                for profile in profiles {
                    group.addTask { @MainActor in
                        do {
                            return SyncUpdate(id: profile.id, record: try await RecommendationSync.refresh(profile), unavailable: false)
                        } catch HFClientError.http(let status) where [401, 403, 404, 410].contains(status) {
                            return SyncUpdate(id: profile.id, record: nil, unavailable: true)
                        } catch {
                            return SyncUpdate(id: profile.id, record: nil, unavailable: false)
                        }
                    }
                }
                for await update in group {
                    guard !Task.isCancelled else { group.cancelAll(); return }
                    if let record = update.record {
                        loaded.records[update.id] = record
                        refreshed += 1
                    } else if update.unavailable, let prior = loaded.records[update.id] {
                        loaded.records[update.id] = RecommendationRecord(model: prior.model, checkedAt: Date(), unavailable: true)
                        refreshed += 1
                    }
                }
            }
            guard !Task.isCancelled else { return }
            catalog = loaded
            let oldest = profiles.compactMap { loaded.records[$0.id]?.checkedAt }.min()
            let date = oldest?.formatted(date: .abbreviated, time: .omitted) ?? "unknown date"
            syncMessage = refreshed == profiles.count
                ? "Model availability checked on HF just now"
                : "Using saved data where HF could not be reached · oldest check \(date)"
            do { try RecommendationSync.save(loaded.records) }
            catch { syncMessage += " · Cache could not be saved" }
            checking = false
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
            checking = false
        }
    }
}

private struct SyncUpdate: Sendable {
    let id: String
    let record: RecommendationRecord?
    let unavailable: Bool
}

private struct ModelSetupView: View {
    let pick: ModelPick
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(pick.profile.name).font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Label("Saved as your selected model", systemImage: "checkmark.circle.fill")
                .foregroundStyle(Color.accentColor)
            if let command = pick.profile.ollamaCommand {
                Text("1. Open or install Ollama on your Mac.")
                Link("Ollama for macOS ↗", destination: URL(string: "https://ollama.com/download/mac")!)
                Text("2. Paste this command into Terminal to download and run the recommended variant.")
                Text(command)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                Button(copied ? "Copied" : "Copy command") {
                    NSPasteboard.general.clearContents()
                    copied = NSPasteboard.general.setString(command, forType: .string)
                }
                Text("This app has not downloaded or started the model. The command can download several GB. Start with a short conversation; memory estimates are not a guarantee.")
                    .font(.caption).foregroundStyle(.secondary)
                Link("Exact model files on HF ↗", destination: pick.profile.filesURL)
            } else {
                Text("Open the model page and select an Inference Provider. Account setup and billing happen with the provider.")
                Text("Listed providers: \(pick.record.model.providers.joined(separator: ", "))")
                    .font(.callout).foregroundStyle(.secondary)
                Link("Open model and providers ↗", destination: pick.profile.pageURL)
            }
            Text("HF data checked \(pick.record.checkedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 600)
    }
}
