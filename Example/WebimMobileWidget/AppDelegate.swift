//
//  AppDelegate.swift
//  WebimWidget
//
//  Created by kotsan777 on 12/22/2022.
//  Copyright (c) 2022 kotsan777. All rights reserved.
//

import UIKit
import WebimMobileWidget
import WebimMobileSDK
import WebimKeyboard

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        setupKeychain()
        registerNotifications(application: application)
        setupWebimKeyboard()
        let window = UIWindow(frame: UIScreen.main.bounds)
        let widget = ExternalWidgetBuilder()
            .buildDefaultWidget(
                accountName: "wmtest105",
                location: "mobile"
            )
        let navigationController = UINavigationController(rootViewController: widget)
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
    
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        WidgetAppDelegate.shared.applicationDidEnterBackground()
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let deviceToken = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        WMKeychainWrapper.standard.setString(deviceToken, forKey: WMKeychainWrapper.deviceTokenKey)
    }
    
    
    private func setupKeychain() {
        let userDefaults = UserDefaults(suiteName: "ru.webim.Webim-Widget") ?? UserDefaults.standard
        WMKeychainWrapper.standard.setAppGroupName(
            userDefaults: userDefaults,
            keychainAccessGroup: Bundle.main.infoDictionary!["keychainAppIdentifier"] as! String
        )
    }
    
    private func registerNotifications(application: UIApplication) {
        let notificationTypes: UNAuthorizationOptions = [.alert,
                                                         .badge,
                                                         .sound]
        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        UNUserNotificationCenter.current().requestAuthorization(options: notificationTypes) { (granted, error) in
            if granted {
                // application.registerUserNotificationSettings(remoteNotificationSettings)
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                    application.applicationIconBadgeNumber = 0
                }
            } else {
                print(error ?? "Error with remote notification")
            }
        }
    }
    
    private func setupWebimKeyboard() {
        WMKeyboardLogger.shared.set(availableLogLevel: .verbose)
    }
}

