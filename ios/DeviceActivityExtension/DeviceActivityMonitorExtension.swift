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

    // Session just started — apply shield immediately as a safety net
    // (AppDelegate also applies it, but this covers edge cases like device restart)
    applyShield()
  }

  // Called when the monitored schedule ENDS (session timer ran out naturally)
  // This is your "session complete" signal
  override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)

    switch activity.rawValue {

    case "screensage.free.session":
      // Free time is up — re-apply shields automatically
      applyShield()
      // Clear free session marker
      ScreenSageShared.defaults?.removeObject(forKey: "ScreenSageFreeSessionEnd")
      sendNotification(
        title: "Free time ended ⏰",
        body: "Apps are re-locked. Ready for another focus session?"
      )

    case ScreenSageShared.activityName:
      clearShield()
      ScreenSageShared.defaults?.set(
        false, forKey: ScreenSageShared.sessionActive)
      sendNotification(
        title: "Focus session complete 🎉",
        body: "You stayed focused. Your streak is safe."
      )

    default:
      break
    }
  }

  // Called when user has spent X minutes on a blocked app (threshold reached)
  // This fires when someone opens a blocked app and hits their warning threshold
  override func eventDidReachThreshold(
    _ event: DeviceActivityEvent.Name, activity: DeviceActivityName
  ) {
    super.eventDidReachThreshold(event, activity: activity)

    // Re-apply shield in case it was cleared somehow
    applyShield()
  }

  // intervalWillStartWarning: called before schedule starts — not needed for us
  // but left here as super() call is safe
  override func intervalWillStartWarning(for activity: DeviceActivityName) {
    super.intervalWillStartWarning(for: activity)

  }

  // Called 1 minute before intervalEnd (the warningTime you set in schedule)
  override func intervalWillEndWarning(for activity: DeviceActivityName) {
    super.intervalWillEndWarning(for: activity)

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

  private func applyShield() {
    guard let data = ScreenSageShared.defaults?.data(forKey: ScreenSageShared.selectionKey),
      let selection = try? PropertyListDecoder().decode(
        FamilyActivitySelection.self, from: data
      )
    else {
      // No selection saved — nothing to shield. Not an error.
      return
    }

    // Only set if non-empty to avoid overwriting with nil accidentally
    if !selection.applicationTokens.isEmpty {
      store.shield.applications = selection.applicationTokens
    }
    if !selection.categoryTokens.isEmpty {
      store.shield.applicationCategories = .specific(selection.categoryTokens)
    }
    if !selection.webDomainTokens.isEmpty {
      store.shield.webDomains = selection.webDomainTokens
    }
  }

  private func clearShield() {
    // clearAllSettings() clears shield + any other ManagedSettings rules
    store.clearAllSettings()
  }

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
