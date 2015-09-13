//
//  UIDocumentExtensions.swift
//  DocumentKit
//
//  Created by Robbie Markwick on 8/28/15.
//  Copyright © 2015 Robbie Markwick. All rights reserved.
//

import UIKit

@objc public protocol DocumentEditor:class {
	func presentDocument(document:UIDocument)
}

public extension UIDocument {
	public func save(completionHandler:((Bool)->())? = nil){
		saveToURL(fileURL, forSaveOperation: .ForOverwriting, completionHandler:completionHandler)
	}
	public func saveAndClose(completionHandler:((Bool)->())? = nil){
		save { success in self.closeWithCompletionHandler(completionHandler) }
	}

}


