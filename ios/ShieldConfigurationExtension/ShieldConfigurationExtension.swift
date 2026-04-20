//
//  ShieldConfigurationExtension.swift
//  ShieldConfigurationExtension
//
//  Created by Puru on 24/02/26.
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

// Override the functions below to customize the shields used in various situations.
// The system provides a default appearance for any methods that your subclass doesn't override.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
@available(iOS 16.0, *)
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
  override func configuration(shielding application: Application) -> ShieldConfiguration {
    // Customize the shield as needed for applications.
    return makeShieldConfiguration()
  }

  override func configuration(shielding application: Application, in category: ActivityCategory)
    -> ShieldConfiguration
  {
    // Customize the shield as needed for applications shielded because of their category.
    return makeShieldConfiguration()
  }

  override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
    // Customize the shield as needed for web domains.
    return makeShieldConfiguration()
  }

  override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory)
    -> ShieldConfiguration
  {
    // Customize the shield as needed for web domains shielded because of their category.
    return makeShieldConfiguration()
  }

  // MARK: - Single source of truth for the shield UI
  // This is your brand moment — the screen the user sees when they try to open a blocked app.
  // Keep it motivating, not punishing. That's your brand identity.
  private func makeShieldConfiguration() -> ShieldConfiguration {

    // Read override count to personalise the message
    let overrides =
      ScreenSageShared.defaults?.integer(
        forKey: ScreenSageShared.overrideKey
      ) ?? 0

    let subtitle =
      overrides == 0
      ? "You haven't broken focus yet today. Don't start now."
      : "You've overridden \(overrides) time\(overrides == 1 ? "" : "s") today."

    return ShieldConfiguration(
      backgroundColor: UIColor(red: 0.06, green: 0.06, blue: 0.10, alpha: 1.0),
      // Use your app icon from assets
      // Note: extensions cannot access main app's Assets.xcassets
      // Copy your logo PNG into the extension's own Assets.xcassets
      icon: UIImage(named: "ShieldLogo"),
      title: ShieldConfiguration.Label(
        text: "You're in focus mode",
        color: .white
      ),
      subtitle: ShieldConfiguration.Label(
        text: subtitle,
        color: UIColor.white.withAlphaComponent(0.65)
      ),
      // Primary = the "escape" button — make it feel costly
      primaryButtonLabel: ShieldConfiguration.Label(
        text: "Override (lose streak)",
        color: UIColor.systemRed.withAlphaComponent(0.9)
      ),
      primaryButtonBackgroundColor: UIColor(
        red: 0.20, green: 0.06, blue: 0.06, alpha: 1.0
      ),
      // Secondary = the "stay" button — make it feel rewarding
      secondaryButtonLabel: ShieldConfiguration.Label(
        text: "Stay focused ✓",
        color: UIColor(red: 0.4, green: 0.9, blue: 0.6, alpha: 1.0)
      )
    )
  }
}
