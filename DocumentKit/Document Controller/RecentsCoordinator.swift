//
//  RecentsCooridinator.swift
//  StudyCards +
//
//  Created by Robbie Markwick on 7/18/15.
//
//

import UIKit

/**
The delegate protocol implemented by the object that receives our results.
We pass the updated list of results as well as a set of animations.
*/
protocol RecentsManagerDelegate: class {
	func recentsManagerResultsDidChange(results: [RecentModelObject], animations: [DocumentBrowserAnimation])
}

/**
The `RecentModelObjectsManager` manages our list of recents.  It receives
notifications from the recents as a RecentModelObjectDelegate and computes
animations from the notifications which is submits to it's delegate.
*/
class RecentsCoordinator: NSObject,RecentModelObjectDelegate {
	
	private static let maxRecentModelObjectCount = 5
	private static let recentsKey = "recents"
	
	weak var delegate: RecentsManagerDelegate? {
		didSet {
			delegate?.recentsManagerResultsDidChange(recentModelObjects, animations: [.Reload])
		}
	}
 
	override init() {
		super.init()
		loadRecents()
	}
	deinit {
		for recent in recentModelObjects {
			NSFileCoordinator.removeFilePresenter(recent)
		}
	}
// Properties
	private var recentModelObjects = [RecentModelObject]()

	private let workerQueue: NSOperationQueue = {
		let coordinationQueue = NSOperationQueue()
		coordinationQueue.name = "com.markwick.documentKit.recentsQueue"
		coordinationQueue.maxConcurrentOperationCount = 1
		return coordinationQueue
	}()
	
// Saving/Loading
	
	// MARK: Recent Saving / Loading
	
	private func loadRecents() {
		workerQueue.addOperationWithBlock {
			guard let loadedRecentData = NSUserDefaults.standardUserDefaults().objectForKey(RecentsCoordinator.recentsKey) as? [NSData] else {
				return
			}
			let loadedRecents = loadedRecentData.flatMap { NSKeyedUnarchiver.unarchiveObjectWithData($0) as? RecentModelObject }
			
			for recent in self.recentModelObjects {
				NSFileCoordinator.removeFilePresenter(recent)
			}
			for recent in loadedRecents {
				recent.delegate = self
				NSFileCoordinator.addFilePresenter(recent)
			}
			self.recentModelObjects = loadedRecents
			
			if (loadedRecents.reduce(false){ $0 || $1.bookmarkDataNeedsSave }) {
				self.saveRecents()
			}
			
			NSOperationQueue.mainQueue().addOperationWithBlock {
				self.delegate?.recentsManagerResultsDidChange(self.recentModelObjects, animations: [.Reload])
			}
		}
	}
	
	private func saveRecents() {
		let recentModels = recentModelObjects.map { recentModelObject in
			return NSKeyedArchiver.archivedDataWithRootObject(recentModelObject)
		}
		NSUserDefaults.standardUserDefaults().setObject(recentModels, forKey: RecentsCoordinator.recentsKey)
		
		do {
			try saveHomeScreenShortcuts()
		}catch { return }

	}
	
	private func saveHomeScreenShortcuts() throws {
		let plistData = try loadDocumentKitPlistData()
		guard let shouldShowShortcuts = plistData["Quick Action Recents"] as? Bool else { throw DocumentBrowserError.InfoPlistKeysMissing }
		guard shouldShowShortcuts else { return }
		
		UIApplication.sharedApplication().shortcutItems = recentModelObjects.map {
			UIApplicationShortcutItem(type: "Open", localizedTitle: $0.displayName ?? "", localizedSubtitle: $0.subtitle, icon: nil, userInfo: ["URL":$0.URL])
		}

	}
	
/// Recents Managemtent
	private func removeRecentModelObject(recent: RecentModelObject) {
		NSFileCoordinator.removeFilePresenter(recent)
		guard let index = recentModelObjects.indexOf(recent) else { return }
		recentModelObjects.removeAtIndex(index)
	}
	private func trimRecents(inout animations:[DocumentBrowserAnimation]){
		while recentModelObjects.count > RecentsCoordinator.maxRecentModelObjectCount {
			removeRecentModelObject(self.recentModelObjects.last!)
			animations += [.Delete(index: self.recentModelObjects.count - 1)]
		}
	}
	func addURLToRecents(URL: NSURL) {
		workerQueue.addOperationWithBlock {
			guard let recent = RecentModelObject(URL: URL) else { return }
			var animations = [DocumentBrowserAnimation]()
			
			if let index = (self.recentModelObjects.map { $0.URL.path ?? "" }).indexOf(recent.URL.path ?? "/.") {
				self.recentModelObjects.removeAtIndex(index)
				if index != 0 {
					animations += [.Move(fromIndex: index, toIndex: 0)]
				}
			} else {
				recent.delegate = self
				NSFileCoordinator.addFilePresenter(recent)
				animations += [.Add(index: 0)]
			}
			self.recentModelObjects.insert(recent, atIndex: 0)
			
			self.trimRecents(&animations)
			
			NSOperationQueue.mainQueue().addOperationWithBlock {
				self.delegate?.recentsManagerResultsDidChange(self.recentModelObjects, animations: animations)
			}
			
			self.saveRecents()
		}
	}
	
///Recent Model Object Delegate
	func recentWasDeleted(recent: RecentModelObject) {
		workerQueue.addOperationWithBlock {
			guard let index = self.recentModelObjects.indexOf(recent) else { return }
			self.removeRecentModelObject(recent)
			NSOperationQueue.mainQueue().addOperationWithBlock {
				let animations = [DocumentBrowserAnimation.Delete(index: index)]
				self.delegate?.recentsManagerResultsDidChange(self.recentModelObjects, animations: animations)
			}
			self.saveRecents()
		}
	}
	func recentNeedsReload(recent: RecentModelObject) {
		self.workerQueue.addOperationWithBlock {
			guard let index = self.recentModelObjects.indexOf(recent) else { return }
			NSOperationQueue.mainQueue().addOperationWithBlock {
				let animations = [DocumentBrowserAnimation.Update(index: index)]
				self.delegate?.recentsManagerResultsDidChange(self.recentModelObjects, animations: animations)
			}
		}
	}
}
