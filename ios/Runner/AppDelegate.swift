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

    // Let Supabase handle it
    let handled = super.application(app, open: url, options: options)
    print("🔗 Supabase handled: \(handled)")

    return handled
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
      if !selection.applicationTokens.isEmpty {
        store.shield.applications = selection.applicationTokens
      }
      if !selection.categoryTokens.isEmpty {
        store.shield.applicationCategories = .specific(selection.categoryTokens)
      }

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
      center.stopMonitoring()  // always clear before starting

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
      DeviceActivityCenter().stopMonitoring()
      ManagedSettingsStore().clearAllSettings()
      ScreenSageShared.defaults?.set(false, forKey: ScreenSageShared.sessionActive)
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
      center.stopMonitoring([DeviceActivityName("screensage.free.session")])

      do {
        try center.startMonitoring(
          DeviceActivityName("screensage.free.session"),
          during: schedule
        )
        // Persist free session end time so extension can read it
        ScreenSageShared.defaults?.set(
          end.timeIntervalSince1970,
          forKey: "ScreenSageFreeSessionEnd"
        )
        result(true)
      } catch {
        print("❌ scheduleFreeSession error: \(error)")
        result(true)  // Non-fatal on simulator path
      }
    }

    private func reApplyShields(result: FlutterResult) {
      guard
        let data = ScreenSageShared.defaults?.data(
          forKey: ScreenSageShared.selectionKey),
        let selection = try? PropertyListDecoder().decode(
          FamilyActivitySelection.self, from: data)
      else {
        result(true)  // No selection saved — nothing to re-apply
        return
      }

      let store = ManagedSettingsStore()
      if !selection.applicationTokens.isEmpty {
        store.shield.applications = selection.applicationTokens
      }
      if !selection.categoryTokens.isEmpty {
        store.shield.applicationCategories = .specific(selection.categoryTokens)
      }
      if !selection.webDomainTokens.isEmpty {
        store.shield.webDomains = selection.webDomainTokens
      }

      // Stop free session monitoring
      DeviceActivityCenter().stopMonitoring([
        DeviceActivityName("screensage.free.session")
      ])

      result(true)
    }
  #endif

}
