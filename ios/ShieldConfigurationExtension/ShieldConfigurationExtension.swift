//
//  ShieldConfigurationExtension.swift
//  ShieldConfigurationExtension
//
//  Created by Puru on 24/02/26.
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

@available(iOS 16.0, *)
class ShieldConfigurationExtension: ShieldConfigurationDataSource {

  override func configuration(shielding application: Application) -> ShieldConfiguration {
    makeShieldConfiguration()
  }

  override func configuration(shielding application: Application, in category: ActivityCategory)
    -> ShieldConfiguration
  {
    makeShieldConfiguration()
  }

  override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
    makeShieldConfiguration()
  }

  override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory)
    -> ShieldConfiguration
  {
    makeShieldConfiguration()
  }

  // MARK: - Design tokens
  private enum Theme {
    static let background = UIColor(red: 0.05, green: 0.05, blue: 0.09, alpha: 1.0)
    static let mint = UIColor(red: 0.42, green: 0.92, blue: 0.64, alpha: 1.0)
    static let mintDeep = UIColor(red: 0.04, green: 0.13, blue: 0.09, alpha: 1.0)
    static let titleText = UIColor.white
    static let bodyText = UIColor.white.withAlphaComponent(0.72)
    static let dangerText = UIColor(red: 1.0, green: 0.62, blue: 0.62, alpha: 1.0)
    static let dangerFill = UIColor(red: 0.30, green: 0.09, blue: 0.11, alpha: 1.0)
  }

  // MARK: - Rounded logo
  // ShieldConfiguration can't round its icon, so we pre-render it.
  private static let roundedLogo: UIImage? = {
    guard let source = UIImage(named: "ShieldLogo") else { return nil }

    let side: CGFloat = 120
    let inset: CGFloat = 4  // room for the ring stroke
    let canvas = CGSize(width: side, height: side)

    let format = UIGraphicsImageRendererFormat()
    format.scale = 3
    format.opaque = false

    return UIGraphicsImageRenderer(size: canvas, format: format).image { _ in
      let rect = CGRect(origin: .zero, size: canvas).insetBy(dx: inset, dy: inset)
      let radius = rect.width * 0.26  // soft squircle-style corners
      let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)

      // Logo, clipped to rounded shape
      UIGraphicsGetCurrentContext()?.saveGState()
      path.addClip()
      source.draw(in: rect)
      UIGraphicsGetCurrentContext()?.restoreGState()

      // Subtle mint ring
      Theme.mint.withAlphaComponent(0.35).setStroke()
      path.lineWidth = 2
      path.stroke()
    }
  }()

  // MARK: - Entry point
  private func makeShieldConfiguration() -> ShieldConfiguration {
    let defaults = ScreenSageShared.defaults
    let presses = defaults?.integer(forKey: ScreenSageShared.shieldPressTotalKey) ?? 0
    let mode = defaults?.string(forKey: ScreenSageShared.blockModeKey) ?? "session"

    return mode == "schedule"
      ? makeScheduleShield(presses: presses)
      : makeSessionShield(presses: presses)
  }

  // MARK: - Focus-session shield
  private func makeSessionShield(presses: Int) -> ShieldConfiguration {
    let titles = [
      "You're in focus mode",
      "Protect your momentum",
      "This can wait.\nYour goals can't.",
      "Future you is watching",
      "Deep work beats\nquick scrolls",
    ]
    let title = titles[presses % titles.count]

    let subtitle =
      presses == 0
      ? "You haven't broken focus yet today.\nDon't start now."
      : "You've pushed past the shield \(presses) time\(presses == 1 ? "" : "s").\nMake this the last."

    return ShieldConfiguration(
      backgroundBlurStyle: .systemThickMaterialDark,  // forces dark, fixes invisible text
      backgroundColor: Theme.background,
      icon: Self.roundedLogo,
      title: .init(text: title, color: Theme.titleText),
      subtitle: .init(text: subtitle, color: Theme.bodyText),
      primaryButtonLabel: .init(text: "Override (lose streak)", color: Theme.dangerText),
      primaryButtonBackgroundColor: Theme.dangerFill,
      secondaryButtonLabel: .init(text: "Stay focused ✓", color: Theme.mint)
    )
  }

  // MARK: - Scheduled-downtime shield
  private func makeScheduleShield(presses: Int) -> ShieldConfiguration {
    let defaults = ScreenSageShared.defaults
    let endLabel = defaults?.string(forKey: ScreenSageShared.blockWindowEndLabelKey)

    let titles = [
      "Downtime is on",
      "This app is resting",
      "Stay on your path",
      "Nothing new here",
      "Your time,\non your terms",
    ]
    let title = titles[presses % titles.count]

    let until = endLabel.map { " until \($0)" } ?? ""
    let subtitle =
      "Paused\(until), not gone.\n"
      + "Need a breather? Spend your earned minutes and the shield lifts for a while."

    return ShieldConfiguration(
      backgroundBlurStyle: .systemThickMaterialDark,
      backgroundColor: Theme.background,
      icon: Self.roundedLogo,
      title: .init(text: title, color: Theme.titleText),
      subtitle: .init(text: subtitle, color: Theme.bodyText),
      // Solid mint button with dark text = clear primary call to action
      primaryButtonLabel: .init(text: "Use Earned Minutes →", color: Theme.mintDeep),
      primaryButtonBackgroundColor: Theme.mint,
      secondaryButtonLabel: .init(text: "Keep going ✓", color: Theme.mint)
    )
  }
}
