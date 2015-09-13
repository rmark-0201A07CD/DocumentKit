//
//  DocumentAppDelegate.swift
//  StudyCards +
//
//  Created by Robbie Markwick on 7/22/15.
//
//

import UIKit

func loadDocumentKitPlistData() throws ->[String:AnyObject]{
	guard let pListURL = NSBundle.mainBundle().URLForResource("Info", withExtension: "plist") else { throw DocumentBrowserError.InfoPlistLoadFailed }
	guard let pListData = NSData(contentsOfURL: pListURL) else { throw DocumentBrowserError.InfoPlistLoadFailed }
	guard let pListDictionary = try NSPropertyListSerialization.propertyListWithData(pListData, options: .Immutable, format: nil) as? [String:AnyObject] else { throw DocumentBrowserError.InfoPlistLoadFailed }
	guard let documentKitDictionary = pListDictionary["DocumentKit"] as? [String:AnyObject] else { throw DocumentBrowserError.InfoPlistKeysMissing }
	return documentKitDictionary
}


public class DocumentAppDelegate: UIResponder, UIApplicationDelegate {
	
	/// OVERRIDE
	public var documentSubclass:UIDocument.Type { return UIDocument.self }
	public var browserTintColor:UIColor { return UIColor.blueColor() }
	
	/// App Delegate
	public var window: UIWindow?

	
	public func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
		setUpDocumentKit()
		loadInitialViewController()
		
		return true
	}
	
	private func setUpDocumentKit() {
		do{
			let plistData = try loadDocumentKitPlistData()
			guard let fileExtension = plistData["File Extension"] as? String else { throw DocumentBrowserError.InfoPlistKeysMissing }
			DocumentController.sharedDocumentController.fileExtension  = fileExtension
			DocumentController.sharedDocumentController.UIDocumentSubclass = documentSubclass
		}catch{
			fatalError("DocumentKit Info.plist keys unavailable")
		}
	}
	private func loadInitialViewController(){
		window = UIWindow(frame: UIScreen.mainScreen().bounds)
		let storyBoard = UIStoryboard(name: "DocumentBrowser", bundle: NSBundle(identifier: "com.markwick.DocumentKit"))
		window?.rootViewController = storyBoard.instantiateInitialViewController()
		defer { window?.makeKeyAndVisible() }
		guard let browser = (window?.rootViewController as? UINavigationController)?.viewControllers[0] as? DocumentBrowserViewController else { return }
		
		window?.tintColor = browserTintColor
		do {
			let plistData = try loadDocumentKitPlistData()
			guard let title = plistData["Document Browser Title"] as? String else { return }
			browser.browserTitle = title
		} catch {}
		
	}
	
	
	private func popToMasterViewController()->DocumentBrowserViewController? {
		let navController = window?.rootViewController as? UINavigationController
		guard navController?.viewControllers[0] is DocumentBrowserViewController else { return nil }
		navController?.popToRootViewControllerAnimated(true)
		return navController?.viewControllers[0] as? DocumentBrowserViewController
	}
	
	public func application(application: UIApplication, performActionForShortcutItem shortcutItem: UIApplicationShortcutItem, completionHandler: (Bool) -> Void) {
		guard let documentBrowser = popToMasterViewController() else { return }
		guard let URL = shortcutItem.userInfo?["URL"] as? NSURL else {return }
		documentBrowser.openDocumentAtURL(URL)
		completionHandler(true)
	}
	
	public func application(application: UIApplication, openURL url: NSURL, options: [String: AnyObject]) -> Bool {
		guard let documentBrowser = popToMasterViewController() else { return false }
		
		let openDocument:(NSURL)->() = { documentBrowser.openDocumentAtURL($0) }
		
		
		if let openInPlace = options[UIApplicationOpenURLOptionsOpenInPlaceKey] as? Bool where openInPlace{
			openDocument(url)
		} else {
			DocumentController.sharedDocumentController.importDocument(url, completion: openDocument)
		}
		return true
	}
	
	//Handoff
	public func application(application: UIApplication, continueUserActivity userActivity: NSUserActivity, restorationHandler: ([AnyObject]?) -> Void) -> Bool {
		popToMasterViewController()?.restoreUserActivityState(userActivity)
		return true
	}
}
