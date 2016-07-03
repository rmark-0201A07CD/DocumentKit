//
//  DocumentAppDelegate.swift
//  StudyCards +
//
//  Created by Robbie Markwick on 7/22/15.
//
//

import UIKit
import Foundation

public class DocumentAppDelegate: UIResponder, UIApplicationDelegate {
	
	/// OVERRIDE
	public var documentSubclass:UIDocument.Type { return UIDocument.self }
	public var browserTintColor:UIColor { return UIColor.blue() }
	
	/// App Delegate
	public var window: UIWindow?
	
	
	class var plistData: [String:AnyObject] {
		struct Static {
			static let instance = { ()->[String:AnyObject] in
				do{
					guard let pListURL = Bundle.main().urlForResource("Info", withExtension: "plist") else { throw DocumentBrowserError.infoPlistLoadFailed }
					guard let pListData = try? Data(contentsOf: pListURL) else { throw DocumentBrowserError.infoPlistLoadFailed }
					guard let pListDictionary = try PropertyListSerialization.propertyList(from: pListData, options: PropertyListSerialization.MutabilityOptions(), format: nil) as? [String:AnyObject] else { throw DocumentBrowserError.infoPlistLoadFailed }
					guard let documentKitDictionary = pListDictionary["DocumentKit"] as? [String:AnyObject] else { throw DocumentBrowserError.infoPlistKeysMissing }
					return documentKitDictionary
				} catch {
					print("DocumentKit Info.plist keys Not Found. Exiting...")
					exit(-1)
				}
			}()
		}
		return Static.instance
	}

	
	public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
		setupDocumentKit()
		loadInitialViewController()
		
		return true
	}
	
	private func setupDocumentKit() {
		do{
			guard let fileExtension = DocumentAppDelegate.plistData["File Extension"] as? String else { throw DocumentBrowserError.infoPlistKeysMissing }
			DocumentController.sharedDocumentController.fileExtension  = fileExtension
			DocumentController.sharedDocumentController.UIDocumentSubclass = documentSubclass
		}catch{
			fatalError("DocumentKit Info.plist keys unavailable")
		}
	}
	private func loadInitialViewController(){
		window = UIWindow(frame: UIScreen.main().bounds)
		let storyBoard = UIStoryboard(name: "DocumentBrowser", bundle: Bundle(identifier: "com.markwick.DocumentKit"))
		window?.rootViewController = storyBoard.instantiateInitialViewController()
		defer { window?.makeKeyAndVisible() }
		guard let browser = (window?.rootViewController as? UINavigationController)?.viewControllers[0] as? DocumentBrowserViewController else { return }
		
		window?.tintColor = browserTintColor
		
		guard let title = DocumentAppDelegate.plistData["Document Browser Title"] as? String else { return }
		browser.browserTitle = title
		
	}
	
	
	private func popToMasterViewController()->DocumentBrowserViewController? {
		let navController = window?.rootViewController as? UINavigationController
		guard navController?.viewControllers[0] is DocumentBrowserViewController else { return nil }
		_ = navController?.popToRootViewController(animated: true)
		return navController?.viewControllers[0] as? DocumentBrowserViewController
	}
	/*
	public func application(application: UIApplication, performActionForShortcutItem shortcutItem: UIApplicationShortcutItem, completionHandler: (Bool) -> Void) {
		guard let documentBrowser = popToMasterViewController() else { return }
		guard let bookmark = shortcutItem.userInfo?["BOOKMARK"] as? NSURL else {return }
		var bookmarkDataIsStale: ObjCBool = false
		do {
			let URL = try NSURL(byResolvingBookmarkData: bookmark, options: NSURLBookmarkResolutionOptions.WithoutUI, relativeToURL: nil, bookmarkDataIsStale: &bookmarkDataIsStale)
		
		
			documentBrowser.openDocumentAtURL(URL)
			completionHandler(true)
		} catch {
			completionHandler(false)
		}
	}*/
	
	public func application(_ application: UIApplication, open url: URL, options: [String: AnyObject]) -> Bool {
		guard let documentBrowser = popToMasterViewController() else { return false }
		
		let openDocument:(URL)->() = { documentBrowser.openDocument(at:$0) }
		
		
		if let openInPlace = options[UIApplicationOpenURLOptionsOpenInPlaceKey] as? Bool where openInPlace{
			openDocument(url)
		} else {
			DocumentController.sharedDocumentController.importDocument(at: url, completion: openDocument)
		}
		return true
	}
	
	//Handoff
	public func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: ([AnyObject]?) -> Void) -> Bool {
		popToMasterViewController()?.restoreUserActivityState(userActivity)
		return true
	}
}
