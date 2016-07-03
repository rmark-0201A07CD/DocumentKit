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
		
		displayName = item.value(forAttribute: NSMetadataItemDisplayNameKey) as? String
		
		if let isExternal = item.value(forAttribute: NSMetadataUbiquitousItemIsExternalDocumentKey) as? Bool,
			containerName = item.value(forAttribute: NSMetadataUbiquitousItemContainerDisplayNameKey) as? String
			where isExternal {
				subtitle = "in \(containerName)"
		}

		url = item.value(forAttribute: NSMetadataItemURLKey) as! Foundation.URL
		
		metadataItem = item
	}
	init(url:URL) {
		displayName = try! url.deletingPathExtension().lastPathComponent
		self.url = url
	}
/// Properties
	private(set) var displayName: String?
	private(set) var subtitle: String?
	private(set) var url: URL
	private(set) var metadataItem: NSMetadataItem?
	
/// Hashing and Equality
	override func isEqual(_ object: AnyObject?) -> Bool {
		guard let other = object as? DocumentBrowserModelObject else { return false }
		return other.metadataItem?.isEqual(metadataItem) ?? false
	}
	
	override var hash: Int {
		return (metadataItem?.hash ?? (url as NSURL).hash)
	}

}
