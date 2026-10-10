import Flutter
import SwiftUI
import UIKit
import UserNotifications

#if !targetEnvironment(simulator)
  import DeviceActivity
  import FamilyControls
  import ManagedSettings
#endif

@main
@objc class AppDelegate: FlutterAppDelegate {

  private var screenTimeChannel: FlutterMethodChannel?
  private var pendingDeepLink: String?

  // ── App Launch ────────────────────────────────────────────────────
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    setupScreenTimeChannel()
    setupNotifications()
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // ── Deep Link / OAuth Callback ────────────────────────────────────
  // This is the SEPARATE method — fires when Safari redirects back to app
  // e.g. com.pratham.screensage://auth-callback?code=xxx
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    print("🔗 App opened with URL: \(url.absoluteString)")
    print("🔗 URL scheme: \(url.scheme ?? "nil")")
    print("🔗 Host: \(url.host ?? "nil")")

    // Our own scheme — e.g. the shield CTA opens screensage://earned
    if url.scheme == "screensage" {
      handleDeepLink(url.absoluteString)
      return true
    }

    // Let Supabase handle it
    let handled = super.application(app, open: url, options: options)
    print("🔗 Supabase handled: \(handled)")

    return handled
  }

  // ── Deep Links ────────────────────────────────────────────────────
  private func handleDeepLink(_ url: String) {
    // Buffer for cold starts AND forward live — Dart dedupes by route.
    pendingDeepLink = url
    screenTimeChannel?.invokeMethod("onDeepLink", arguments: url)
  }

  // ── Screen Time Channel Setup ─────────────────────────────────────
  private func setupScreenTimeChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "com.screensage/screentime",
      binaryMessenger: controller.binaryMessenger
    )
    screenTimeChannel = channel

    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {

      case "requestAuthorization":
        #if !targetEnvironment(simulator)
          Task {
            do {
              try await AuthorizationCenter.shared
                .requestAuthorization(for: .individual)
              result(true)
            } catch {
              result(
                FlutterError(
                  code: "AUTH_FAILED",
                  message: error.localizedDescription,
                  details: nil
                ))
            }
          }
        #else
          // Simulator: mock success so Flutter UI doesn't break
          result(true)
        #endif

      case "showAppPicker":
        #if !targetEnvironment(simulator)
          self?.showFamilyActivityPicker(result: result)
        #else
          result(true)
        #endif

      case "startSession":
        guard let args = call.arguments as? [String: Any],
          let minutes = args["durationMinutes"] as? Int,
          minutes > 0
        else {
          result(
            FlutterError(
              code: "BAD_ARGS",
              message: "durationMinutes required and must be > 0",
              details: nil
            ))
          return
        }
        #if !targetEnvironment(simulator)
          self?.startSession(durationMinutes: minutes, result: result)
        #else
          result(true)
        #endif

      case "endSession":
        #if !targetEnvironment(simulator)
          self?.endSession(result: result)
        #else
          result(true)
        #endif

      case "getOverrideCount":
        let count =
          ScreenSageShared.defaults?.integer(
            forKey: ScreenSageShared.overrideKey
          ) ?? 0
        result(count)

      case "resetOverrideCount":
        ScreenSageShared.defaults?.set(0, forKey: ScreenSageShared.overrideKey)
        result(true)

      case "getAuthorizationStatus":
        #if !targetEnvironment(simulator)
          let status = AuthorizationCenter.shared.authorizationStatus
          switch status {
          case .approved: result("approved")
          case .denied: result("denied")
          case .notDetermined: result("notDetermined")
          @unknown default: result("notDetermined")
          }
        #else
          result("approved")  // simulator always "approved" for UI testing
        #endif

      case "getSelectedAppCount":
        #if !targetEnvironment(simulator)
          let count: Int
          if let data = ScreenSageShared.defaults?.data(
            forKey: ScreenSageShared.selectionKey),
            let selection = try? PropertyListDecoder().decode(
              FamilyActivitySelection.self, from: data)
          {
            count =
              selection.applicationTokens.count
              + selection.categoryTokens.count
              + selection.webDomainTokens.count
          } else {
            count = 0
          }
          result(count)
        #else
          result(0)
        #endif

      case "scheduleFreeSession":
        guard let args = call.arguments as? [String: Any],
          let minutes = args["durationMinutes"] as? Int
        else {
          result(false)
          return
        }
        #if !targetEnvironment(simulator)
          self?.scheduleFreeSession(durationMinutes: minutes, result: result)
        #else
          result(true)
        #endif

      case "reApplyShields":
        #if !targetEnvironment(simulator)
          self?.reApplyShields(result: result)
        #else
          result(true)
        #endif

      case "openSettings":
        if let url = URL(string: UIApplication.openSettingsURLString) {
          DispatchQueue.main.async {
            UIApplication.shared.open(url)
          }
        }
        result(nil)

      case "setBlockWindows":
        #if !targetEnvironment(simulator)
          self?.setBlockWindows(args: call.arguments as? [String: Any], result: result)
        #else
          result(true)
        #endif

      case "getPendingDeepLink":
        let link = self?.pendingDeepLink ?? nil
        self?.pendingDeepLink = nil
        result(link)

      case "consumePendingUnlock":
        // One-shot read of the shield CTA handoff flag (stale after 30 min).
        let d = ScreenSageShared.defaults
        let pending = d?.bool(forKey: ScreenSageShared.pendingUnlockKey) ?? false
        let at = d?.double(forKey: ScreenSageShared.unlockRequestedAtKey) ?? 0
        let fresh = Date().timeIntervalSince1970 - at < 1800
        d?.removeObject(forKey: ScreenSageShared.pendingUnlockKey)
        d?.removeObject(forKey: ScreenSageShared.unlockRequestedAtKey)
        result(pending && fresh)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // ── Notifications ─────────────────────────────────────────────────
  private func setupNotifications() {
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .sound, .badge]
    ) { _, _ in }
  }

  // ── FamilyActivityPicker (Device only) ───────────────────────────
  #if !targetEnvironment(simulator)
    private func showFamilyActivityPicker(result: @escaping FlutterResult) {
      guard let rootVC = window?.rootViewController else {
        result(FlutterError(code: "NO_ROOT_VC", message: "No root view controller", details: nil))
        return
      }

      let model = AppSelectionModel()

      // Pre-load previously saved selection
      if let data = ScreenSageShared.defaults?.data(forKey: ScreenSageShared.selectionKey),
        let saved = try? PropertyListDecoder().decode(
          FamilyActivitySelection.self, from: data
        )
      {
        model.selection = saved
      }

      let pickerVC = UIHostingController(
        rootView: AppPickerView(model: model) {
          if let encoded = try? PropertyListEncoder().encode(model.selection) {
            ScreenSageShared.defaults?.set(encoded, forKey: ScreenSageShared.selectionKey)
            ScreenSageShared.defaults?.synchronize()
          }
          rootVC.dismiss(animated: true)
          result(true)
        }
      )
      pickerVC.modalPresentationStyle = .pageSheet
      rootVC.present(pickerVC, animated: true)
    }

    private func startSession(durationMinutes: Int, result: FlutterResult) {
      guard durationMinutes >= 15 else {
        result(
          FlutterError(
            code: "DURATION_TOO_SHORT",
            message: "Sessions must be at least 15 minutes on iOS.",
            details: nil
          ))
        return
      }
      guard let data = ScreenSageShared.defaults?.data(forKey: ScreenSageShared.selectionKey),
        let selection = try? PropertyListDecoder().decode(
          FamilyActivitySelection.self, from: data
        )
      else {
        result(
          FlutterError(
            code: "NO_SELECTION",
            message: "No apps selected. Call showAppPicker first.",
            details: nil
          ))
        return
      }

      // Apply shield immediately
      let store = ManagedSettingsStore()
      ScreenSageShared.applyStoredShield(store)

      // ── ADD THIS — silence notifications from blocked apps ──────────
      // if !selection.applicationTokens.isEmpty {
      //   store.shield.applicationCategories = store.shield.applicationCategories  // keep existing
      //   // Block notifications from selected apps
      //   store.notifications.blocked = .specific(selection.applicationTokens)
      // }

      // Build session window
      let now = Date()
      let endDate = Calendar.current.date(
        byAdding: .minute, value: durationMinutes, to: now
      )!

      let schedule = DeviceActivitySchedule(
        intervalStart: Calendar.current.dateComponents(
          [.year, .month, .day, .hour, .minute, .second], from: now
        ),
        intervalEnd: Calendar.current.dateComponents(
          [.year, .month, .day, .hour, .minute, .second], from: endDate
        ),
        repeats: false,
        warningTime: DateComponents(minute: 1)
      )

      let event = DeviceActivityEvent(
        applications: selection.applicationTokens,
        categories: selection.categoryTokens.isEmpty ? [] : selection.categoryTokens,
        webDomains: selection.webDomainTokens.isEmpty ? [] : selection.webDomainTokens,
        threshold: DateComponents(second: 1)
      )

      let center = DeviceActivityCenter()
      // Only reset the focus activity — scheduled block windows keep running.
      center.stopMonitoring([DeviceActivityName(ScreenSageShared.activityName)])

      do {
        try center.startMonitoring(
          DeviceActivityName(ScreenSageShared.activityName),
          during: schedule,
          events: [DeviceActivityEvent.Name(ScreenSageShared.eventName): event]
        )

        // Persist state for extensions to read
        ScreenSageShared.defaults?.set(true, forKey: ScreenSageShared.sessionActive)
        ScreenSageShared.defaults?.set(
          endDate.timeIntervalSince1970,
          forKey: ScreenSageShared.sessionEndTime
        )
        ScreenSageShared.setBlockMode("session")

        result(true)
      } catch {
        store.clearAllSettings()
        result(
          FlutterError(
            code: "MONITOR_FAILED",
            message: error.localizedDescription,
            details: nil
          ))
      }
    }

    private func endSession(result: FlutterResult) {
      DeviceActivityCenter().stopMonitoring([
        DeviceActivityName(ScreenSageShared.activityName)
      ])
      ScreenSageShared.defaults?.set(false, forKey: ScreenSageShared.sessionActive)
      // Keep shields up if a scheduled block window is active right now.
      ScreenSageShared.evaluateShieldState(ManagedSettingsStore())
      result(true)
    }
  #endif

  #if !targetEnvironment(simulator)
    private func scheduleFreeSession(durationMinutes: Int, result: FlutterResult) {
      // Shields are already lifted by endSession() called before this
      // We just schedule DeviceActivity to re-apply shields after N minutes
      let now = Date()
      let end = Calendar.current.date(
        byAdding: .minute, value: durationMinutes, to: now)!

      let schedule = DeviceActivitySchedule(
        intervalStart: Calendar.current.dateComponents(
          [.year, .month, .day, .hour, .minute, .second], from: now),
        intervalEnd: Calendar.current.dateComponents(
          [.year, .month, .day, .hour, .minute, .second], from: end),
        repeats: false
      )

      let center = DeviceActivityCenter()
      center.stopMonitoring([DeviceActivityName(ScreenSageShared.freeActivityName)])

      do {
        try center.startMonitoring(
          DeviceActivityName(ScreenSageShared.freeActivityName),
          during: schedule
        )
        // Persist free session end time so extensions can read it
        ScreenSageShared.defaults?.set(
          end.timeIntervalSince1970,
          forKey: ScreenSageShared.freeSessionEndKey
        )
        // Earned time: shields come down NOW (even inside a block window)
        // and the free-session interval end re-locks them.
        ManagedSettingsStore().clearAllSettings()
        ScreenSageShared.setBlockMode("none")
        result(true)
      } catch {
        print("❌ scheduleFreeSession error: \(error)")
        result(true)  // Non-fatal on simulator path
      }
    }

    private func reApplyShields(result: FlutterResult) {
      // Free time is over — re-lock only if a focus session or a
      // scheduled block window is active right now.
      DeviceActivityCenter().stopMonitoring([
        DeviceActivityName(ScreenSageShared.freeActivityName)
      ])
      ScreenSageShared.defaults?.removeObject(
        forKey: ScreenSageShared.freeSessionEndKey
      )
      ScreenSageShared.evaluateShieldState(ManagedSettingsStore())
      result(true)
    }

    // ── Daily Block Windows (scheduled downtime) ────────────────────
    private func setBlockWindows(args: [String: Any]?, result: FlutterResult) {
      guard let raw = args?["windows"] as? [[String: Any]] else {
        result(
          FlutterError(
            code: "BAD_ARGS", message: "windows list required", details: nil))
        return
      }

      let windows: [BlockWindow] = raw.compactMap { dict in
        guard let id = dict["id"] as? String,
          let start = dict["startMinutes"] as? Int,
          let end = dict["endMinutes"] as? Int
        else { return nil }
        return BlockWindow(
          id: id,
          startMinutes: start,
          endMinutes: end,
          enabled: dict["enabled"] as? Bool ?? true
        )
      }

      // Stop monitoring every previously-saved window (covers removals)
      let center = DeviceActivityCenter()
      let oldNames = ScreenSageShared.loadBlockWindows().map {
        DeviceActivityName(ScreenSageShared.blockWindowActivityPrefix + $0.id)
      }
      let newNames = windows.map {
        DeviceActivityName(ScreenSageShared.blockWindowActivityPrefix + $0.id)
      }
      center.stopMonitoring(Array(Set(oldNames + newNames)))

      ScreenSageShared.saveBlockWindows(windows)

      // Re-register every enabled window as a daily repeating activity.
      for window in windows where window.enabled {
        let clampedEnd = min(window.endMinutes, 1439)
        let schedule = DeviceActivitySchedule(
          intervalStart: DateComponents(
            hour: window.startMinutes / 60,
            minute: window.startMinutes % 60,
            second: 0
          ),
          intervalEnd: DateComponents(
            hour: clampedEnd / 60,
            minute: clampedEnd % 60,
            second: 59
          ),
          repeats: true
        )
        do {
          try center.startMonitoring(
            DeviceActivityName(ScreenSageShared.blockWindowActivityPrefix + window.id),
            during: schedule
          )
        } catch {
          print("❌ block window monitoring failed: \(error)")
        }
      }

      // Reflect the change immediately — block or unblock right now.
      ScreenSageShared.evaluateShieldState(ManagedSettingsStore())
      result(true)
    }
  #endif

}
