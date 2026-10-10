//
//  ShieldActionExtension.swift
//  ShieldActionExtension
//
//  Created by Puru on 24/02/26.
//

import Foundation
import ManagedSettings
import UserNotifications

// Override the functions below to customize the shield actions used in various situations.
// The system provides a default response for any functions that your subclass doesn't override.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
@available(iOS 16.0, *)
class ShieldActionExtension: ShieldActionDelegate {
  override func handle(
    action: ShieldAction,
    for application: ApplicationToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    switch action {
    case .primaryButtonPressed:
      handlePrimaryPress(completionHandler: completionHandler) {
        // Safely scope the unblock to ONLY this specific app
        let store = ManagedSettingsStore()
        var shieldedApps = store.shield.applications ?? Set<ApplicationToken>()
        shieldedApps.remove(application)
        store.shield.applications = shieldedApps
      }

    case .secondaryButtonPressed:
      // "Stay focused" -> close the shield and return to home screen
      completionHandler(.close)

    @unknown default:
      completionHandler(.defer)
    }
  }

  // MARK: - Category Shield Handler
  override func handle(
    action: ShieldAction,
    for category: ActivityCategoryToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    switch action {
    case .primaryButtonPressed:
      handlePrimaryPress(completionHandler: completionHandler) {
        let store = ManagedSettingsStore()
        // If you blocked by category (e.g., all Social apps)
        if case .specific(let categories, except: let exceptions) =
          store.shield.applicationCategories
        {
          var updated = categories
          updated.remove(category)
          store.shield.applicationCategories = .specific(updated, except: exceptions)
        }
      }
    case .secondaryButtonPressed:
      completionHandler(.close)
    @unknown default:
      completionHandler(.defer)
    }
  }

  // MARK: - Web Domain Shield Handler
  override func handle(
    action: ShieldAction,
    for webDomain: WebDomainToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    switch action {
    case .primaryButtonPressed:
      handlePrimaryPress(completionHandler: completionHandler) {
        let store = ManagedSettingsStore()
        var shieldedDomains = store.shield.webDomains ?? Set<WebDomainToken>()
        shieldedDomains.remove(webDomain)
        store.shield.webDomains = shieldedDomains
      }
    case .secondaryButtonPressed:
      completionHandler(.close)
    @unknown default:
      completionHandler(.defer)
    }
  }

  // MARK: - Primary button routing
  /// Session mode: the primary button is the costly "override" — drop the
  /// shield for THIS app only.
  /// Schedule mode: the primary button is the CTA — open ScreenSage's Earned
  /// Time page so the user can unlock a break with their earned minutes.
  private func handlePrimaryPress(
    completionHandler: @escaping (ShieldActionResponse) -> Void,
    unblock: () -> Void
  ) {
    recordOverride()

    let mode =
      ScreenSageShared.defaults?.string(forKey: ScreenSageShared.blockModeKey)
      ?? "session"

    if mode == "schedule" {
      // Extensions can't open the host app directly (no ShieldActionResponse
      // case allows it). Hand off via shared storage — the app reads this
      // flag on launch/resume and lands on the Earned Time tab.
      let defaults = ScreenSageShared.defaults
      defaults?.set(true, forKey: ScreenSageShared.pendingUnlockKey)
      defaults?.set(
        Date().timeIntervalSince1970,
        forKey: ScreenSageShared.unlockRequestedAtKey
      )

      // Instant local notification — tapping it opens ScreenSage at Earned Time.
      let content = UNMutableNotificationContent()
      content.title = "Take a mindful break 🌿"
      content.body =
        "Tap to open ScreenSage and unlock time with your earned minutes."
      content.sound = .default
      content.userInfo = ["payload": ScreenSageShared.earnedDeepLink]
      UNUserNotificationCenter.current().add(
        UNNotificationRequest(
          identifier: UUID().uuidString, content: content, trigger: nil),
        withCompletionHandler: nil
      )

      completionHandler(.close)
      return
    }

    unblock()
    // .defer tells iOS to re-evaluate the store, notice the app is clear, and dismiss the shield
    completionHandler(.defer)
  }

  // MARK: - Override recording
  private func recordOverride() {
    guard let defaults = ScreenSageShared.defaults else { return }

    // Resettable counter — Flutter syncs it to the backend, then clears it.
    let current = defaults.integer(forKey: ScreenSageShared.overrideKey)
    defaults.set(current + 1, forKey: ScreenSageShared.overrideKey)

    // Lifetime counter — NEVER reset. Drives the shield message rotation.
    let total = defaults.integer(forKey: ScreenSageShared.shieldPressTotalKey)
    defaults.set(total + 1, forKey: ScreenSageShared.shieldPressTotalKey)

    defaults.synchronize()  // force-write immediately since extension may be killed
    // Flutter reads OverrideCount on next app foreground and updates streak/analytics
  }
}
