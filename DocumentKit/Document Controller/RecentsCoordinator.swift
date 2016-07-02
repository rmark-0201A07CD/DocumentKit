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
	func recentsManagerResultsDidChange(_ results: [RecentModelObject], animations: [DocumentBrowserAnimation])
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
			delegate?.recentsManagerResultsDidChange(recentModelObjects, animations: [.reload])
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

	private let workerQueue: OperationQueue = {
		let coordinationQueue = OperationQueue()
		coordinationQueue.name = "com.markwick.documentKit.recentsQueue"
		coordinationQueue.maxConcurrentOperationCount = 1
		return coordinationQueue
	}()
	
// Saving/Loading
	
	// MARK: Recent Saving / Loading
	
	private func loadRecents() {
		workerQueue.addOperation {
			guard let loadedRecentData = UserDefaults.standard().object(forKey: RecentsCoordinator.recentsKey) as? [Data] else {
				return
			}
			let loadedRecents = loadedRecentData.flatMap { NSKeyedUnarchiver.unarchiveObject(with: $0) as? RecentModelObject }
			
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
			
			OperationQueue.main().addOperation {
				self.delegate?.recentsManagerResultsDidChange(self.recentModelObjects, animations: [.reload])
			}
		}
	}
	
	private func saveRecents() {
		let recentModels = recentModelObjects.map { recentModelObject in
			return NSKeyedArchiver.archivedData(withRootObject: recentModelObject)
		}
		UserDefaults.standard().set(recentModels, forKey: RecentsCoordinator.recentsKey)
		
		do {
			try saveHomeScreenShortcuts()
		}catch { return }

	}
	
	private func saveHomeScreenShortcuts() throws {
		let plistData = try loadDocumentKitPlistData()
		guard let shouldShowShortcuts = plistData["Quick Action Recents"] as? Bool else { throw DocumentBrowserError.infoPlistKeysMissing }
		guard shouldShowShortcuts else { return }
	/*
		UIApplication.sharedApplication().shortcutItems = recentModelObjects.map {
			UIApplicationShortcutItem(type: "Open", localizedTitle: $0.displayName ?? "", localizedSubtitle: $0.subtitle, icon: nil, userInfo: ["BOOKMARK":$0.bookmarkData])
		}
*/

	}
	
/// Recents Managemtent
	private func removeRecentModelObject(_ recent: RecentModelObject) {
		NSFileCoordinator.removeFilePresenter(recent)
		guard let index = recentModelObjects.index(of: recent) else { return }
		recentModelObjects.remove(at: index)
	}
	private func trimRecents(_ animations:inout [DocumentBrowserAnimation]){
		while recentModelObjects.count > RecentsCoordinator.maxRecentModelObjectCount {
			removeRecentModelObject(self.recentModelObjects.last!)
			animations += [.delete(index: self.recentModelObjects.count - 1)]
		}
	}
	func addURLToRecents(_ url: URL) {
		workerQueue.addOperation {
			guard let recent = RecentModelObject(url: url) else { return }
			var animations = [DocumentBrowserAnimation]()
			
			if let index = (self.recentModelObjects.map { $0.url.path ?? "" }).index(of: recent.url.path ?? "/.") {
				self.recentModelObjects.remove(at: index)
				if index != 0 {
					animations += [.move(fromIndex: index, toIndex: 0)]
				}
			} else {
				recent.delegate = self
				NSFileCoordinator.addFilePresenter(recent)
				animations += [.add(index: 0)]
			}
			self.recentModelObjects.insert(recent, at: 0)
			
			self.trimRecents(&animations)
			
			OperationQueue.main().addOperation {
				self.delegate?.recentsManagerResultsDidChange(self.recentModelObjects, animations: animations)
			}
			
			self.saveRecents()
		}
	}
	
///Recent Model Object Delegate
	func recentWasDeleted(_ recent: RecentModelObject) {
		workerQueue.addOperation {
			guard let index = self.recentModelObjects.index(of: recent) else { return }
			self.removeRecentModelObject(recent)
			OperationQueue.main().addOperation {
				let animations = [DocumentBrowserAnimation.delete(index: index)]
				self.delegate?.recentsManagerResultsDidChange(self.recentModelObjects, animations: animations)
			}
			self.saveRecents()
		}
	}
	func recentNeedsReload(_ recent: RecentModelObject) {
		self.workerQueue.addOperation {
			guard let index = self.recentModelObjects.index(of: recent) else { return }
			OperationQueue.main().addOperation {
				let animations = [DocumentBrowserAnimation.update(index: index)]
				self.delegate?.recentsManagerResultsDidChange(self.recentModelObjects, animations: animations)
			}
		}
	}
}
