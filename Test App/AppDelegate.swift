//
//  AppDelegate.swift
//  iOSTestApp
//
//  Created by Nolan Waite on 2018-05-13.
//  Copyright © 2018 Nolan Waite. All rights reserved.
//

import ImgurUploader
import UIKit

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        ImgurUploader.logger = { level, message in
            print("\(level): \(message())")
        }

        return true
    }
}
