//
//  DocumentKitDataTypes.swift
//  StudyCards +
//
//  Created by Robbie Markwick on 7/18/15.
//
//

import Foundation



/// The base protocol for all collection view objects to display in our UI.
protocol ModelObject: class {
	var displayName: String? { get }
	var subtitle: String? { get }
	var URL: NSURL { get }
}

/// These represent the possible errors thrown in our project.
enum DocumentBrowserError: ErrorType {
	case BookmarkResolveFailed
	case SignedOutOfiCloud
	case InfoPlistLoadFailed
	case InfoPlistKeysMissing
	case HelpFileMissing
}

enum DocumentBrowserAnimation {
	case Reload
	case Delete(index: Int)
	case Add(index: Int)
	case Update(index: Int)
	case Move(fromIndex: Int, toIndex: Int)
}


extension DocumentBrowserAnimation: Equatable { }
func ==(lhs: DocumentBrowserAnimation, rhs: DocumentBrowserAnimation) -> Bool {
	switch (lhs, rhs) {
	case (.Reload, .Reload): return true
	case let (.Delete(left), .Delete(right)) where left == right: return true
	case let (.Add(left), .Add(right)) where left == right: return true
	case let (.Update(left), .Update(right)) where left == right: return true
	case let (.Move(leftFrom, leftTo), .Move(rightFrom, rightTo)) where leftFrom == rightFrom && leftTo == rightTo: return true
	default:
		return false
	}
}


/// Convenience function
func dispatch_main(block:dispatch_block_t){
	dispatch_async(dispatch_get_main_queue(), block)
}