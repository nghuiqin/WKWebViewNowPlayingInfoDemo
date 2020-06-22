//
//  AppDelegate.swift
//  MacPlayer
//
//  Created by Hui Qin Ng on 2019/9/2.
//  Copyright © 2019 Hui Qin Ng. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

	@IBOutlet weak var window: NSWindow!


	func applicationDidFinishLaunching(_ aNotification: Notification) {
		window.contentViewController = HomeViewController()
		window.makeKey()
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}


}

