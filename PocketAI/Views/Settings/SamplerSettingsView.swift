import SwiftUI

struct SamplerSettingsView: View {

    @Environment(ServiceContainer.self) private var serviceContainer
    @Environment(\.appTheme) private var appTheme
    @State private var userStopSequenceText = ""
    @State private var botStopSequenceText = ""
    @State private var systemStopSequenceText = ""
    @State private var thinkingStartSequenceText = ""
    @State private var thinkingStopSequenceText = ""
    @State private var forceThinkingInstructText = ""
    @State private var samplerOrderText = ""
    @State private var isAdvancedSamplingExpanded = false

    private var connectionManager: ConnectionStatusManager {
        serviceContainer.getConnectionStatusManager()
    }

    private var forceThinkingBinding: Binding<Bool> {
        Binding(
            get: { connectionManager.connectionSettings.forceThinking },
            set: { connectionManager.update(\.forceThinking, to: $0) }
        )
    }

    private var temperatureBinding: Binding<Double> {
        Binding(
            get: { connectionManager.connectionSettings.temperature },
            set: { connectionManager.update(\.temperature, to: $0) }
        )
    }

    private var topPBinding: Binding<Double> {
        Binding(
            get: { connectionManager.connectionSettings.topP },
            set: { connectionManager.update(\.topP, to: $0) }
        )
    }

    private var topKBinding: Binding<Double> {
        Binding(
            get: { connectionManager.connectionSettings.topK },
            set: { connectionManager.update(\.topK, to: $0) }
        )
    }

    private var typicalPBinding: Binding<Double> {
        Binding(
            get: { connectionManager.connectionSettings.typicalP },
            set: { connectionManager.update(\.typicalP, to: $0) }
        )
    }

    private var tfsBinding: Binding<Double> {
        Binding(
            get: { Double(connectionManager.connectionSettings.tfs) },
            set: { connectionManager.update(\.tfs, to: Int($0)) }
        )
    }

    private var topABinding: Binding<Double> {
        Binding(
            get: { connectionManager.connectionSettings.topA },
            set: { connectionManager.update(\.topA, to: $0) }
        )
    }

    private var minPBinding: Binding<Double> {
        Binding(
            get: { connectionManager.connectionSettings.minP },
            set: { connectionManager.update(\.minP, to: $0) }
        )
    }

    private var repetitionPenaltyBinding: Binding<Double> {
        Binding(
            get: { connectionManager.connectionSettings.repetitionPenalty },
            set: { connectionManager.update(\.repetitionPenalty, to: $0) }
        )
    }

    private var repetitionRangeBinding: Binding<Double> {
        Binding(
            get: { Double(connectionManager.connectionSettings.repetitionRange) },
            set: { connectionManager.update(\.repetitionRange, to: Int($0)) }
        )
    }

    private var repetitionSlopeBinding: Binding<Double> {
        Binding(
            get: { connectionManager.connectionSettings.repetitionSlope },
            set: { connectionManager.update(\.repetitionSlope, to: $0) }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsCard("Sampling") {
                    Text("Temperature is the main control most people should adjust. Advanced controls can stay at their defaults unless you are tuning a specific model.")
                        .font(.caption)
                        .foregroundStyle(appTheme.secondaryText.color)

                    SamplerSlider(
                        title: "Temperature",
                        value: temperatureBinding,
                        range: 0.1...2,
                        step: 0.05,
                        displayValue: formattedDecimal(temperatureBinding.wrappedValue)
                    )

                    Divider()

                    DisclosureGroup(isExpanded: $isAdvancedSamplingExpanded) {
                        VStack(alignment: .leading, spacing: 14) {
                            SamplerSlider(
                                title: "Top P",
                                value: topPBinding,
                                range: 0...1,
                                step: 0.05,
                                displayValue: formattedDecimal(topPBinding.wrappedValue)
                            )

                            SamplerSlider(
                                title: "Top K",
                                value: topKBinding,
                                range: 0...200,
                                step: 1,
                                displayValue: "\(Int(topKBinding.wrappedValue))"
                            )

                            SamplerSlider(
                                title: "Typical P",
                                value: typicalPBinding,
                                range: 0...1,
                                step: 0.05,
                                displayValue: formattedDecimal(typicalPBinding.wrappedValue)
                            )

                            SamplerSlider(
                                title: "TFS",
                                value: tfsBinding,
                                range: 0...1,
                                step: 1,
                                displayValue: "\(Int(tfsBinding.wrappedValue))"
                            )

                            SamplerSlider(
                                title: "Top A",
                                value: topABinding,
                                range: 0...1,
                                step: 0.05,
                                displayValue: formattedDecimal(topABinding.wrappedValue)
                            )

                            SamplerSlider(
                                title: "Min P",
                                value: minPBinding,
                                range: 0...1,
                                step: 0.005,
                                displayValue: formattedDecimal(minPBinding.wrappedValue)
                            )

                            SamplerSlider(
                                title: "Repetition Penalty",
                                value: repetitionPenaltyBinding,
                                range: 1...2,
                                step: 0.01,
                                displayValue: formattedDecimal(repetitionPenaltyBinding.wrappedValue)
                            )

                            SamplerSlider(
                                title: "Repetition Range",
                                value: repetitionRangeBinding,
                                range: 0...Double(connectionManager.connectionSettings.contextLength ?? 4096),
                                step: 64,
                                displayValue: "\(Int(repetitionRangeBinding.wrappedValue))"
                            )

                            SamplerSlider(
                                title: "Repetition Slope",
                                value: repetitionSlopeBinding,
                                range: 0...10,
                                step: 0.05,
                                displayValue: formattedDecimal(repetitionSlopeBinding.wrappedValue)
                            )

                            sequenceField(title: "Sampler Order", text: $samplerOrderText)
                        }
                        .padding(.top, 8)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Advanced Sampling Controls")
                                .foregroundStyle(appTheme.primaryText.color)

                            Text("Top-p, min-p, repetition, and sampler order.")
                                .font(.caption)
                                .foregroundStyle(appTheme.secondaryText.color)
                        }
                    }
                    .tint(appTheme.tintColor.color)
                }

                SettingsCard("Sequences") {
                    sequenceField(title: "User Sequence", text: $userStopSequenceText)
                    sequenceField(title: "Bot Sequence", text: $botStopSequenceText)
                    sequenceField(title: "System Sequence", text: $systemStopSequenceText)
                }
                // caption description
                Text("Include any escape sequences for newlines, tabs, and carriage returns.")
                    .font(.caption)
                    .foregroundStyle(appTheme.secondaryText.color)
                    .padding(.horizontal, 16)

                SettingsCard("Reasoning") {
                    sequenceField(title: "Thinking Start Sequence", text: $thinkingStartSequenceText)
                    sequenceField(title: "Thinking Stop Sequence", text: $thinkingStopSequenceText)
                    ThemedToggleRow(isOn: forceThinkingBinding) {
                        Text("Force Thinking")
                            .foregroundColor(appTheme.primaryText.color)
                    }

                    if forceThinkingBinding.wrappedValue {
                        sequenceField(title: "Force Thinking Instruct", text: $forceThinkingInstructText)
                    }
                }
                Text("You may find if the model does not close the \(connectionManager.connectionSettings.thinkingStopSequence.encodeEscapedSequence()) tag, the response does not stream. It should still load when complete.")
                    .font(.caption)
                    .foregroundStyle(appTheme.secondaryText.color)
                    .padding(.horizontal, 16)
            }
        }
        .padding(.horizontal, 16)
        .background(appTheme.backgroundColor.color)
        .scrollIndicators(.hidden)
        .navigationTitle("Sampler Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    resetVisibleSettingsToDefaults()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .onAppear(perform: syncSequenceFieldsFromSettings)
        .onChange(of: samplerOrderText) { _, newValue in
            updateSamplerOrder(from: newValue)
        }
        .onChange(of: userStopSequenceText) { _, newValue in
            updateEscapedSequence(\.userStopSequence, from: newValue)
        }
        .onChange(of: botStopSequenceText) { _, newValue in
            updateEscapedSequence(\.botStopSequence, from: newValue)
        }
        .onChange(of: systemStopSequenceText) { _, newValue in
            updateEscapedSequence(\.systemStopSequence, from: newValue)
        }
        .onChange(of: thinkingStartSequenceText) { _, newValue in
            updateEscapedSequence(\.thinkingStartSequence, from: newValue)
        }
        .onChange(of: thinkingStopSequenceText) { _, newValue in
            updateEscapedSequence(\.thinkingStopSequence, from: newValue)
        }
        .onChange(of: forceThinkingInstructText) { _, newValue in
            updateEscapedSequence(\.forceThinkingInstruct, from: newValue)
        }
    }

    private func sequenceField(title: String, text: Binding<String>) -> some View {
        ThemedTextField(
            title: title,
            placeholder: title,
            text: text,
            autocapitalization: .never,
            monospaced: true
        )
    }

    private func formattedDecimal(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)))
    }

    private func syncSequenceFieldsFromSettings() {
        let settings = connectionManager.connectionSettings
        userStopSequenceText = settings.userStopSequence.encodeEscapedSequence()
        botStopSequenceText = settings.botStopSequence.encodeEscapedSequence()
        systemStopSequenceText = settings.systemStopSequence.encodeEscapedSequence()
        thinkingStartSequenceText = settings.thinkingStartSequence.encodeEscapedSequence()
        thinkingStopSequenceText = settings.thinkingStopSequence.encodeEscapedSequence()
        forceThinkingInstructText = settings.forceThinkingInstruct.encodeEscapedSequence()
        samplerOrderText = settings.samplerOrder.map(String.init).joined(separator: ", ")
    }

    private func updateEscapedSequence(
        _ keyPath: WritableKeyPath<ConnectionSettingsModel, String>,
        from text: String
    ) {
        let decodedSequence = text.decodeEscapedSequence()
        connectionManager.update(
            keyPath,
            to: decodedSequence.isEmpty ? defaultSequence(for: keyPath) : decodedSequence
        )

        if decodedSequence.isEmpty {
            syncSequenceFieldsFromSettings()
        }
    }

    private func defaultSequence(
        for keyPath: WritableKeyPath<ConnectionSettingsModel, String>
    ) -> String {
        let defaults = ConnectionSettingsModel.defaults

        switch keyPath {
        case \.userStopSequence:
            return defaults.userStopSequence
        case \.botStopSequence:
            return defaults.botStopSequence
        case \.systemStopSequence:
            return defaults.systemStopSequence
        case \.thinkingStartSequence:
            return defaults.thinkingStartSequence
        case \.thinkingStopSequence:
            return defaults.thinkingStopSequence
        case \.forceThinkingInstruct:
            return defaults.forceThinkingInstruct
        default:
            return ""
        }
    }

    private func updateSamplerOrder(from text: String) {
        let samplerOrder = text
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }

        connectionManager.update(
            \.samplerOrder,
            to: samplerOrder.isEmpty ? ConnectionSettingsModel.defaults.samplerOrder : samplerOrder
        )
    }

    private func resetVisibleSettingsToDefaults() {
        let defaults = ConnectionSettingsModel.defaults
        var settings = connectionManager.connectionSettings

        settings.temperature = defaults.temperature
        settings.topP = defaults.topP
        settings.topK = defaults.topK
        settings.typicalP = defaults.typicalP
        settings.tfs = defaults.tfs
        settings.topA = defaults.topA
        settings.minP = defaults.minP
        settings.repetitionPenalty = defaults.repetitionPenalty
        settings.repetitionRange = defaults.repetitionRange
        settings.repetitionSlope = defaults.repetitionSlope
        settings.samplerOrder = defaults.samplerOrder
        settings.userStopSequence = defaults.userStopSequence
        settings.botStopSequence = defaults.botStopSequence
        settings.systemStopSequence = defaults.systemStopSequence
        settings.thinkingStartSequence = defaults.thinkingStartSequence
        settings.thinkingStopSequence = defaults.thinkingStopSequence
        settings.forceThinking = defaults.forceThinking
        settings.forceThinkingInstruct = defaults.forceThinkingInstruct

        connectionManager.updateSettings(settings)
        syncSequenceFieldsFromSettings()
    }
}
