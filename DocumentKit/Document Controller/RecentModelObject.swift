/*
Copyright (C) 2015 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
This is the RecentsModelObject which listens for notifications about a single recent object. It then forwards the notifications on to the delegate.
*/

import Foundation

/**
The delegate protocol implemented by the object that wants to be notified
about changes to this recent.
*/
protocol RecentModelObjectDelegate: class {
	func recentWasDeleted(recent: RecentModelObject)
	func recentNeedsReload(recent: RecentModelObject)
}

/**
The `RecentModelObject` manages a single recent on disk.  It is registered
as a file presenter and as such is notified when the recent changes on
disk.  It forwards these notifications on to its delegate.
*/
class RecentModelObject: NSObject, NSFilePresenter, ModelObject {
	private static let displayNameKey = "displayName"
	private static let subtitleKey = "subtitle"
	private static let bookmarkKey = "bookmark"
	
	weak var delegate: RecentModelObjectDelegate?
	
	required init?(URL: NSURL) {
		self.URL = URL
		super.init()
		do {
			try refreshNameAndSubtitle()
			bookmarkDataNeedsSave = true
		} catch { return nil }
	}
	deinit {
		URL.stopAccessingSecurityScopedResource()
	}
	
/// Properties
	private(set) var URL: NSURL
	private(set) var displayName:String?
	private(set) var subtitle:String?
	
	private(set) var bookmarkDataNeedsSave = false
	private var bookmarkData: NSData?
	private var isSecurityScoped = false
	
// Initialization Support
	
	private func refreshNameAndSubtitle() throws {
		var refreshedName: AnyObject?
		try URL.getPromisedItemResourceValue(&refreshedName, forKey: NSURLLocalizedNameKey)
		displayName = refreshedName as? String
		
		subtitle = nil
		
		let fileManager = NSFileManager.defaultManager()
		guard let ubiquitousContainer = fileManager.URLForUbiquityContainerIdentifier(nil) else { return }
		var relationship: NSURLRelationship = .Other
		try fileManager.getRelationship(&relationship, ofDirectoryAtURL: ubiquitousContainer, toItemAtURL: URL)
		if relationship != .Contains {
			var externalContainerName: AnyObject?
			try URL.getPromisedItemResourceValue(&externalContainerName, forKey: NSURLUbiquitousItemContainerDisplayNameKey)
			subtitle = "in \(externalContainerName as! String)"
		}
	}

/// NSCoding
	required init?(coder aDecoder: NSCoder) {
		do {
			displayName = aDecoder.decodeObjectOfClass(NSString.self, forKey: RecentModelObject.displayNameKey) as? String
			subtitle = aDecoder.decodeObjectOfClass(NSString.self, forKey: RecentModelObject.subtitleKey) as? String
			
			// Decode the bookmark into a URL.
			guard let bookmark = aDecoder.decodeObjectOfClass(NSData.self, forKey: RecentModelObject.bookmarkKey) as? NSData else {
				throw DocumentBrowserError.BookmarkResolveFailed
			}
			bookmarkData = bookmark
			
			var bookmarkDataIsStale: ObjCBool = false
			URL = try NSURL(byResolvingBookmarkData: bookmark, options: .WithoutUI, relativeToURL: nil, bookmarkDataIsStale: &bookmarkDataIsStale)
			bookmarkDataNeedsSave = bookmarkDataIsStale.boolValue
			
			isSecurityScoped = URL.startAccessingSecurityScopedResource()

			super.init()
			do {
				try self.refreshNameAndSubtitle()
			} catch { }
		} catch {
			URL = NSURL()
			bookmarkDataNeedsSave = false
			bookmarkData = NSData()
			super.init()
			return nil
		}
	}
	
	func encodeWithCoder(aCoder: NSCoder) {
		do {
			aCoder.encodeObject(displayName, forKey: RecentModelObject.displayNameKey)
			aCoder.encodeObject(subtitle, forKey: RecentModelObject.subtitleKey)
			if bookmarkDataNeedsSave {
				bookmarkData = try URL.bookmarkDataWithOptions(.SuitableForBookmarkFile, includingResourceValuesForKeys: nil, relativeToURL: nil)
				bookmarkDataNeedsSave = false
			}
			aCoder.encodeObject(bookmarkData, forKey: RecentModelObject.bookmarkKey)
		} catch { }
	}
	
/// NSFilePresenter
	var presentedItemURL: NSURL? {
		return URL
	}
	var presentedItemOperationQueue: NSOperationQueue {
		return NSOperationQueue.mainQueue()
	}
	func accommodatePresentedItemDeletionWithCompletionHandler(completionHandler: NSError? -> Void) {
		delegate?.recentWasDeleted(self)
		completionHandler(nil)
	}
	func presentedItemDidMoveToURL(newURL: NSURL) {
		URL = newURL
		do {
			try refreshNameAndSubtitle()
		} catch { }
		delegate?.recentNeedsReload(self)
	}
	func presentedItemDidChange() {
		delegate?.recentNeedsReload(self)
	}
	
	
/// Equality and Hashing
	override func isEqual(object: AnyObject?) -> Bool {
		guard let other = object as? RecentModelObject else { return false }
		return other.URL.isEqual(URL)
	}

	override var hash: Int {
		return URL.hash
	}
}
