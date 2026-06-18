import Foundation

struct GestureStateMachine {
    private enum DictationStartSource {
        case handGesture
        case mouthOpen
        case custom
    }

    private let minimumDictationDuration: TimeInterval = 3.0
    private var dictationActive = false
    private var dictationStartSource: DictationStartSource?
    private var dictationStartedAt: Date?
    private var lastGesture: GestureID = .none
    private var stableSince = Date.now
    private var cooldownUntil = Date.distantPast
    private var waveSamples: [(timestamp: Date, x: Double)] = []
    private var lowAudioSince: Date?

    mutating func nextAction(
        for event: GestureEvent,
        profiles: [GestureProfile] = [],
        builtInGestureSettings: BuiltInGestureSettings = BuiltInGestureSettings(),
        mouthOpenAction: ActionMapping = .none,
        mouthOpenConfidenceThreshold: Double = 0.80,
        closeMouthAutoStopEnabled: Bool = false,
        closeMouthAutoStopDelay: TimeInterval = 3.0,
        audioSilenceStopEnabled: Bool = false,
        audioSilenceThresholdDBFS: Double = -45,
        audioSilenceDelay: TimeInterval = 3.0,
        audioLevelDBFS: Double? = nil
    ) -> (action: ActionMapping, reason: String, stableDuration: TimeInterval)? {
        let now = event.timestamp
        if event.gesture != lastGesture {
            lastGesture = event.gesture
            stableSince = now
            if event.gesture != .none {
                lowAudioSince = nil
            }
        }
        guard now >= cooldownUntil else { return nil }

        let stableDuration = now.timeIntervalSince(stableSince)

        switch event.gesture {
        case .closedFist, .pointing:
            guard builtInGestureSettings.isEnabled(event.gesture) else { return nil }
            guard !dictationActive, stableDuration >= 0.30 else { return nil }
            dictationActive = true
            dictationStartSource = .handGesture
            dictationStartedAt = now
            lowAudioSince = nil
            cooldownUntil = now.addingTimeInterval(0.80)
            return (.startDictation, event.gesture.id, stableDuration)

        case .victory, .thumbsUp:
            guard builtInGestureSettings.isEnabled(event.gesture) else { return nil }
            guard stableDuration >= 0.30 else { return nil }
            cooldownUntil = now.addingTimeInterval(0.80)
            return (.pressReturn, event.gesture.id, stableDuration)

        case .wave:
            guard builtInGestureSettings.isEnabled(BuiltInGestureKind.wave) else { return nil }
            guard recordWaveSample(event), stableDuration >= 0.30 else { return nil }
            waveSamples.removeAll()
            cooldownUntil = now.addingTimeInterval(1.20)
            return (.clearInput, "wave", stableDuration)

        case .mouthOpen:
            guard builtInGestureSettings.isEnabled(BuiltInGestureKind.mouthOpen) else { return nil }
            guard event.confidence >= mouthOpenConfidenceThreshold else {
                DiagnosticsLogger.shared.append(
                    "skip action reason=mouthOpenLowConfidence confidence=\(String(format: "%.2f", event.confidence)) threshold=\(String(format: "%.2f", mouthOpenConfidenceThreshold))"
                )
                return nil
            }
            guard mouthOpenAction != .none, stableDuration >= 0.30 else { return nil }
            if mouthOpenAction == .startDictation, dictationActive {
                return nil
            }
            applyDictationState(for: mouthOpenAction, source: .mouthOpen, at: now)
            cooldownUntil = now.addingTimeInterval(1.20)
            return (mouthOpenAction, "mouthOpen", stableDuration)

        case .custom(let id):
            guard stableDuration >= 0.35, let profile = profiles.first(where: { $0.id == id }) else { return nil }
            guard canPerformStopIfNeeded(profile.action, at: now) else { return nil }
            applyDictationState(for: profile.action, source: .custom, at: now)
            cooldownUntil = now.addingTimeInterval(0.80)
            return (profile.action, "custom profile=\(profile.name)", stableDuration)

        case .none:
            guard builtInGestureSettings.isHandDownEnabled() else { return nil }
            guard dictationActive, stableDuration >= 0.50 else { return nil }
            if dictationStartSource == .mouthOpen {
                guard closeMouthAutoStopEnabled else {
                    DiagnosticsLogger.shared.append("skip stop reason=mouthOpenSession stable=\(String(format: "%.2f", stableDuration))")
                    return nil
                }
                guard event.handPresent else {
                    DiagnosticsLogger.shared.append("skip stop reason=mouthOpenSessionNoFace stable=\(String(format: "%.2f", stableDuration))")
                    return nil
                }
                if audioSilenceStopEnabled, let audioLevelDBFS {
                    guard isAudioSilent(
                        at: now,
                        levelDBFS: audioLevelDBFS,
                        thresholdDBFS: audioSilenceThresholdDBFS,
                        requiredDuration: audioSilenceDelay
                    ) else {
                        return nil
                    }
                }
                guard stableDuration >= closeMouthAutoStopDelay else { return nil }
                guard canPerformStopIfNeeded(.stopDictation, at: now) else { return nil }
                dictationActive = false
                dictationStartSource = nil
                dictationStartedAt = nil
                lowAudioSince = nil
                cooldownUntil = now.addingTimeInterval(0.80)
                let reason = audioSilenceStopEnabled && audioLevelDBFS != nil
                    ? "mouthClosedAndLowAudio db=\(String(format: "%.1f", audioLevelDBFS ?? -120)) threshold=\(String(format: "%.0f", audioSilenceThresholdDBFS))"
                    : "mouthClosed"
                return (.stopDictation, reason, stableDuration)
            }
            guard dictationStartSource == .handGesture else {
                DiagnosticsLogger.shared.append("skip stop reason=nonHandSession stable=\(String(format: "%.2f", stableDuration))")
                return nil
            }
            guard canPerformStopIfNeeded(.stopDictation, at: now) else { return nil }
            dictationActive = false
            dictationStartSource = nil
            dictationStartedAt = nil
            lowAudioSince = nil
            cooldownUntil = now.addingTimeInterval(0.80)
            return (.stopDictation, event.handPresent ? "noGesture" : "noHand", stableDuration)
        }
    }

    private mutating func applyDictationState(for action: ActionMapping, source: DictationStartSource, at now: Date) {
        if action == .startDictation {
            dictationActive = true
            dictationStartSource = source
            dictationStartedAt = now
            lowAudioSince = nil
        }
        if action == .stopDictation {
            dictationActive = false
            dictationStartSource = nil
            dictationStartedAt = nil
            lowAudioSince = nil
        }
    }

    private mutating func isAudioSilent(
        at now: Date,
        levelDBFS: Double,
        thresholdDBFS: Double,
        requiredDuration: TimeInterval
    ) -> Bool {
        guard levelDBFS < thresholdDBFS else {
            lowAudioSince = nil
            DiagnosticsLogger.shared.append(
                "skip stop reason=audioAboveThreshold db=\(String(format: "%.1f", levelDBFS)) threshold=\(String(format: "%.0f", thresholdDBFS))"
            )
            return false
        }

        if lowAudioSince == nil {
            lowAudioSince = now
        }

        let duration = now.timeIntervalSince(lowAudioSince ?? now)
        guard duration >= requiredDuration else {
            DiagnosticsLogger.shared.append(
                "skip stop reason=audioSilenceDuration db=\(String(format: "%.1f", levelDBFS)) duration=\(String(format: "%.2f", duration))"
            )
            return false
        }
        return true
    }

    private func canPerformStopIfNeeded(_ action: ActionMapping, at now: Date) -> Bool {
        guard action == .stopDictation, let dictationStartedAt else { return true }
        let activeDuration = now.timeIntervalSince(dictationStartedAt)
        if activeDuration < minimumDictationDuration {
            DiagnosticsLogger.shared.append(
                "skip stop reason=minimumDictationDuration active=\(String(format: "%.2f", activeDuration))"
            )
            return false
        }
        return true
    }

    private mutating func recordWaveSample(_ event: GestureEvent) -> Bool {
        guard let trackingPoint = event.trackingPoint else { return false }
        let now = event.timestamp
        waveSamples.append((now, trackingPoint.x))
        waveSamples.removeAll { now.timeIntervalSince($0.timestamp) > 0.80 }

        let xValues = waveSamples.map(\.x)
        guard let minX = xValues.min(), let maxX = xValues.max() else { return false }
        return maxX - minX >= 0.18
    }

    mutating func consume(
        _ event: GestureEvent,
        profiles: [GestureProfile],
        builtInGestureSettings: BuiltInGestureSettings = BuiltInGestureSettings(),
        mouthOpenAction: ActionMapping = .none,
        mouthOpenConfidenceThreshold: Double = 0.80,
        closeMouthAutoStopEnabled: Bool = false,
        closeMouthAutoStopDelay: TimeInterval = 3.0,
        audioSilenceStopEnabled: Bool = false,
        audioSilenceThresholdDBFS: Double = -45,
        audioSilenceDelay: TimeInterval = 3.0,
        audioLevelDBFS: Double? = nil,
        actionService: KeyboardActionService
    ) -> (action: ActionMapping, reason: String, stableDuration: TimeInterval)? {
        if let decision = nextAction(
            for: event,
            profiles: profiles,
            builtInGestureSettings: builtInGestureSettings,
            mouthOpenAction: mouthOpenAction,
            mouthOpenConfidenceThreshold: mouthOpenConfidenceThreshold,
            closeMouthAutoStopEnabled: closeMouthAutoStopEnabled,
            closeMouthAutoStopDelay: closeMouthAutoStopDelay,
            audioSilenceStopEnabled: audioSilenceStopEnabled,
            audioSilenceThresholdDBFS: audioSilenceThresholdDBFS,
            audioSilenceDelay: audioSilenceDelay,
            audioLevelDBFS: audioLevelDBFS
        ) {
            DiagnosticsLogger.shared.append(
                "action \(decision.action.rawValue) reason=\(decision.reason) stable=\(String(format: "%.2f", decision.stableDuration))"
            )
            actionService.perform(decision.action)
            return decision
        }
        return nil
    }
}
