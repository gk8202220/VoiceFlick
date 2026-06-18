import XCTest
@testable import VoiceFlick

final class GestureStateMachineTests: XCTestCase {
    func testFistDownFistCyclesTriggerRepeatedStartAndStopActions() {
        var machine = GestureStateMachine()
        let start = Date(timeIntervalSince1970: 1_000)
        var actions: [ActionMapping] = []

        for cycle in 0..<20 {
            let base = start.addingTimeInterval(Double(cycle) * 5.0)
            actions.append(contentsOf: feed(&machine, gesture: .closedFist, handPresent: true, from: base, count: 5))
            actions.append(contentsOf: feed(&machine, gesture: .none, handPresent: false, from: base.addingTimeInterval(1.2), count: 18))
        }

        let starts = actions.filter { $0 == .startDictation }.count
        let stops = actions.filter { $0 == .stopDictation }.count
        XCTAssertEqual(starts, 20)
        XCTAssertEqual(stops, 20)
    }

    func testNoHandTimestampIsFreshForEveryEmptyEvent() {
        let first = GestureEvent.empty
        Thread.sleep(forTimeInterval: 0.01)
        let second = GestureEvent.empty
        XCTAssertGreaterThan(second.timestamp, first.timestamp)
    }

    func testMinimumDictationDurationDelaysStopAfterHandDrops() {
        var machine = GestureStateMachine()
        let start = Date(timeIntervalSince1970: 2_000)

        var actions = feed(&machine, gesture: .closedFist, handPresent: true, from: start, count: 5)
        actions.append(contentsOf: feed(&machine, gesture: .none, handPresent: false, from: start.addingTimeInterval(0.45), count: 12))

        XCTAssertEqual(actions, [.startDictation])

        actions.append(contentsOf: feed(&machine, gesture: .none, handPresent: false, from: start.addingTimeInterval(2.4), count: 10))
        actions.append(contentsOf: feed(&machine, gesture: .closedFist, handPresent: true, from: start.addingTimeInterval(4.4), count: 8))

        XCTAssertEqual(actions, [.startDictation, .stopDictation, .startDictation])
    }

    func testDisabledClosedFistDoesNotStartDictation() {
        var machine = GestureStateMachine()
        let start = Date(timeIntervalSince1970: 2_100)
        var settings = BuiltInGestureSettings()
        settings.enabledIDs.remove(BuiltInGestureKind.closedFist.id)

        let actions = feed(&machine, gesture: .closedFist, handPresent: true, from: start, count: 5, settings: settings)

        XCTAssertTrue(actions.isEmpty)
    }

    func testDisabledHandDownDoesNotStopDictation() {
        var machine = GestureStateMachine()
        let start = Date(timeIntervalSince1970: 2_200)
        var settings = BuiltInGestureSettings()
        settings.enabledIDs.remove(BuiltInGestureKind.handDown.id)

        var actions = feed(&machine, gesture: .closedFist, handPresent: true, from: start, count: 5, settings: settings)
        actions.append(contentsOf: feed(&machine, gesture: .none, handPresent: false, from: start.addingTimeInterval(1.2), count: 7, settings: settings))

        XCTAssertEqual(actions, [.startDictation])
    }

    func testPointingStartsDictationAndStopsWhenHandDrops() {
        var machine = GestureStateMachine()
        let start = Date(timeIntervalSince1970: 2_500)

        var actions = feed(&machine, gesture: .pointing, handPresent: true, from: start, count: 5)
        actions.append(contentsOf: feed(&machine, gesture: .none, handPresent: false, from: start.addingTimeInterval(1.2), count: 18))

        XCTAssertEqual(actions, [.startDictation, .stopDictation])
    }

    func testThumbsUpTriggersReturn() {
        var machine = GestureStateMachine()
        let start = Date(timeIntervalSince1970: 2_750)

        let actions = feed(&machine, gesture: .thumbsUp, handPresent: true, from: start, count: 5)

        XCTAssertEqual(actions, [.pressReturn])
    }

    func testWaveClearsInputAfterHorizontalMovement() {
        var machine = GestureStateMachine()
        let start = Date(timeIntervalSince1970: 2_900)
        let positions = [0.32, 0.37, 0.44, 0.51, 0.56]

        let actions = feedWave(&machine, from: start, positions: positions)

        XCTAssertEqual(actions, [.clearInput])
    }

    func testStaticOpenPalmDoesNotClearInput() {
        var machine = GestureStateMachine()
        let start = Date(timeIntervalSince1970: 2_950)
        let positions = [0.42, 0.43, 0.42, 0.43, 0.42, 0.43]

        let actions = feedWave(&machine, from: start, positions: positions)

        XCTAssertTrue(actions.isEmpty)
    }

    func testMouthOpenDoesNothingByDefault() {
        var machine = GestureStateMachine()
        let start = Date(timeIntervalSince1970: 2_980)

        let actions = feed(&machine, gesture: .mouthOpen, handPresent: true, from: start, count: 5)

        XCTAssertTrue(actions.isEmpty)
    }

    func testMouthOpenTriggersConfiguredAction() {
        var machine = GestureStateMachine()
        let start = Date(timeIntervalSince1970: 2_990)

        let actions = feed(
            &machine,
            gesture: .mouthOpen,
            handPresent: true,
            from: start,
            count: 5,
            mouthOpenAction: .clearInput
        )

        XCTAssertEqual(actions, [.clearInput])
    }

    func testMouthOpenBelowConfidenceThresholdDoesNotStartDictation() {
        var machine = GestureStateMachine()
        let start = Date(timeIntervalSince1970: 2_991)

        let actions = feed(
            &machine,
            gesture: .mouthOpen,
            handPresent: true,
            from: start,
            count: 5,
            mouthOpenAction: .startDictation,
            mouthOpenConfidenceThreshold: 0.80,
            confidence: 0.79
        )

        XCTAssertTrue(actions.isEmpty)
    }

    func testMouthOpenUsesConfiguredConfidenceThreshold() {
        var machine = GestureStateMachine()
        let start = Date(timeIntervalSince1970: 2_9915)

        let actions = feed(
            &machine,
            gesture: .mouthOpen,
            handPresent: true,
            from: start,
            count: 5,
            mouthOpenAction: .startDictation,
            mouthOpenConfidenceThreshold: 0.70,
            confidence: 0.72
        )

        XCTAssertEqual(actions, [.startDictation])
    }

    func testMouthOpenStartedDictationDoesNotStopWhenFaceIsLost() {
        var machine = GestureStateMachine()
        let start = Date(timeIntervalSince1970: 2_992)

        var actions = feed(
            &machine,
            gesture: .mouthOpen,
            handPresent: true,
            from: start,
            count: 5,
            mouthOpenAction: .startDictation
        )
        actions.append(contentsOf: feed(
            &machine,
            gesture: .none,
            handPresent: false,
            from: start.addingTimeInterval(1.4),
            count: 8,
            mouthOpenAction: .startDictation
        ))

        XCTAssertEqual(actions, [.startDictation])
    }

    func testMouthOpenDoesNotRepeatedlyStartWhileAlreadyActive() {
        var machine = GestureStateMachine()
        let start = Date(timeIntervalSince1970: 2_9925)

        var actions = feed(
            &machine,
            gesture: .mouthOpen,
            handPresent: true,
            from: start,
            count: 5,
            mouthOpenAction: .startDictation
        )
        actions.append(contentsOf: feed(
            &machine,
            gesture: .mouthOpen,
            handPresent: true,
            from: start.addingTimeInterval(1.5),
            count: 8,
            mouthOpenAction: .startDictation
        ))

        XCTAssertEqual(actions, [.startDictation])
    }

    func testMouthOpenStartedDictationStopsAfterConfiguredClosedMouthDelay() {
        var machine = GestureStateMachine()
        let start = Date(timeIntervalSince1970: 2_993)

        var actions = feed(
            &machine,
            gesture: .mouthOpen,
            handPresent: true,
            from: start,
            count: 5,
            mouthOpenAction: .startDictation,
            closeMouthAutoStopEnabled: true,
            closeMouthAutoStopDelay: 3.0
        )
        actions.append(contentsOf: feed(
            &machine,
            gesture: .none,
            handPresent: true,
            from: start.addingTimeInterval(1.4),
            count: 23,
            mouthOpenAction: .startDictation,
            closeMouthAutoStopEnabled: true,
            closeMouthAutoStopDelay: 3.0
        ))

        XCTAssertEqual(actions, [.startDictation, .stopDictation])
    }

    func testMouthOpenStartedDictationDoesNotStopWhenMouthClosedButAudioIsHigh() {
        var machine = GestureStateMachine()
        let start = Date(timeIntervalSince1970: 2_9932)

        var actions = feed(
            &machine,
            gesture: .mouthOpen,
            handPresent: true,
            from: start,
            count: 5,
            mouthOpenAction: .startDictation
        )
        actions.append(contentsOf: feed(
            &machine,
            gesture: .none,
            handPresent: true,
            from: start.addingTimeInterval(1.4),
            count: 35,
            mouthOpenAction: .startDictation,
            closeMouthAutoStopEnabled: true,
            closeMouthAutoStopDelay: 3.0,
            audioSilenceStopEnabled: true,
            audioLevelDBFS: -30.0
        ))

        XCTAssertEqual(actions, [.startDictation])
    }

    func testMouthOpenStartedDictationDoesNotStopWhenAudioIsLowButMouthStaysOpen() {
        var machine = GestureStateMachine()
        let start = Date(timeIntervalSince1970: 2_9934)

        var actions = feed(
            &machine,
            gesture: .mouthOpen,
            handPresent: true,
            from: start,
            count: 5,
            mouthOpenAction: .startDictation
        )
        actions.append(contentsOf: feed(
            &machine,
            gesture: .mouthOpen,
            handPresent: true,
            from: start.addingTimeInterval(1.4),
            count: 35,
            mouthOpenAction: .startDictation,
            closeMouthAutoStopEnabled: true,
            closeMouthAutoStopDelay: 3.0,
            audioSilenceStopEnabled: true,
            audioLevelDBFS: -55.0
        ))

        XCTAssertEqual(actions, [.startDictation])
    }

    func testMouthOpenStartedDictationStopsWhenMouthClosedAndAudioIsLow() {
        var machine = GestureStateMachine()
        let start = Date(timeIntervalSince1970: 2_9936)

        var actions = feed(
            &machine,
            gesture: .mouthOpen,
            handPresent: true,
            from: start,
            count: 5,
            mouthOpenAction: .startDictation
        )
        actions.append(contentsOf: feed(
            &machine,
            gesture: .none,
            handPresent: true,
            from: start.addingTimeInterval(1.4),
            count: 35,
            mouthOpenAction: .startDictation,
            closeMouthAutoStopEnabled: true,
            closeMouthAutoStopDelay: 3.0,
            audioSilenceStopEnabled: true,
            audioLevelDBFS: -55.0
        ))

        XCTAssertEqual(actions, [.startDictation, .stopDictation])
    }

    func testCustomStopCanStopMouthOpenStartedDictation() {
        var machine = GestureStateMachine()
        let start = Date(timeIntervalSince1970: 2_994)
        let profileID = UUID()
        let profile = GestureProfile(
            id: profileID,
            name: "停止",
            action: .stopDictation,
            threshold: 0.18,
            templates: [[LandmarkPoint(x: 0, y: 0)]]
        )

        var actions = feed(
            &machine,
            gesture: .mouthOpen,
            handPresent: true,
            from: start,
            count: 5,
            mouthOpenAction: .startDictation
        )
        actions.append(contentsOf: feed(
            &machine,
            gesture: .custom(profileID),
            handPresent: true,
            from: start.addingTimeInterval(3.4),
            count: 5,
            profiles: [profile],
            mouthOpenAction: .startDictation
        ))

        XCTAssertEqual(actions, [.startDictation, .stopDictation])
    }

    func testCustomStopIsBlockedBeforeMinimumDictationDuration() {
        var machine = GestureStateMachine()
        let start = Date(timeIntervalSince1970: 2_9945)
        let profileID = UUID()
        let profile = GestureProfile(
            id: profileID,
            name: "停止",
            action: .stopDictation,
            threshold: 0.18,
            templates: [[LandmarkPoint(x: 0, y: 0)]]
        )

        var actions = feed(
            &machine,
            gesture: .mouthOpen,
            handPresent: true,
            from: start,
            count: 5,
            mouthOpenAction: .startDictation
        )
        actions.append(contentsOf: feed(
            &machine,
            gesture: .custom(profileID),
            handPresent: true,
            from: start.addingTimeInterval(1.4),
            count: 5,
            profiles: [profile],
            mouthOpenAction: .startDictation
        ))

        XCTAssertEqual(actions, [.startDictation])
    }

    func testDisabledMouthOpenDoesNotTriggerConfiguredAction() {
        var machine = GestureStateMachine()
        let start = Date(timeIntervalSince1970: 2_995)
        var settings = BuiltInGestureSettings()
        settings.enabledIDs.remove(BuiltInGestureKind.mouthOpen.id)

        let actions = feed(
            &machine,
            gesture: .mouthOpen,
            handPresent: true,
            from: start,
            count: 5,
            settings: settings,
            mouthOpenAction: .clearInput
        )

        XCTAssertTrue(actions.isEmpty)
    }

    func testNoisyGestureStreamDoesNotGetStuckAcrossManyCycles() {
        var machine = GestureStateMachine()
        let start = Date(timeIntervalSince1970: 3_000)
        var actions: [ActionMapping] = []
        var cursor = start

        for _ in 0..<50 {
            actions.append(contentsOf: feed(&machine, gesture: .none, handPresent: true, from: cursor, count: 2))
            cursor = cursor.addingTimeInterval(0.28)
            actions.append(contentsOf: feed(&machine, gesture: .closedFist, handPresent: true, from: cursor, count: 6))
            cursor = cursor.addingTimeInterval(0.84)
            actions.append(contentsOf: feed(&machine, gesture: .none, handPresent: false, from: cursor, count: 22))
            cursor = cursor.addingTimeInterval(3.40)
        }

        XCTAssertEqual(actions.filter { $0 == .startDictation }.count, 50)
        XCTAssertEqual(actions.filter { $0 == .stopDictation }.count, 50)
        XCTAssertFalse(actions.contains(.pressReturn))
    }

    private func feed(
        _ machine: inout GestureStateMachine,
        gesture: GestureID,
        handPresent: Bool,
        from start: Date,
        count: Int,
        interval: TimeInterval = 0.14,
        profiles: [GestureProfile] = [],
        settings: BuiltInGestureSettings = BuiltInGestureSettings(),
        mouthOpenAction: ActionMapping = .none,
        mouthOpenConfidenceThreshold: Double = 0.80,
        closeMouthAutoStopEnabled: Bool = false,
        closeMouthAutoStopDelay: TimeInterval = 3.0,
        audioSilenceStopEnabled: Bool = false,
        audioSilenceThresholdDBFS: Double = -45,
        audioSilenceDelay: TimeInterval = 3.0,
        audioLevelDBFS: Double? = nil,
        confidence: Double? = nil
    ) -> [ActionMapping] {
        (0..<count).compactMap { index in
            let event = GestureEvent(
                gesture: gesture,
                confidence: confidence ?? (gesture == .none ? 0 : 0.84),
                handPresent: handPresent,
                timestamp: start.addingTimeInterval(Double(index) * interval),
                trackingPoint: nil
            )
            return machine.nextAction(
                for: event,
                profiles: profiles,
                builtInGestureSettings: settings,
                mouthOpenAction: mouthOpenAction,
                mouthOpenConfidenceThreshold: mouthOpenConfidenceThreshold,
                closeMouthAutoStopEnabled: closeMouthAutoStopEnabled,
                closeMouthAutoStopDelay: closeMouthAutoStopDelay,
                audioSilenceStopEnabled: audioSilenceStopEnabled,
                audioSilenceThresholdDBFS: audioSilenceThresholdDBFS,
                audioSilenceDelay: audioSilenceDelay,
                audioLevelDBFS: audioLevelDBFS
            )?.action
        }
    }

    private func feedWave(
        _ machine: inout GestureStateMachine,
        from start: Date,
        positions: [Double],
        interval: TimeInterval = 0.14
    ) -> [ActionMapping] {
        positions.enumerated().compactMap { index, x in
            let event = GestureEvent(
                gesture: .wave,
                confidence: 0.78,
                handPresent: true,
                timestamp: start.addingTimeInterval(Double(index) * interval),
                trackingPoint: LandmarkPoint(x: x, y: 0.5)
            )
            return machine.nextAction(for: event)?.action
        }
    }
}
