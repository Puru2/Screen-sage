//
//  DeviceActivityMonitorExtension.swift
//  DeviceActivityExtension
//
//  Created by Puru on 24/02/26.
//

import DeviceActivity
import Foundation
import ManagedSettings
import UserNotifications

// Optionally override any of the functions below.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
@available(iOS 16.0, *)
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

  // Each extension gets its own ManagedSettingsStore instance.
  // The store is scoped to the app group automatically when FamilyControls entitlement is present.
  private let store = ManagedSettingsStore()

  // Called when the monitored schedule STARTS (session begins)
  // intervalStart DateComponents fires this
  override func intervalDidStart(for activity: DeviceActivityName) {
    super.intervalDidStart(for: activity)

    let name = activity.rawValue

    if name == ScreenSageShared.freeActivityName {
      // Earned free time just began — shields stay DOWN.
      ScreenSageShared.setBlockMode("none")
      return
    }

    if name.hasPrefix(ScreenSageShared.blockWindowActivityPrefix) {
      // A scheduled daily block window just started.
      guard !ScreenSageShared.isFreeSessionActive else { return }
      ScreenSageShared.applyStoredShield(store)
      ScreenSageShared.setBlockMode(
        "schedule",
        windowEndLabel: ScreenSageShared.activeWindow()?.endLabel
      )
      return
    }

    // Focus session just started — apply shield immediately as a safety net
    // (AppDelegate also applies it, but this covers edge cases like device restart)
    ScreenSageShared.applyStoredShield(store)
    ScreenSageShared.setBlockMode("session")
  }

  // Called when the monitored schedule ENDS (session timer ran out naturally)
  // This is your "session complete" signal
  override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)

    let name = activity.rawValue

    if name == ScreenSageShared.freeActivityName {
      // Free time is up — re-lock only if a session/window says so.
      ScreenSageShared.defaults?.removeObject(
        forKey: ScreenSageShared.freeSessionEndKey
      )
      ScreenSageShared.evaluateShieldState(store)
      sendNotification(
        title: "Free time ended ⏰",
        body: "Apps are re-locked. Ready for another focus session?"
      )
      return
    }

    if name == ScreenSageShared.activityName {
      ScreenSageShared.defaults?.set(
        false, forKey: ScreenSageShared.sessionActive)
      // Keep shields up if a scheduled block window is still active.
      ScreenSageShared.evaluateShieldState(store)
      sendNotification(
        title: "Focus session complete 🎉",
        body: "You stayed focused. Your streak is safe."
      )
      return
    }

    if name.hasPrefix(ScreenSageShared.blockWindowActivityPrefix) {
      // Block window ended — clear unless another window/session is active.
      ScreenSageShared.evaluateShieldState(store)
      return
    }
  }

  // Called when user has spent X minutes on a blocked app (threshold reached)
  // This fires when someone opens a blocked app and hits their warning threshold
  override func eventDidReachThreshold(
    _ event: DeviceActivityEvent.Name, activity: DeviceActivityName
  ) {
    super.eventDidReachThreshold(event, activity: activity)

    // Re-apply shield in case it was cleared somehow —
    // but never during earned free time.
    guard !ScreenSageShared.isFreeSessionActive else { return }
    ScreenSageShared.applyStoredShield(store)
  }

  // intervalWillStartWarning: called before schedule starts — not needed for us
  // but left here as super() call is safe
  override func intervalWillStartWarning(for activity: DeviceActivityName) {
    super.intervalWillStartWarning(for: activity)

  }

  // Called 1 minute before intervalEnd (the warningTime you set in schedule)
  override func intervalWillEndWarning(for activity: DeviceActivityName) {
    super.intervalWillEndWarning(for: activity)

    // Only nudge for focus sessions — not for daily block windows.
    guard activity.rawValue == ScreenSageShared.activityName else { return }
    sendNotification(
      title: "Almost there ⏱",
      body: "1 minute left in your focus session. Hang on!"
    )
  }

  // Called 1 minute before eventDidReachThreshold
  override func eventWillReachThresholdWarning(
    _ event: DeviceActivityEvent.Name, activity: DeviceActivityName
  ) {
    super.eventWillReachThresholdWarning(event, activity: activity)

    sendNotification(
      title: "Warning ⚠️",
      body: "You're close to breaking your focus. Stay strong!"
    )
  }

  // MARK: - Private Helpers

  private func sendNotification(title: String, body: String) {
    // Extensions have a hard 5MB memory limit — keep this lightweight
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default

    let request = UNNotificationRequest(
      identifier: UUID().uuidString,
      content: content,
      trigger: nil  // deliver immediately
    )

    UNUserNotificationCenter.current().add(request) { error in
      // Silently ignore — extension is not the right place for error handling
      _ = error
    }
  }
}
