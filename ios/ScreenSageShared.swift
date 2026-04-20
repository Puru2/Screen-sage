//
//  ScreenSageShared.swift
//  Runner
//
//  Created by Puru on 24/02/26.
//

import Foundation

enum ScreenSageShared {

  static let appGroupID = "group.com.pratham.screensage.data"

  static let selectionKey = "ScreenSageSelection"
  static let overrideKey = "ScreenSageOverrideCount"
  static let sessionActive = "ScreenSageSessionActive"
  static let sessionEndTime = "ScreenSageSessionEnd"

  static let activityName = "screensage.focus.session"
  static let eventName = "screensage.focus.event"

  static var defaults: UserDefaults? {
    UserDefaults(suiteName: appGroupID)
  }
}
