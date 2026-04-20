//
//  ShieldActionExtension.swift
//  ShieldActionExtension
//
//  Created by Puru on 24/02/26.
//

import ManagedSettings

// Override the functions below to customize the shield actions used in various situations.
// The system provides a default response for any functions that your subclass doesn't override.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
@available(iOS 16.0, *)
class ShieldActionExtension: ShieldActionDelegate {
  override func handle(
    action: ShieldAction, for application: ApplicationToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    handleAction(action, completionHandler: completionHandler)
  }

  override func handle(
    action: ShieldAction, for webDomain: WebDomainToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    handleAction(action, completionHandler: completionHandler)
  }

  override func handle(
    action: ShieldAction, for category: ActivityCategoryToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    handleAction(action, completionHandler: completionHandler)
  }

  // MARK: - Shared handler
  private func handleAction(
    _ action: ShieldAction,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    switch action {
    case .primaryButtonPressed:
      // Primary = "Override (lose streak)" — RED button
      // User chose to break focus
      recordOverride()
      //   ManagedSettingsStore().clearAllSettings()
      completionHandler(.close)  // Open the app

    case .secondaryButtonPressed:
      // Secondary = "Stay focused ✓" — GREEN button
      // User chose to stay focused — send back to home screen
      completionHandler(.defer)

    @unknown default:
      completionHandler(.defer)
    }
  }

  // MARK: - Override recording
  private func recordOverride() {
    guard let defaults = ScreenSageShared.defaults else { return }
    let current = defaults.integer(forKey: ScreenSageShared.overrideKey)
    defaults.set(current + 1, forKey: ScreenSageShared.overrideKey)
    defaults.synchronize()  // force-write immediately since extension may be killed
    // Flutter reads OverrideCount on next app foreground and updates streak/analytics
  }
}
