//
//  DocumentBrowserModelObject.swift
//  StudyCards +
//
//  Created by Robbie Markwick on 7/18/15.
//
//

import Foundation

/**
This class is used as an immutable value object to represent an item in our
document browser. Note the custom implementation of `hash` and `isEqual(_:)`,
which are required so we can later look up instances in our results set.
*/

class DocumentBrowserModelObject: NSObject, ModelObject {

	required init(item: NSMetadataItem) {
		
		displayName = item.valueForAttribute(NSMetadataItemDisplayNameKey) as? String
		
		if let isExternal = item.valueForAttribute(NSMetadataUbiquitousItemIsExternalDocumentKey) as? Bool,
			containerName = item.valueForAttribute(NSMetadataUbiquitousItemContainerDisplayNameKey) as? String
			where isExternal {
				subtitle = "in \(containerName)"
		}

		URL = item.valueForAttribute(NSMetadataItemURLKey) as! NSURL
		
		metadataItem = item
	}
	init(URL:NSURL) {
		displayName = URL.URLByDeletingPathExtension?.lastPathComponent
		self.URL = URL
	}
/// Properties
	private(set) var displayName: String?
	private(set) var subtitle: String?
	private(set) var URL: NSURL
	private(set) var metadataItem: NSMetadataItem?
	
/// Hashing and Equality
	override func isEqual(object: AnyObject?) -> Bool {
		guard let other = object as? DocumentBrowserModelObject else { return false }
		return other.metadataItem?.isEqual(metadataItem) ?? false
	}
	
	override var hash: Int {
		return (metadataItem ?? URL).hash
	}

}