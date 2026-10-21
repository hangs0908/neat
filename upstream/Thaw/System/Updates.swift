//
//  Updates.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Combine
import Sparkle
import SwiftUI

/// Sparkle appcast channels Thaw publishes to.
nonisolated enum UpdateChannel: String, CaseIterable, Identifiable {
    /// Default channel (no sparkle:channel in the appcast).
    case stable
    /// Development / RC builds (sparkle:channel = beta).
    case beta
    /// Alpha builds for macOS 27 (sparkle:channel = alpha).
    case alpha

    /// Neat은 단일 공개 채널만 제공한다.
    static let selectable: [UpdateChannel] = [.stable]

    /// Preserve the persisted key so existing channel choices carry over.
    static let defaultsKey = "UpdateChannel"

    var id: String {
        rawValue
    }

    var localized: LocalizedStringKey {
        switch self {
        case .stable: "Stable"
        case .beta: "Beta"
        case .alpha: "Alpha"
        }
    }

    /// Sparkle channel names to allow in addition to the default channel.
    var allowedSparkleChannels: Set<String> {
        switch self {
        case .stable:
            []
        case .beta:
            ["beta"]
        case .alpha:
            ["alpha"]
        }
    }
}

@MainActor
@Observable
final class UpdatesManager: NSObject {
    var canCheckForUpdates = false

    var lastUpdateCheckDate: Date?

    private(set) weak var appState: AppState?

    private var hasStartedUpdater = false

    /// The channel the user is subscribed to.
    var updateChannel: UpdateChannel {
        get {
            // Backed by UserDefaults, so Observation is registered by hand,
            // like the Sparkle-backed properties below.
            access(keyPath: \.updateChannel)
            return Self.storedUpdateChannel()
        }
        set {
            withMutation(keyPath: \.updateChannel) {
                UserDefaults.standard.set(newValue.rawValue, forKey: UpdateChannel.defaultsKey)
            }
            guard hasStartedUpdater else { return }
            updater.checkForUpdatesInBackground()
        }
    }

    /// 이전 채널 설정이 남아 있어도 Neat 공개 채널만 사용한다.
    static nonisolated func storedUpdateChannel() -> UpdateChannel {
        guard let raw = UserDefaults.standard.string(forKey: UpdateChannel.defaultsKey),
              let channel = UpdateChannel(rawValue: raw),
              UpdateChannel.selectable.contains(channel)
        else {
            return .stable
        }
        return channel
    }

    /// Mirrors Sparkle's KVO publishers into the stored properties above.
    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()

    @ObservationIgnored
    private(set) lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: self,
        userDriverDelegate: self
    )

    var updater: SPUUpdater {
        updaterController.updater
    }

    /// Sparkle-backed check/download preferences need explicit access and withMutation calls for Observation tracking.
    var automaticallyChecksForUpdates: Bool {
        get {
            access(keyPath: \.automaticallyChecksForUpdates)
            return updater.automaticallyChecksForUpdates
        }
        set {
            guard Constants.supportsSparkleUpdates else {
                return
            }
            withMutation(keyPath: \.automaticallyChecksForUpdates) {
                updater.automaticallyChecksForUpdates = newValue
                if newValue {
                    Defaults.set(true, forKey: .hasSeenUpdateConsent)
                }
            }
        }
    }

    var automaticallyDownloadsUpdates: Bool {
        get {
            access(keyPath: \.automaticallyDownloadsUpdates)
            return updater.automaticallyDownloadsUpdates
        }
        set {
            guard Constants.supportsSparkleUpdates, !newValue else {
                return
            }
            withMutation(keyPath: \.automaticallyDownloadsUpdates) {
                updater.automaticallyDownloadsUpdates = newValue
            }
        }
    }

    func performSetup(with appState: AppState) {
        guard Constants.supportsSparkleUpdates else { return }
        self.appState = appState
        _ = updaterController
        // Scrub SUFeedURL defaults that could redirect checks away from Info.plist; the delegate also ignores them.
        updater.clearFeedURLFromUserDefaults()
        // 이전 설정이 남아 있어도 동의 전 확인과 자동 다운로드를 허용하지 않는다.
        updater.automaticallyChecksForUpdates = Defaults.bool(forKey: .hasSeenUpdateConsent) && updater.automaticallyChecksForUpdates
        updater.automaticallyDownloadsUpdates = false

        // Sparkle's updater is KVO-backed, not @Observable; its publishers
        // mirror into the stored properties Observation can track.
        updater.publisher(for: \.canCheckForUpdates)
            .sink { [weak self] value in
                self?.canCheckForUpdates = value
            }
            .store(in: &cancellables)
        updater.publisher(for: \.lastUpdateCheckDate)
            .sink { [weak self] value in
                self?.lastUpdateCheckDate = value
            }
            .store(in: &cancellables)
        if Defaults.bool(forKey: .hasSeenUpdateConsent) {
            startUpdaterIfNeeded()
        }
    }

    func startUpdaterIfNeeded() {
        guard Constants.supportsSparkleUpdates, forwardCheck == nil else {
            return
        }
        guard !hasStartedUpdater else {
            return
        }
        hasStartedUpdater = true
        updaterController.startUpdater()
    }

    /// Set in the settings process, which hands checks to the app.
    @ObservationIgnored
    var forwardCheck: (() -> Void)?

    /// The settings process may have changed Sparkle's stored preferences. Sparkle reads
    /// them from the defaults, and a reset schedules the next check by them.
    func storedPreferencesChanged() {
        if Defaults.bool(forKey: .hasSeenUpdateConsent) {
            startUpdaterIfNeeded()
        }
        guard hasStartedUpdater else { return }
        withMutation(keyPath: \.automaticallyChecksForUpdates) {
            // Sparkle already holds the new value; observers only need to hear that it changed.
        }
        withMutation(keyPath: \.automaticallyDownloadsUpdates) {
            // Sparkle already holds the new value; observers only need to hear that it changed.
        }
        updater.resetUpdateCycleAfterShortDelay()
    }

    @objc func checkForUpdates() {
        guard Constants.supportsSparkleUpdates else {
            return
        }
        if let forwardCheck {
            forwardCheck()
            return
        }
        #if DEBUG
            // Checking for updates hangs in debug mode, except against a local
            // rehearsal feed (see feedURLString(for:)).
            guard UserDefaults.standard.string(forKey: "NeatDebugFeedURL") != nil else {
                let alert = NSAlert()
                alert.messageText = String(localized: "Checking for updates is not supported in debug mode.")
                alert.runModal()
                return
            }
        #endif
        guard let appState else {
            return
        }
        startUpdaterIfNeeded()
        // Activate the app in case an alert needs to be displayed.
        appState.activate(withPolicy: .regular)
        updater.checkForUpdates()
    }
}

// MARK: UpdatesManager: SPUUpdaterDelegate

extension UpdatesManager: SPUUpdaterDelegate {
    func updaterShouldPromptForPermissionToCheck(forUpdates _: SPUUpdater) -> Bool {
        // Consent belongs to the app's blocking sheet, never Sparkle's prompt.
        false
    }

    /// Pin the feed to Info.plist so writes to SUFeedURL defaults cannot redirect update checks to a foreign server.
    func feedURLString(for _: SPUUpdater) -> String? {
        #if DEBUG
            // Lets a Debug build rehearse the update flow against a local
            // appcast. Release builds never read it.
            if let debugFeed = UserDefaults.standard.string(forKey: "NeatDebugFeedURL") {
                return debugFeed
            }
        #endif
        return Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
    }

    func allowedChannels(for _: SPUUpdater) -> Set<String> {
        Self.storedUpdateChannel().allowedSparkleChannels
    }

    func updater(_: SPUUpdater, willScheduleUpdateCheckAfterDelay _: TimeInterval) {
        guard let appState else {
            return
        }
        appState.userNotificationManager.requestAuthorization()
    }
}

// MARK: UpdatesManager: SPUStandardUserDriverDelegate

extension UpdatesManager: @MainActor SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool {
        true
    }

    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        NSApp.isActive && immediateFocus
    }

    func standardUserDriverWillHandleShowingUpdate(
        _: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        guard let appState else {
            return
        }
        if !state.userInitiated {
            appState.userNotificationManager.addRequest(
                with: .updateCheck,
                title: String(localized: "A new update is available"),
                body: String(localized: "Version \(update.displayVersionString) (\(update.versionString)) is now available")
            )
        }
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate _: SUAppcastItem) {
        guard let appState else {
            return
        }
        appState.userNotificationManager.removeDeliveredNotifications(with: [.updateCheck])
    }
}
