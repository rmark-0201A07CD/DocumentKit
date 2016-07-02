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
	func recentWasDeleted(_ recent: RecentModelObject)
	func recentNeedsReload(_ recent: RecentModelObject)
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
	
	required init?(url: Foundation.URL) {
		self.url = url
		super.init()
		do {
			try refreshNameAndSubtitle()
			bookmarkDataNeedsSave = true
		} catch { return nil }
	}
	deinit {
		url.stopAccessingSecurityScopedResource()
	}
	
/// Properties
	private(set) var url: URL
	private(set) var displayName:String?
	private(set) var subtitle:String?
	
	private(set) var bookmarkDataNeedsSave = false
	private(set) var bookmarkData: Data?
	private var isSecurityScoped = false
	
// Initialization Support
	
	private func refreshNameAndSubtitle() throws {
		let refreshedName = try url.promisedItemResourceValues(forKeys: [URLResourceKey.localizedNameKey])
		displayName = refreshedName.localizedName
		
		subtitle = nil
		
		let fileManager = FileManager.default()
		guard let ubiquitousContainer = fileManager.urlForUbiquityContainerIdentifier(nil) else { return }
		var relationship: FileManager.URLRelationship = .other
		try fileManager.getRelationship(&relationship, ofDirectoryAt: ubiquitousContainer, toItemAt: url)
		if relationship != .contains {
			let externalContainerName = try url.promisedItemResourceValues(forKeys: [.ubiquitousItemContainerDisplayNameKey])
			subtitle = "in \(externalContainerName.ubiquitousItemContainerDisplayName!)"
		}
	}

/// NSCoding
	required init?(coder aDecoder: NSCoder) {
		do {
			displayName = aDecoder.decodeObjectOfClass(NSString.self, forKey: RecentModelObject.displayNameKey) as? String
			subtitle = aDecoder.decodeObjectOfClass(NSString.self, forKey: RecentModelObject.subtitleKey) as? String
			
			// Decode the bookmark into a URL.
			guard let bookmark = aDecoder.decodeObjectOfClass(NSData.self, forKey: RecentModelObject.bookmarkKey) else {
				throw DocumentBrowserError.bookmarkResolveFailed
			}
			bookmarkData = bookmark as Data
			
			var bookmarkDataIsStale: ObjCBool = false
			url = try (NSURL(resolvingBookmarkData: bookmark as Data, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &bookmarkDataIsStale) as URL)
			bookmarkDataNeedsSave = bookmarkDataIsStale.boolValue
			
			isSecurityScoped = url.startAccessingSecurityScopedResource()

			super.init()
			do {
				try self.refreshNameAndSubtitle()
			} catch { }
		} catch {
			url = URL(fileURLWithPath: "")
			bookmarkDataNeedsSave = false
			bookmarkData = Data()
			super.init()
			return nil
		}
	}
	
	func encodeWithCoder(_ aCoder: NSCoder) {
		do {
			aCoder.encode(displayName, forKey: RecentModelObject.displayNameKey)
			aCoder.encode(subtitle, forKey: RecentModelObject.subtitleKey)
			if bookmarkDataNeedsSave {
				bookmarkData = try url.bookmarkData(.suitableForBookmarkFile, includingResourceValuesForKeys: nil, relativeTo: nil)
				bookmarkDataNeedsSave = false
			}
			aCoder.encode(bookmarkData, forKey: RecentModelObject.bookmarkKey)
		} catch { }
	}
	
/// NSFilePresenter
	var presentedItemURL: Foundation.URL? {
		return url
	}
	var presentedItemOperationQueue: OperationQueue {
		return OperationQueue.main()
	}
	func accommodatePresentedItemDeletion(completionHandler: (NSError?) -> Void) {
		delegate?.recentWasDeleted(self)
		completionHandler(nil)
	}
	func presentedItemDidMove(to newURL: URL) {
		url = newURL
		do {
			try refreshNameAndSubtitle()
		} catch { }
		delegate?.recentNeedsReload(self)
	}
	func presentedItemDidChange() {
		delegate?.recentNeedsReload(self)
	}
	
	
/// Equality and Hashing
	override func isEqual(_ object: AnyObject?) -> Bool {
		guard let other = object as? RecentModelObject else { return false }
		return other.url == url
	}

	override var hash: Int {
		return (url as NSURL).hash
	}
}
