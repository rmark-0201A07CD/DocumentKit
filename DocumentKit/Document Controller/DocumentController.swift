//
//  Document_Controller.swift
//  StudyCards +
//
//  Created by Robbie Markwick on 7/18/15.
//
//

import UIKit

protocol DocumentControllerDelegate: class {
	func reloadData()
	func processAnimations(animations:[DocumentBrowserAnimation])
	func processRecentsAnimations(animations:[DocumentBrowserAnimation])
}

class DocumentController: NSObject, DocumentCoordinatorDelegate,RecentsManagerDelegate {
	
	class var sharedDocumentController: DocumentController {
		struct Static { static let instance = DocumentController() }
		return Static.instance
	}
	
	weak var delegate:DocumentControllerDelegate? {
		didSet {
			delegate?.reloadData()
		}
	}
	override init(){
		super.init()
		coordinator.delegate = self
		recentsCoordinator.delegate = self
	}

/// Properities
	var fileExtension = "" {
		didSet { coordinator.loadLocalDocuments() }
	}
	var UIDocumentSubclass: UIDocument.Type = UIDocument.self

///Recents Coordinator
	var recents = [RecentModelObject]()
	private var recentsCoordinator = RecentsCoordinator()
	var numberOfRecents:Int {
		return recents.count
	}
	func recentsManagerResultsDidChange(results: [RecentModelObject], animations: [DocumentBrowserAnimation]) {
		self.recents = results
		if animations == [.Reload] {
			delegate?.reloadData()
		} else {
			delegate?.processRecentsAnimations(animations)
		}
	}
	
///Document Coordinator
	var documents = [DocumentBrowserModelObject]()
	private var coordinator = DocumentCoordinator()
	var numberOfDocuments:Int {
		return documents.count
	}
	func documentQueryResultsDidChangeWithResults(results: [DocumentBrowserModelObject], animations: [DocumentBrowserAnimation]) {
		documents = results
		if animations == [.Reload] {
			delegate?.reloadData()
		} else {
			delegate?.processAnimations(animations)
		}
	}

	
///Document Operations

	private let workerQueue: NSOperationQueue = {
		let workerQueue = NSOperationQueue()
		workerQueue.name = "com.markwick.documentbrowser.coordinationQueue"
		return workerQueue
	}()
	
	func openDocumentAtURL(url:NSURL, handoffState:[NSObject:AnyObject]? = nil)->UIDocument {
		let document = UIDocumentSubclass.init(fileURL:url)
		document.openWithCompletionHandler {
			guard $0 else { return }
			if let handoff = handoffState {
				let userActivity = NSUserActivity()
				userActivity.userInfo = handoff
				document.restoreUserActivityState(userActivity)
			}
			self.recentsCoordinator.addURLToRecents(url)
		}
		return document
	}
	
	func createNewDocument(completion:((NSURL)->())?=nil) {
		workerQueue.addOperationWithBlock {
			let newDocURL = self.coordinator.urlForNewDocument()
			let writeIntent = NSFileAccessIntent.writingIntentWithURL(newDocURL, options: .ForReplacing)
			NSFileCoordinator().coordinateAccessWithIntents([writeIntent], queue: self.workerQueue) {
				guard $0 == nil else { return }
				do {
					try self.coordinator.addDocumentAtURL(writeIntent.URL)
					NSOperationQueue.mainQueue().addOperationWithBlock {
						completion?(writeIntent.URL)
					}
				}catch {}
			}
		}
	}
	func importDocument(url:NSURL,completion:((NSURL)->())?){
		guard url.pathExtension == fileExtension else { return }
		guard let fileName = url.lastPathComponent else { return }
		workerQueue.addOperationWithBlock {
			let fromURL = url, toURL = self.coordinator.urlForNewDocument(fileName)
			self.moveFile(fromURL: fromURL, toURL: toURL, completion:completion)
		}
		
	}
	
	func moveFile(fromURL fromURL:NSURL,toURL:NSURL, completion:((NSURL)->())?=nil){
		guard fromURL != toURL else { return }
		workerQueue.addOperationWithBlock {
			guard let path = toURL.path where !NSFileManager.defaultManager().fileExistsAtPath(path) else {return}
			
			let successfulSecurityScopedResourceAccess = fromURL.startAccessingSecurityScopedResource()

			let movingIntent = NSFileAccessIntent.writingIntentWithURL(fromURL, options: .ForDeleting)
			let replacingIntent = NSFileAccessIntent.writingIntentWithURL(toURL, options: .ForReplacing)
			NSFileCoordinator().coordinateAccessWithIntents([movingIntent,replacingIntent], queue: self.workerQueue) {
				if successfulSecurityScopedResourceAccess {
					defer { fromURL.stopAccessingSecurityScopedResource() }
				}
				guard $0 == nil else { return }
				do {
					try self.coordinator.moveFile(fromURL: movingIntent.URL, toURL: replacingIntent.URL)
					completion?(toURL)
				}catch{}
			}
		}
	}
	func deleteFileAtIndex(index:Int){
		let url = self.documents[index].URL
		workerQueue.addOperationWithBlock {
			let successfulSecurityScopedResourceAccess = url.startAccessingSecurityScopedResource()

			let writingIntent = NSFileAccessIntent.writingIntentWithURL(url, options: .ForDeleting)
			NSFileCoordinator().coordinateAccessWithIntents([writingIntent], queue: self.workerQueue) {
				if successfulSecurityScopedResourceAccess {
					defer { url.stopAccessingSecurityScopedResource() }
				}
				guard $0 == nil else { return }
				do {
					try self.coordinator.deleteFileAtURL(writingIntent.URL)
				} catch {}
			}
		}
	}
}









