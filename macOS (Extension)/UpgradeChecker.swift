//
//  UpgradeChecker.swift
//  Kagi Search Extension macOS
//
//  Created by Nano Anderson on 11/29/23.
//

import Foundation

class UpgradeChecker {
    
    static let shared = UpgradeChecker()
    
    static let RequestNotificationName = "com.kagimacOS.Kagi-Search.Extension.UpgradeCheckRequestNotification" as CFString
    static let ResponseNotificationName = "com.kagimacOS.Kagi-Search.Extension.UpgradeCheckResponseNotification" as CFString
    
    /// Should only ever be called from the Extension target, not the App target
    func startObservers() {
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque()), { _, _, _, object, _ in
            guard Preferences.shared.checkedIfUpgradedFromLegacyExtension == false else {
                return
            }
            let previousVersionExisted = UserDefaults.standard.object(forKey: "enableKagiSearch") != nil
            Preferences.shared.checkedIfUpgradedFromLegacyExtension = true
            Preferences.shared.didUpgradeFromLegacyExtension = previousVersionExisted
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(UpgradeChecker.ResponseNotificationName), nil, nil, true)
        }, Self.RequestNotificationName as CFString, nil, .hold)
    }
    
    deinit {
        CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(), UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque()))
    }
}
