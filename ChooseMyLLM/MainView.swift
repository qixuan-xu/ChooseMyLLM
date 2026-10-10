import SwiftUI

struct MainView: View {
    @State private var requirements = UserRequirements()
    @State private var step: SetupStep = .purpose
    @State private var submittedRequirements: UserRequirements?

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(spacing: 0) {
                header
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if let submittedRequirements {
                            results(for: submittedRequirements)
                        } else {
                            stepContent
                        }
                    }
                    .frame(maxWidth: 640, alignment: .leading)
                    .padding(32)
                    .frame(maxWidth: .infinity)
                }
                .id(submittedRequirements == nil ? step.rawValue : "results")
                Divider()
                footer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 28) {
            Label(AppConfiguration.displayName, systemImage: "globe")
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 8) {
                Text("FIND YOUR MODEL")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 6)

                ForEach(SetupStep.allCases) { item in
                    Button {
                        submittedRequirements = nil
                        step = item
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: item.symbol)
                                .frame(width: 18)
                            Text(item.rawValue)
                            Spacer()
                        }
                        .padding(10)
                        .contentShape(Rectangle())
                        .background(
                            step == item && submittedRequirements == nil
                                ? Color.accentColor.opacity(0.12) : .clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(step == item && submittedRequirements == nil ? .isSelected : [])
                }

                Label("Results", systemImage: "sparkles")
                    .foregroundStyle(submittedRequirements == nil ? .secondary : .primary)
                    .padding(10)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 6) {
                Label("Device details stay on this Mac", systemImage: "lock")
                    .font(.caption)
                Text("Version \(AppConfiguration.version)")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 220)
        .frame(maxHeight: .infinity)
        .background(.bar)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(submittedRequirements == nil ? "STEP \(step.number) OF 3" : "YOUR SETUP")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(submittedRequirements == nil ? step.title : "Your recommended models")
                    .font(.system(size: 25, weight: .semibold))
            }
            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .purpose:
            Text("What will you use an LLM for most often?")
                .foregroundStyle(.secondary)
            ForEach(ModelUseCase.allCases) { useCase in
                Button {
                    requirements.useCase = useCase
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: useCase.symbol)
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(useCase.rawValue).font(.headline)
                            Text(useCase.detail)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: requirements.useCase == useCase ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(requirements.useCase == useCase ? Color.accentColor : .secondary)
                    }
                    .padding(18)
                    .background(.background, in: RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(requirements.useCase == useCase ? Color.accentColor : Color.primary.opacity(0.1))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(requirements.useCase == useCase ? .isSelected : [])
            }
        case .device:
            settingsCard("Where should the model run?") {
                Picker("Run location", selection: $requirements.deployment) {
                    ForEach(ModelDeployment.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text("Local models run on your device. Cloud models need an internet connection and send requests to a provider.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if requirements.deployment != .cloud {
                settingsCard("Your Mac") {
                    LabeledContent("Operating system", value: "macOS")
                    Picker("Chip", selection: $requirements.macChip) {
                        ForEach(MacChip.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Memory", selection: $requirements.memoryGB) {
                        ForEach(Array(Set([8, 16, 18, 24, 32, 36, 48, 64, 96, 128, 192, 256, 512, requirements.memoryGB])).sorted(), id: \.self) {
                            Text("\($0) GB").tag($0)
                        }
                    }
                    Text("Detected this Mac for you. Change these values if you are choosing for another machine.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        case .preferences:
            settingsCard("What matters most?") {
                Picker("Priority", selection: $requirements.priority) {
                    ForEach(ModelPriority.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text("Choose faster responses, stronger answers, or a balance of both.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            settingsCard("A few more preferences") {
                Toggle("Prefer models on our Chinese-focused shortlist", isOn: $requirements.needsChinese)
                Divider()
                Toggle("Only show free options", isOn: $requirements.mustBeFree)
                Text("Free local weights exclude hardware costs. We do not currently have a verified free cloud tier in the recommended shortlist.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func results(for snapshot: UserRequirements) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            RecommendationResultsView(requirements: snapshot)

            DisclosureGroup("Your preferences") {
                LabeledContent("Main use", value: snapshot.useCase.rawValue)
                Divider()
                LabeledContent("Run location", value: snapshot.deployment.rawValue)
                if snapshot.deployment != .cloud {
                    LabeledContent("Chip", value: snapshot.macChip.rawValue)
                    LabeledContent("Mac memory", value: "\(snapshot.memoryGB) GB")
                }
                LabeledContent("Priority", value: snapshot.priority.rawValue)
                LabeledContent("Chinese support", value: snapshot.needsChinese ? "Required" : "No preference")
                LabeledContent("Budget", value: snapshot.mustBeFree ? "Free options" : "Free and paid options")
            }

        }
    }

    private var footer: some View {
        HStack {
            if submittedRequirements != nil {
                Button("Edit preferences") { submittedRequirements = nil }
            } else if step != .purpose {
                Button("Back") { step = step == .preferences ? .device : .purpose }
            }
            Spacer()
            if submittedRequirements == nil {
                Button(step == .preferences ? "Find my model" : "Continue") {
                    switch step {
                    case .purpose: step = .device
                    case .device: step = .preferences
                    case .preferences: submittedRequirements = requirements
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .controlSize(.large)
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
    }

    private func settingsCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title).font(.headline)
            content()
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.08))
        }
    }
}

private enum SetupStep: String, CaseIterable, Identifiable {
    case purpose = "Purpose"
    case device = "Device"
    case preferences = "Preferences"
    var id: Self { self }
    var number: Int {
        switch self { case .purpose: 1; case .device: 2; case .preferences: 3 }
    }
    var symbol: String {
        switch self { case .purpose: "square.grid.2x2"; case .device: "desktopcomputer"; case .preferences: "slider.horizontal.3" }
    }
    var title: String {
        switch self {
        case .purpose: "A model that fits your work."
        case .device: "Make it work for your setup."
        case .preferences: "Choose what matters to you."
        }
    }
}

#Preview {
    MainView()
        .frame(width: 960, height: 700)
}
