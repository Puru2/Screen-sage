//
//  ScreenSageShared.swift
//  Runner
//
//  Created by Puru on 24/02/26.
//

import FamilyControls
import Foundation
import ManagedSettings

enum ScreenSageShared {

  static let appGroupID = "group.com.pratham.screensage.data"

  static let selectionKey = "ScreenSageSelection"
  static let overrideKey = "ScreenSageOverrideCount"
  /// Lifetime count of shield push-backs. Never reset — drives shield message rotation.
  static let shieldPressTotalKey = "ScreenSageShieldPressTotal"
  static let sessionActive = "ScreenSageSessionActive"
  static let sessionEndTime = "ScreenSageSessionEnd"
  static let freeSessionEndKey = "ScreenSageFreeSessionEnd"

  /// JSON-encoded [BlockWindow] — written by the main app, read by extensions.
  static let blockWindowsKey = "ScreenSageBlockWindows"
  /// "session" | "schedule" | "none" — tells the shield which copy to show.
  static let blockModeKey = "ScreenSageBlockMode"
  /// Human-readable "h:mm a" of when the current schedule window ends.
  static let blockWindowEndLabelKey = "ScreenSageBlockWindowEndLabel"
  /// Set by the shield CTA — the app routes to Earned Time on next open.
  static let pendingUnlockKey = "ScreenSagePendingUnlock"
  static let unlockRequestedAtKey = "ScreenSageUnlockRequestedAt"

  static let activityName = "screensage.focus.session"
  static let eventName = "screensage.focus.event"
  static let freeActivityName = "screensage.free.session"
  static let blockWindowActivityPrefix = "screensage.blockwindow."

  /// Deep link opened by the shield's CTA in schedule mode.
  static let earnedDeepLink = "screensage://earned"

  static var defaults: UserDefaults? {
    UserDefaults(suiteName: appGroupID)
  }
}

// MARK: - Daily block window model

struct BlockWindow: Codable {
  let id: String
  let startMinutes: Int  // minutes since midnight
  let endMinutes: Int  // minutes since midnight (1439 = full day end)
  let enabled: Bool

  var isFullDay: Bool { startMinutes == 0 && endMinutes >= 1439 }

  /// Handles windows that wrap past midnight (e.g. 22:00 → 02:00).
  func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
    guard startMinutes != endMinutes else { return false }
    let mins =
      calendar.component(.hour, from: date) * 60
      + calendar.component(.minute, from: date)
    if startMinutes < endMinutes {
      return mins >= startMinutes && mins < endMinutes
    }
    return mins >= startMinutes || mins < endMinutes
  }

  var endLabel: String {
    var comps = DateComponents()
    comps.hour = (endMinutes / 60) % 24
    comps.minute = endMinutes % 60
    let date = Calendar.current.date(from: comps) ?? Date()
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    return formatter.string(from: date)
  }
}

// MARK: - Shared state helpers (app + extensions)

extension ScreenSageShared {

  static func loadBlockWindows() -> [BlockWindow] {
    guard let json = defaults?.string(forKey: blockWindowsKey),
      let data = json.data(using: .utf8),
      let windows = try? JSONDecoder().decode([BlockWindow].self, from: data)
    else { return [] }
    return windows
  }

  static func saveBlockWindows(_ windows: [BlockWindow]) {
    guard let data = try? JSONEncoder().encode(windows),
      let json = String(data: data, encoding: .utf8)
    else { return }
    defaults?.set(json, forKey: blockWindowsKey)
    defaults?.synchronize()
  }

  /// The currently-active enabled window, if any.
  static func activeWindow(at date: Date = Date()) -> BlockWindow? {
    loadBlockWindows().first { $0.enabled && $0.contains(date) }
  }

  static var isFreeSessionActive: Bool {
    let end = defaults?.double(forKey: freeSessionEndKey) ?? 0
    return end > Date().timeIntervalSince1970
  }

  static var isFocusSessionActive: Bool {
    defaults?.bool(forKey: sessionActive) ?? false
  }

  static func setBlockMode(_ mode: String, windowEndLabel: String? = nil) {
    defaults?.set(mode, forKey: blockModeKey)
    if let label = windowEndLabel {
      defaults?.set(label, forKey: blockWindowEndLabelKey)
    }
    defaults?.synchronize()
  }

  // MARK: - Shield application

  static func applyStoredShield(_ store: ManagedSettingsStore) {
    guard let data = defaults?.data(forKey: selectionKey),
      let selection = try? PropertyListDecoder().decode(
        FamilyActivitySelection.self, from: data
      )
    else { return }

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

  /// Single source of truth for "should apps be shielded right now?".
  /// Priority: earned free time (shields down) > focus session > schedule window > clear.
  static func evaluateShieldState(_ store: ManagedSettingsStore) {
    if isFreeSessionActive {
      store.clearAllSettings()
      setBlockMode("none")
      return
    }
    if isFocusSessionActive {
      applyStoredShield(store)
      setBlockMode("session")
      return
    }
    if let window = activeWindow() {
      applyStoredShield(store)
      setBlockMode("schedule", windowEndLabel: window.endLabel)
      return
    }
    store.clearAllSettings()
    setBlockMode("none")
  }
}
