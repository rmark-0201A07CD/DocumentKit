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
	func processAnimations(_ animations:[DocumentBrowserAnimation])
	func processRecentsAnimations(_ animations:[DocumentBrowserAnimation])
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
	func recentsManagerResultsDidChange(_ results: [RecentModelObject], animations: [DocumentBrowserAnimation]) {
		self.recents = results
		if animations == [.reload] {
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
	func documentQueryResultsDidChangeWithResults(_ results: [DocumentBrowserModelObject], animations: [DocumentBrowserAnimation]) {
		documents = results
		if animations == [.reload] {
			delegate?.reloadData()
		} else {
			delegate?.processAnimations(animations)
		}
	}

	
///Document Operations

	private let workerQueue: OperationQueue = {
		let workerQueue = OperationQueue()
		workerQueue.name = "com.markwick.documentbrowser.coordinationQueue"
		return workerQueue
	}()
	
	func openDocumentAtURL(_ url:URL, handoffState:[NSObject:AnyObject]? = nil)->UIDocument {
		let document = UIDocumentSubclass.init(fileURL:url)
		document.open {
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
	
	func createNewDocument(_ completion:((URL)->())?=nil) {
		workerQueue.addOperation {
			let newDocURL = self.coordinator.urlForNewDocument()
			let writeIntent = NSFileAccessIntent.writingIntent(with: newDocURL as URL, options: .forReplacing)
			NSFileCoordinator().coordinate(with: [writeIntent], queue: self.workerQueue) {
				guard $0 == nil else { return }
				do {
					try self.coordinator.addDocumentAtURL(writeIntent.url)
					OperationQueue.main().addOperation {
						completion?(writeIntent.url)
					}
				}catch {}
			}
		}
	}
	func importDocument(_ url:URL,completion:((URL)->())?){
		guard url.pathExtension == fileExtension else { return }
		guard let fileName = url.lastPathComponent else { return }
		workerQueue.addOperation {
			let fromURL = url, toURL = self.coordinator.urlForNewDocument(fileName)
			self.moveFile(fromURL: fromURL, toURL: toURL, completion:completion)
		}
		
	}
	
	func moveFile(fromURL:URL,toURL:URL, completion:((URL)->())?=nil){
		guard fromURL != toURL else { return }
		workerQueue.addOperation {
			guard let path = toURL.path where !FileManager.default().fileExists(atPath: path) else {return}
			
			let successfulSecurityScopedResourceAccess = fromURL.startAccessingSecurityScopedResource()

			let movingIntent = NSFileAccessIntent.writingIntent(with: fromURL, options: .forDeleting)
			let replacingIntent = NSFileAccessIntent.writingIntent(with: toURL, options: .forReplacing)
			NSFileCoordinator().coordinate(with: [movingIntent,replacingIntent], queue: self.workerQueue) {
				if successfulSecurityScopedResourceAccess {
					defer { fromURL.stopAccessingSecurityScopedResource() }
				}
				guard $0 == nil else { return }
				do {
					try self.coordinator.moveFile(fromURL: movingIntent.url, toURL: replacingIntent.url)
					completion?(toURL)
				}catch{}
			}
		}
	}
	func deleteFileAtIndex(_ index:Int){
		let url = self.documents[index].url
		workerQueue.addOperation {
			let successfulSecurityScopedResourceAccess = url.startAccessingSecurityScopedResource()

			let writingIntent = NSFileAccessIntent.writingIntent(with: url as URL, options: .forDeleting)
			NSFileCoordinator().coordinate(with: [writingIntent], queue: self.workerQueue) {
				if successfulSecurityScopedResourceAccess {
					defer { url.stopAccessingSecurityScopedResource() }
				}
				guard $0 == nil else { return }
				do {
					try self.coordinator.deleteFileAtURL(writingIntent.url)
				} catch {}
			}
		}
	}
}









