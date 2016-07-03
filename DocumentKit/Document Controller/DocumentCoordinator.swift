//
//  DocumentCoordinator.swift
//  StudyCards +
//
//  Created by Robbie Markwick on 7/18/15.
//
//

import Foundation

protocol DocumentCoordinatorDelegate:class {
	func documentQueryResultsDidChangeWithResults(_ results: [DocumentBrowserModelObject], animations: [DocumentBrowserAnimation])
}

class DocumentCoordinator: NSObject {
	
	weak var delegate:DocumentCoordinatorDelegate? {
		didSet {
			delegate?.documentQueryResultsDidChangeWithResults(documents, animations: [.reload])
		}
	}
	override init(){
		super.init()
		metadataQuery.operationQueue = workerQueue
		if !isLocal {
			NotificationCenter.default().addObserver(self, selector: #selector(DocumentCoordinator.finishGathering(_:)), name:NSNotification.Name.NSMetadataQueryDidFinishGathering, object: metadataQuery)
			NotificationCenter.default().addObserver(self, selector: #selector(DocumentCoordinator.queryUpdated(_:)), name: NSNotification.Name.NSMetadataQueryDidUpdate, object: metadataQuery)
			metadataQuery.start()
		}
	}

	
	private var documents = [DocumentBrowserModelObject]()
	var fileExtension:String = "" {
		didSet {
			metadataQuery.predicate = Predicate(format: "%K like '*%@'", NSMetadataItemFSNameKey,fileExtension)
		}
	}
	
	private let workerQueue: OperationQueue = {
		let workerQueue = OperationQueue()
		workerQueue.name = "com.markwick.documentbrowser.queryQueue"
		return workerQueue
	}()
	
	private var documentsDirectory:URL {
		let fm = FileManager.default()
		if let iCloud = try! fm.urlForUbiquityContainerIdentifier(nil)?.appendingPathComponent("Documents") {
			return iCloud
		} else {
			return fm.urlsForDirectory(.documentDirectory, inDomains: .userDomainMask)[0]
		}
	}
	
/// Local Documents
	var isLocal:Bool {
		return FileManager().ubiquityIdentityToken == nil
	}
	func loadLocalDocuments(){
		guard isLocal else { return }
		let directory = FileManager.default().urlsForDirectory(.documentDirectory, inDomains: .userDomainMask)[0]
		do {
			documents = try FileManager.default().contentsOfDirectory(at: directory,includingPropertiesForKeys: nil, options: [])
				.filter { $0.pathExtension == .some(self.fileExtension) }
				.map { DocumentBrowserModelObject(url: $0) }
			OperationQueue.main().addOperation {
				self.delegate?.documentQueryResultsDidChangeWithResults(self.documents, animations: [.reload])
			}
		} catch {}
	}
	
///iCloud Documents
	private var metadataQuery: NSMetadataQuery = {
		let query = NSMetadataQuery()
		query.searchScopes = [
			NSMetadataQueryUbiquitousDocumentsScope,
			NSMetadataQueryAccessibleUbiquitousExternalDocumentsScope
		]
		return query
	}()
	private var previousQueryObjects: OrderedSet?
	
	// Query Notifications
	@objc func queryUpdated(_ notification: Notification) {
		metadataQuery.disableUpdates()
		defer { metadataQuery.enableUpdates() }
		
		let changedMetadataItems = (notification as NSNotification).userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem]
		let removedMetadataItems = (notification as NSNotification).userInfo?[NSMetadataQueryUpdateRemovedItemsKey] as? [NSMetadataItem]
		let addedMetadataItems = (notification as NSNotification).userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem]
		
		let changedResults = buildModelObjectSet(changedMetadataItems ?? [])
		let removedResults = buildModelObjectSet(removedMetadataItems ?? [])
		let addedResults = buildModelObjectSet(addedMetadataItems ?? [])
		
		guard let metadataQueryResults = metadataQuery.results as? [NSMetadataItem] else { return }
		let newResults = buildModelObjectSet(metadataQueryResults)
		
		update(newResults: newResults, removedResults: removedResults, addedResults: addedResults, changedResults: changedResults)
	}
	
	@objc func finishGathering(_ notification: Notification) {
		metadataQuery.disableUpdates()
		defer { metadataQuery.enableUpdates() }
		
		guard let metadataQueryResults = metadataQuery.results as? [NSMetadataItem] else { return }
		let results = buildModelObjectSet(metadataQueryResults)
		
		update(newResults: results, removedResults: OrderedSet(), addedResults: OrderedSet(), changedResults: OrderedSet())
	}
	
	//Processing Notifications
	private func buildModelObjectSet(_ objects: [NSMetadataItem]) -> OrderedSet {
		let array = objects.map { DocumentBrowserModelObject(item: $0) }.sorted { $0.displayName < $1.displayName }
		return NSMutableOrderedSet(array: array)
	}
	
	private func computeAnimations(newResults: OrderedSet, oldResults: OrderedSet, removedResults: OrderedSet, addedResults: OrderedSet, changedResults: OrderedSet) -> [DocumentBrowserAnimation] {
		
		let oldResultAnimations: [DocumentBrowserAnimation] = removedResults.array.flatMap { removedResult in
			let oldIndex = oldResults.index(of: removedResult)
			guard oldIndex != NSNotFound else { return nil }
			return .delete(index: oldIndex)
		}
		
		let newResultAnimations: [DocumentBrowserAnimation] = addedResults.array.flatMap { addedResult in
			let newIndex = newResults.index(of: addedResult)
			guard newIndex != NSNotFound else { return nil }
			return .add(index: newIndex)
		}
		
		let movedResultAnimations: [DocumentBrowserAnimation] = changedResults.array.flatMap { movedResult in
			let oldIndex = oldResults.index(of: movedResult)
			let newIndex = newResults.index(of: movedResult)
			guard oldIndex != NSNotFound && newIndex != NSNotFound && oldIndex != newIndex else { return nil }
			return .move(fromIndex: oldIndex, toIndex: newIndex)
		}
		
		let changedResultAnimations: [DocumentBrowserAnimation] = changedResults.array.flatMap { changedResult in
			let index = newResults.index(of: changedResult)
			guard index != NSNotFound else { return nil }
			return .update(index: index)
		}
		
		return oldResultAnimations + changedResultAnimations + newResultAnimations + movedResultAnimations
	}
	
	private func update(newResults results: OrderedSet, removedResults: OrderedSet, addedResults: OrderedSet, changedResults: OrderedSet) {
		guard let queryResults = results.array as? [DocumentBrowserModelObject] else { return }
		let queryAnimations: [DocumentBrowserAnimation]
		
		if let oldResults = previousQueryObjects {
			queryAnimations = computeAnimations(newResults: results, oldResults: oldResults, removedResults: removedResults, addedResults: addedResults, changedResults: changedResults)
		} else {
			queryAnimations = [.reload]
		}
		previousQueryObjects = results
		
		
		OperationQueue.main().addOperation {
			self.delegate?.documentQueryResultsDidChangeWithResults(queryResults, animations: queryAnimations)
		}
	}
	
/// Document Management
	func urlForNewDocument(_ originalFileName:String? = nil)->URL {
		let fileName = originalFileName ?? "Untitled"
		let baseURL = try! self.documentsDirectory.appendingPathComponent(fileName)
		var target = try! baseURL.appendingPathExtension(self.fileExtension)

		var nameSuffix = 2
		let checkExistence = { (url:URL) -> Bool  in
			do{ return try url.checkPromisedItemIsReachable() }
			catch { return true }
		}
		while checkExistence(target) {
			target = URL(fileURLWithPath: baseURL.path! + "-\(nameSuffix).\(self.fileExtension)")
			nameSuffix+=1
		}
		return target
	}
	
	func addDocument(at URL:Foundation.URL) throws {
		try FileWrapper(directoryWithFileWrappers: [:]).write(to: URL, options: .atomic,originalContentsURL: nil)
		try (URL as NSURL).setResourceValue(true, forKey: URLResourceKey.hasHiddenExtensionKey)
		
		guard isLocal else { return }
		let modelObject = DocumentBrowserModelObject(url: URL)
		documents.insert(modelObject, at: 0)
		OperationQueue.main().addOperation {
			self.delegate?.documentQueryResultsDidChangeWithResults(self.documents, animations: [.add(index:0)])
		}
	}

	func moveFile(fromURL:URL, toURL:URL, documentIndex:Int? = nil) throws{
		try FileManager.default().moveItem(at: fromURL, to: toURL)
		if let path = toURL.path{
			try FileManager.default().setAttributes([FileAttributeKey.extensionHidden.rawValue: true], ofItemAtPath: path)
		}
		guard isLocal else { return }
		guard let index = (documents.map{ $0.url }).index(of: fromURL) else {
			loadLocalDocuments()
			return
		}
		documents[index] = DocumentBrowserModelObject(url: toURL)
		OperationQueue.main().addOperation {
			self.delegate?.documentQueryResultsDidChangeWithResults(self.documents, animations: [.update(index:0)])
		}
	}
	
	func deleteFile(at URL:Foundation.URL) throws{
		try FileManager.default().removeItem(at: URL)
		guard isLocal else { return }
		guard let idx = (documents.map{ $0.url }).index(of: URL) else {
			loadLocalDocuments()
			return
		}
		documents.remove(at: idx)
		OperationQueue.main().addOperation {
			self.delegate?.documentQueryResultsDidChangeWithResults(self.documents, animations: [.delete(index:idx)])
		}
	}
	
}
