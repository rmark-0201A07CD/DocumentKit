//
//  UIDocumentExtensions.swift
//  DocumentKit
//
//  Created by Robbie Markwick on 8/28/15.
//  Copyright © 2015 Robbie Markwick. All rights reserved.
//

import UIKit

@objc public protocol DocumentEditor:class {
	func presentDocument(_ document:UIDocument)
}

public extension UIDocument {
	public func save(_ completionHandler:((Bool)->())? = nil){
		self.save(to: fileURL, for: .forOverwriting, completionHandler:completionHandler)
	}
	public func saveAndClose(_ completionHandler:((Bool)->())? = nil){
		save { success in self.close(completionHandler: completionHandler) }
	}

}


