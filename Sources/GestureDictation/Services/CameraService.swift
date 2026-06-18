@preconcurrency import AVFoundation
import Combine
import Foundation
import Vision

final class CameraService: NSObject, ObservableObject, @unchecked Sendable {
    @Published private(set) var currentEvent: GestureEvent = .empty
    @Published var powerMode: PowerMode = .lowPower {
        didSet { applyPowerMode() }
    }
    @Published private(set) var isRunning = false
    @Published private(set) var latestTemplate: [LandmarkPoint]?
    @Published private(set) var diagnostics = RuntimeDiagnostics()
    @Published private(set) var actionLogEntries: [ActionLogEntry]

    let session = AVCaptureSession()

    private let videoOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "VoiceFlick.camera", qos: .userInitiated)
    private let sequenceHandler = VNSequenceRequestHandler()
    private let classifier = GestureClassifier()
    private let mouthClassifier = MouthOpenClassifier()
    let audioLevelService = AudioLevelService()
    private var stateMachine = GestureStateMachine()
    @Published private(set) var builtInGestureSettings: BuiltInGestureSettings
    private weak var profileStore: GestureProfileStore?
    private var profileSubscription: AnyCancellable?
    private var audioLevelSubscription: AnyCancellable?
    private let profilesLock = NSLock()
    private var profilesSnapshot: [GestureProfile] = []
    private var actionService: KeyboardActionService?
    private var configured = false
    private var lastProcessed = Date.distantPast
    private var lastFaceProcessed = Date.distantPast
    private var cachedMouthEvent: GestureEvent?
    private var cachedMouthEventExpiresAt = Date.distantPast
    private var cachedMouthClosedExpiresAt = Date.distantPast
    private var lastDiagnosticLog = Date.distantPast
    private let maxActionLogEntries = 100

    @Published var actionLoggingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(actionLoggingEnabled, forKey: "actionLoggingEnabled")
        }
    }

    @Published var mouthOpenAction: ActionMapping {
        didSet {
            UserDefaults.standard.set(mouthOpenAction.rawValue, forKey: "mouthOpenAction")
        }
    }

    @Published var mouthOpenConfidenceThreshold: Double {
        didSet {
            let clampedThreshold = min(max(mouthOpenConfidenceThreshold, 0.45), 0.95)
            if clampedThreshold != mouthOpenConfidenceThreshold {
                mouthOpenConfidenceThreshold = clampedThreshold
                return
            }
            UserDefaults.standard.set(clampedThreshold, forKey: "mouthOpenConfidenceThreshold")
        }
    }

    @Published var mouthOpenStableDuration: Double {
        didSet {
            let clampedDuration = min(max(mouthOpenStableDuration, 0.10), 1.00)
            if clampedDuration != mouthOpenStableDuration {
                mouthOpenStableDuration = clampedDuration
                return
            }
            UserDefaults.standard.set(clampedDuration, forKey: "mouthOpenStableDuration")
        }
    }

    @Published var closeMouthAutoStopEnabled: Bool {
        didSet {
            UserDefaults.standard.set(closeMouthAutoStopEnabled, forKey: "closeMouthAutoStopEnabled")
        }
    }

    @Published var closeMouthAutoStopDelay: Double {
        didSet {
            let clampedDelay = min(max(closeMouthAutoStopDelay, 1.0), 10.0)
            if clampedDelay != closeMouthAutoStopDelay {
                closeMouthAutoStopDelay = clampedDelay
                return
            }
            UserDefaults.standard.set(clampedDelay, forKey: "closeMouthAutoStopDelay")
        }
    }

    @Published var audioSilenceStopEnabled: Bool {
        didSet {
            UserDefaults.standard.set(audioSilenceStopEnabled, forKey: "audioSilenceStopEnabled")
        }
    }

    @Published var audioSilenceThresholdDBFS: Double {
        didSet {
            let clampedThreshold = min(max(audioSilenceThresholdDBFS, -60.0), -25.0)
            if clampedThreshold != audioSilenceThresholdDBFS {
                audioSilenceThresholdDBFS = clampedThreshold
                return
            }
            UserDefaults.standard.set(clampedThreshold, forKey: "audioSilenceThresholdDBFS")
        }
    }

    @Published var audioSilenceDelay: Double {
        didSet {
            let clampedDelay = min(max(audioSilenceDelay, 1.0), 10.0)
            if clampedDelay != audioSilenceDelay {
                audioSilenceDelay = clampedDelay
                return
            }
            UserDefaults.standard.set(clampedDelay, forKey: "audioSilenceDelay")
        }
    }

    override init() {
        let storedAction = UserDefaults.standard.string(forKey: "mouthOpenAction")
            .flatMap(ActionMapping.init(rawValue:)) ?? .startDictation
        mouthOpenAction = storedAction
        let storedMouthThreshold = UserDefaults.standard.object(forKey: "mouthOpenConfidenceThreshold") as? Double ?? 0.80
        mouthOpenConfidenceThreshold = min(max(storedMouthThreshold, 0.45), 0.95)
        let storedMouthStableDuration = UserDefaults.standard.object(forKey: "mouthOpenStableDuration") as? Double ?? 0.30
        mouthOpenStableDuration = min(max(storedMouthStableDuration, 0.10), 1.00)
        closeMouthAutoStopEnabled = UserDefaults.standard.object(forKey: "closeMouthAutoStopEnabled") as? Bool ?? true
        let storedDelay = UserDefaults.standard.object(forKey: "closeMouthAutoStopDelay") as? Double ?? 3.0
        closeMouthAutoStopDelay = min(max(storedDelay, 1.0), 10.0)
        let enabledIDs = UserDefaults.standard.array(forKey: "enabledBuiltInGestures") as? [String]
        builtInGestureSettings = BuiltInGestureSettings(enabledIDs: Set(enabledIDs ?? BuiltInGestureKind.allCases.map(\.id)))
        actionLoggingEnabled = UserDefaults.standard.object(forKey: "actionLoggingEnabled") as? Bool ?? true
        audioSilenceStopEnabled = UserDefaults.standard.object(forKey: "audioSilenceStopEnabled") as? Bool ?? true
        let storedThreshold = UserDefaults.standard.object(forKey: "audioSilenceThresholdDBFS") as? Double ?? -45.0
        audioSilenceThresholdDBFS = min(max(storedThreshold, -60.0), -25.0)
        let storedAudioDelay = UserDefaults.standard.object(forKey: "audioSilenceDelay") as? Double ?? 3.0
        audioSilenceDelay = min(max(storedAudioDelay, 1.0), 10.0)
        actionLogEntries = Self.loadActionLogEntries()
        super.init()
        audioLevelSubscription = audioLevelService.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.objectWillChange.send()
            }
        }
    }

    @MainActor
    func configure(profileStore: GestureProfileStore, actionService: KeyboardActionService) {
        self.profileStore = profileStore
        self.actionService = actionService
        setProfilesSnapshot(profileStore.profiles)
        profileSubscription = profileStore.$profiles.sink { [weak self] profiles in
            self?.setProfilesSnapshot(profiles)
        }
        guard !configured else { return }
        configured = true

        updateDiagnostics(status: "正在配置摄像头")
        DiagnosticsLogger.shared.append("configure requested")
        queue.async { [weak self] in self?.configureSession() }
    }

    func toggleRunning() {
        if isRunning {
            stop()
        } else {
            start()
        }
    }

    func start() {
        guard powerMode != .paused else {
            powerMode = .lowPower
            return
        }
        queue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isRunning = true
                self.updateDiagnostics(status: "摄像头运行中")
            }
            DiagnosticsLogger.shared.append("capture session started")
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isRunning = false
                self.audioLevelService.stopMonitoring()
                self.updateDiagnostics(status: "摄像头已暂停")
            }
            DiagnosticsLogger.shared.append("capture session stopped")
        }
    }

    @MainActor
    func captureTrainingSample(for profileID: UUID) {
        guard let latestTemplate else { return }
        profileStore?.appendTemplate(latestTemplate, to: profileID)
    }

    @MainActor
    func resetRecognitionState() {
        stateMachine = GestureStateMachine()
        audioLevelService.stopMonitoring()
        DiagnosticsLogger.shared.append("state machine reset by user")
    }

    @MainActor
    func clearActionLog() {
        actionLogEntries = []
        persistActionLogEntries()
        DiagnosticsLogger.shared.append("action log cleared by user")
    }

    @MainActor
    func setBuiltInGesture(_ kind: BuiltInGestureKind, enabled: Bool) {
        if enabled {
            builtInGestureSettings.enabledIDs.insert(kind.id)
        } else {
            builtInGestureSettings.enabledIDs.remove(kind.id)
        }
        UserDefaults.standard.set(Array(builtInGestureSettings.enabledIDs), forKey: "enabledBuiltInGestures")
        stateMachine = GestureStateMachine()
        DiagnosticsLogger.shared.append("builtInGesture \(kind.id) enabled=\(enabled)")
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .low

        guard
            let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified),
            let input = try? AVCaptureDeviceInput(device: camera),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            publishFailure("找不到可用摄像头或无法创建输入")
            return
        }

        session.addInput(input)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        publishStatus("摄像头配置完成，使用软件节流 \(powerMode.targetFPS) FPS")
        DiagnosticsLogger.shared.append("session configured preset=low throttleFPS=\(powerMode.targetFPS)")
        session.commitConfiguration()

        start()
    }

    private func applyPowerMode() {
        if powerMode == .paused {
            stop()
            return
        }
        publishStatus("软件节流 \(powerMode.targetFPS) FPS")
        DiagnosticsLogger.shared.append("power mode changed \(powerMode.rawValue) throttleFPS=\(powerMode.targetFPS)")
    }

    private func handle(sampleBuffer: CMSampleBuffer) {
        let now = Date()
        let minimumInterval = 1.0 / Double(max(powerMode.targetFPS, 1))
        guard now.timeIntervalSince(lastProcessed) >= minimumInterval else { return }
        lastProcessed = now

        let handRequest = VNDetectHumanHandPoseRequest()
        handRequest.maximumHandCount = 1

        let faceRequest: VNDetectFaceLandmarksRequest? = shouldProcessFace(at: now)
            ? VNDetectFaceLandmarksRequest()
            : nil
        let requests: [VNRequest] = [handRequest] + (faceRequest.map { [$0] } ?? [])

        do {
            try sequenceHandler.perform(requests, on: sampleBuffer, orientation: .up)
            if let faceRequest {
                updateCachedMouthEvent(from: faceRequest, at: now)
            }

            guard let observation = handRequest.results?.first else {
                let event = filteredEvent(currentMouthEvent(at: now) ?? currentMouthClosedEvent(at: now) ?? .empty)
                maybeLogFrame(handDetected: false, event: event)
                publish(event: event, template: nil, handDetected: false)
                return
            }

            let profiles = currentProfilesSnapshot()
            let (handEvent, template) = classifier.classify(observation: observation, profiles: profiles)
            let filteredHandEvent = filteredEvent(handEvent)
            let event = filteredHandEvent.gesture == .none
                ? filteredEvent(currentMouthEvent(at: now) ?? currentMouthClosedEvent(at: now) ?? filteredHandEvent)
                : filteredHandEvent
            maybeLogFrame(handDetected: true, event: event)
            publish(event: event, template: template, profiles: profiles, handDetected: true)
        } catch {
            publishFailure("Vision 识别失败: \(error.localizedDescription)")
            publish(event: .empty, template: nil, handDetected: false)
        }
    }

    private func publish(
        event: GestureEvent,
        template: [LandmarkPoint]?,
        profiles: [GestureProfile] = [],
        handDetected: Bool = false
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.currentEvent = event
            self.latestTemplate = template
            self.diagnostics.processedFrames += 1
            self.diagnostics.lastFrameAt = .now
            self.diagnostics.status = self.isRunning ? "摄像头运行中" : "摄像头已配置"
            if handDetected {
                self.diagnostics.detectedHands += 1
                self.diagnostics.lastHandAt = .now
            }
            if let actionService = self.actionService {
                let decision = self.stateMachine.consume(
                    event,
                    profiles: profiles,
                    builtInGestureSettings: self.builtInGestureSettings,
                    mouthOpenAction: self.mouthOpenAction,
                    mouthOpenConfidenceThreshold: self.mouthOpenConfidenceThreshold,
                    mouthOpenStableDuration: self.mouthOpenStableDuration,
                    closeMouthAutoStopEnabled: self.closeMouthAutoStopEnabled,
                    closeMouthAutoStopDelay: self.closeMouthAutoStopDelay,
                    audioSilenceStopEnabled: self.audioSilenceStopEnabled && self.audioLevelService.isMonitoring,
                    audioSilenceThresholdDBFS: self.audioSilenceThresholdDBFS,
                    audioSilenceDelay: self.audioSilenceDelay,
                    audioLevelDBFS: self.audioLevelService.isMonitoring ? self.audioLevelService.currentLevelDBFS : nil,
                    actionService: actionService
                )
                if let decision {
                    self.applyAudioMonitoring(for: decision.action)
                    self.recordActionLog(for: decision, event: event)
                }
            }
        }
    }

    private func applyAudioMonitoring(for action: ActionMapping) {
        switch action {
        case .startDictation:
            guard audioSilenceStopEnabled else { return }
            audioLevelService.startMonitoringIfAllowed()
        case .stopDictation:
            audioLevelService.stopMonitoring()
        case .pressReturn, .clearInput, .copyClipboard, .pasteClipboard, .none:
            break
        }
    }

    private func recordActionLog(
        for decision: (action: ActionMapping, reason: String, stableDuration: TimeInterval),
        event: GestureEvent
    ) {
        guard actionLoggingEnabled else { return }
        let entry = ActionLogEntry(
            timestamp: event.timestamp,
            gestureName: gestureName(for: event, reason: decision.reason),
            actionName: decision.action.displayName,
            reason: decision.reason,
            confidence: event.confidence,
            audioLevelDBFS: audioLevelService.isMonitoring ? audioLevelService.currentLevelDBFS : nil
        )
        actionLogEntries.insert(entry, at: 0)
        if actionLogEntries.count > maxActionLogEntries {
            actionLogEntries.removeLast(actionLogEntries.count - maxActionLogEntries)
        }
        persistActionLogEntries()
    }

    private func gestureName(for event: GestureEvent, reason: String) -> String {
        if reason == "noHand" || reason == "noGesture" || reason == "mouthClosed" || reason.hasPrefix("mouthClosedAndLowAudio") {
            return "放下/结束条件"
        }
        if reason.hasPrefix("custom profile=") {
            return reason.replacingOccurrences(of: "custom profile=", with: "自定义: ")
        }
        if reason == "gripClosedFromPalm" {
            return "握拳复制"
        }
        if reason == "fistRelease" {
            return "松开粘贴"
        }
        return event.gesture.displayName
    }

    private func persistActionLogEntries() {
        if let data = try? JSONEncoder().encode(actionLogEntries) {
            UserDefaults.standard.set(data, forKey: "actionLogEntries")
        }
    }

    private static func loadActionLogEntries() -> [ActionLogEntry] {
        guard
            let data = UserDefaults.standard.data(forKey: "actionLogEntries"),
            let entries = try? JSONDecoder().decode([ActionLogEntry].self, from: data)
        else {
            return []
        }
        return Array(entries.prefix(100))
    }

    private func filteredEvent(_ event: GestureEvent) -> GestureEvent {
        guard builtInGestureSettings.isEnabled(event.gesture) else {
            return GestureEvent(
                gesture: .none,
                confidence: 0,
                handPresent: event.handPresent,
                timestamp: event.timestamp,
                trackingPoint: event.trackingPoint
            )
        }
        return event
    }

    private func shouldProcessFace(at now: Date) -> Bool {
        guard powerMode != .paused else { return false }
        let targetFPS: Double = powerMode == .normal ? 5 : 2
        let minimumInterval = 1.0 / targetFPS
        guard now.timeIntervalSince(lastFaceProcessed) >= minimumInterval else { return false }
        lastFaceProcessed = now
        return true
    }

    private func updateCachedMouthEvent(from request: VNDetectFaceLandmarksRequest, at now: Date) {
        let ttl = powerMode == .normal ? 0.35 : 0.65
        guard let observation = request.results?.first else {
            cachedMouthEvent = nil
            cachedMouthEventExpiresAt = .distantPast
            cachedMouthClosedExpiresAt = .distantPast
            return
        }

        if var event = mouthClassifier.classify(observation: observation) {
            event.timestamp = now
            cachedMouthEvent = event
            cachedMouthEventExpiresAt = now.addingTimeInterval(ttl)
            cachedMouthClosedExpiresAt = .distantPast
        } else {
            cachedMouthEvent = nil
            cachedMouthEventExpiresAt = .distantPast
            cachedMouthClosedExpiresAt = now.addingTimeInterval(ttl)
        }
    }

    private func currentMouthEvent(at now: Date) -> GestureEvent? {
        guard var event = cachedMouthEvent, now <= cachedMouthEventExpiresAt else {
            return nil
        }
        event.timestamp = now
        return event
    }

    private func currentMouthClosedEvent(at now: Date) -> GestureEvent? {
        guard now <= cachedMouthClosedExpiresAt else {
            return nil
        }
        return GestureEvent(
            gesture: .none,
            confidence: 0,
            handPresent: true,
            timestamp: now,
            trackingPoint: nil
        )
    }

    private func publishStatus(_ status: String) {
        DiagnosticsLogger.shared.append("status \(status)")
        DispatchQueue.main.async { [weak self] in
            self?.updateDiagnostics(status: status)
        }
    }

    private func publishFailure(_ message: String) {
        DiagnosticsLogger.shared.append("failure \(message)")
        DispatchQueue.main.async { [weak self] in
            self?.diagnostics.lastError = message
            self?.updateDiagnostics(status: "需要处理")
        }
    }

    private func updateDiagnostics(status: String) {
        diagnostics.status = status
    }

    private func setProfilesSnapshot(_ profiles: [GestureProfile]) {
        profilesLock.lock()
        profilesSnapshot = profiles
        profilesLock.unlock()
    }

    private func currentProfilesSnapshot() -> [GestureProfile] {
        profilesLock.lock()
        let profiles = profilesSnapshot
        profilesLock.unlock()
        return profiles
    }

    private func maybeLogFrame(handDetected: Bool, event: GestureEvent) {
        let now = Date()
        let shouldLog = handDetected || now.timeIntervalSince(lastDiagnosticLog) >= 2
        guard shouldLog else { return }
        lastDiagnosticLog = now
        DiagnosticsLogger.shared.append(
            "frame hand=\(handDetected) gesture=\(event.gesture.id) confidence=\(String(format: "%.2f", event.confidence))"
        )
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        self.handle(sampleBuffer: sampleBuffer)
    }
}
