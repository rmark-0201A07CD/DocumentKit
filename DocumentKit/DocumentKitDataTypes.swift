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
	var url: URL { get }
}

/// These represent the possible errors thrown in our project.
enum DocumentBrowserError: ErrorProtocol {
	case bookmarkResolveFailed
	case signedOutOfiCloud
	case infoPlistLoadFailed
	case infoPlistKeysMissing
	case helpFileMissing
}

enum DocumentBrowserAnimation {
	case reload
	case delete(index: Int)
	case add(index: Int)
	case update(index: Int)
	case move(fromIndex: Int, toIndex: Int)
}


extension DocumentBrowserAnimation: Equatable { }
func ==(lhs: DocumentBrowserAnimation, rhs: DocumentBrowserAnimation) -> Bool {
	switch (lhs, rhs) {
	case (.reload, .reload): return true
	case let (.delete(left), .delete(right)) where left == right: return true
	case let (.add(left), .add(right)) where left == right: return true
	case let (.update(left), .update(right)) where left == right: return true
	case let (.move(leftFrom, leftTo), .move(rightFrom, rightTo)) where leftFrom == rightFrom && leftTo == rightTo: return true
	default:
		return false
	}
}

