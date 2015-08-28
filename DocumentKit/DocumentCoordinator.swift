//
//  DocumentCoordinator.swift
//  StudyCards +
//
//  Created by Robbie Markwick on 7/18/15.
//
//

import Foundation

protocol DocumentCoordinatorDelegate:class {
	func documentQueryResultsDidChangeWithResults(results: [ModelObject], animations: [DocumentBrowserAnimation])
}

class DocumentCoordinator: NSObject {
	
	weak var delegate:DocumentCoordinatorDelegate? {
		didSet {
			delegate?.documentQueryResultsDidChangeWithResults(documents, animations: [.Reload])
		}
	}
	override init(){
		super.init()
		metadataQuery.operationQueue = workerQueue
		if !isLocal {
			NSNotificationCenter.defaultCenter().addObserver(self, selector: "finishGathering:", name:NSMetadataQueryDidFinishGatheringNotification, object: metadataQuery)
			NSNotificationCenter.defaultCenter().addObserver(self, selector: "queryUpdated:", name: NSMetadataQueryDidUpdateNotification, object: metadataQuery)
			metadataQuery.startQuery()
		}
	}

	
	private var documents = [ModelObject]()
	var fileExtension:String = ""
	
	private let workerQueue: NSOperationQueue = {
		let workerQueue = NSOperationQueue()
		workerQueue.name = "com.markwick.documentbrowser.queryQueue"
		return workerQueue
	}()
	
	private var documentsDirectory:NSURL {
		let fm = NSFileManager.defaultManager()
		if let iCloud = fm.URLForUbiquityContainerIdentifier(nil)?.URLByAppendingPathComponent("Documents") {
			return iCloud
		} else {
			return fm.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[0]
		}
	}
	
/// Local Documents
	var isLocal:Bool {
		return NSFileManager().ubiquityIdentityToken == nil
	}
	func loadLocalDocuments(){
		guard isLocal else { return }
		let directory = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[0]
		do {
			documents = try NSFileManager.defaultManager().contentsOfDirectoryAtURL(directory,includingPropertiesForKeys: nil, options: [])
				.filter { $0.pathExtension == .Some(self.fileExtension) }
				.map { DocumentBrowserModelObject(URL: $0) }
			NSOperationQueue.mainQueue().addOperationWithBlock {
				self.delegate?.documentQueryResultsDidChangeWithResults(self.documents, animations: [.Reload])
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
	private var previousQueryObjects: NSOrderedSet?
	
	// Query Notifications
	@objc func queryUpdated(notification: NSNotification) {
		metadataQuery.disableUpdates()
		defer { metadataQuery.enableUpdates() }
		
		let changedMetadataItems = notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem]
		let removedMetadataItems = notification.userInfo?[NSMetadataQueryUpdateRemovedItemsKey] as? [NSMetadataItem]
		let addedMetadataItems = notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem]
		
		let changedResults = buildModelObjectSet(changedMetadataItems ?? [])
		let removedResults = buildModelObjectSet(removedMetadataItems ?? [])
		let addedResults = buildModelObjectSet(addedMetadataItems ?? [])
		
		guard let metadataQueryResults = metadataQuery.results as? [NSMetadataItem] else { return }
		let newResults = buildModelObjectSet(metadataQueryResults)
		
		updateWithResults(newResults, removedResults: removedResults, addedResults: addedResults, changedResults: changedResults)
	}
	
	@objc func finishGathering(notification: NSNotification) {
		metadataQuery.disableUpdates()
		defer { metadataQuery.enableUpdates() }
		
		guard let metadataQueryResults = metadataQuery.results as? [NSMetadataItem] else { return }
		let results = buildModelObjectSet(metadataQueryResults)
		
		updateWithResults(results, removedResults: NSOrderedSet(), addedResults: NSOrderedSet(), changedResults: NSOrderedSet())
	}
	
	//Processing Notifications
	private func buildModelObjectSet(objects: [NSMetadataItem]) -> NSOrderedSet {
		let array = objects.map { DocumentBrowserModelObject(item: $0) }.sort { $0.displayName < $1.displayName }
		return NSMutableOrderedSet(array: array)
	}
	
	private func computeAnimationsForNewResults(newResults: NSOrderedSet, oldResults: NSOrderedSet, removedResults: NSOrderedSet, addedResults: NSOrderedSet, changedResults: NSOrderedSet) -> [DocumentBrowserAnimation] {
		
		let oldResultAnimations: [DocumentBrowserAnimation] = removedResults.array.flatMap { removedResult in
			let oldIndex = oldResults.indexOfObject(removedResult)
			guard oldIndex != NSNotFound else { return nil }
			return .Delete(index: oldIndex)
		}
		
		let newResultAnimations: [DocumentBrowserAnimation] = addedResults.array.flatMap { addedResult in
			let newIndex = newResults.indexOfObject(addedResult)
			guard newIndex != NSNotFound else { return nil }
			return .Add(index: newIndex)
		}
		
		let movedResultAnimations: [DocumentBrowserAnimation] = changedResults.array.flatMap { movedResult in
			let oldIndex = oldResults.indexOfObject(movedResult)
			let newIndex = newResults.indexOfObject(movedResult)
			guard oldIndex != NSNotFound && newIndex != NSNotFound && oldIndex != newIndex else { return nil }
			return .Move(fromIndex: oldIndex, toIndex: newIndex)
		}
		
		let changedResultAnimations: [DocumentBrowserAnimation] = changedResults.array.flatMap { changedResult in
			let index = newResults.indexOfObject(changedResult)
			guard index != NSNotFound else { return nil }
			return .Update(index: index)
		}
		
		return oldResultAnimations + changedResultAnimations + newResultAnimations + movedResultAnimations
	}
	
	private func updateWithResults(results: NSOrderedSet, removedResults: NSOrderedSet, addedResults: NSOrderedSet, changedResults: NSOrderedSet) {
		guard let queryResults = results.array as? [DocumentBrowserModelObject] else { return }
		let queryAnimations: [DocumentBrowserAnimation]
		
		if let oldResults = previousQueryObjects {
			queryAnimations = computeAnimationsForNewResults(results, oldResults: oldResults, removedResults: removedResults, addedResults: addedResults, changedResults: changedResults)
		} else {
			queryAnimations = [.Reload]
		}
		previousQueryObjects = results
		
		NSOperationQueue.mainQueue().addOperationWithBlock {
			self.delegate?.documentQueryResultsDidChangeWithResults(queryResults, animations: queryAnimations)
		}
	}
	
/// Document Management
	func urlForNewDocument(originalFileName:String? = nil)->NSURL {
		let fileName = originalFileName ?? "Untitled"
		let baseURL = self.documentsDirectory.URLByAppendingPathComponent(fileName)
		var target = baseURL.URLByAppendingPathExtension(self.fileExtension)
		
		var nameSuffix = 1
		while target.checkPromisedItemIsReachableAndReturnError(nil) {
			target = NSURL(fileURLWithPath: baseURL.path! + "-\(++nameSuffix).\(self.fileExtension)")
		}
		return target
	}
	
	func addDocumentAtURL(URL:NSURL) throws {
		try NSFileWrapper(directoryWithFileWrappers: [:]).writeToURL(URL, options: .Atomic,originalContentsURL: nil)
		try URL.setResourceValue(true, forKey: NSURLHasHiddenExtensionKey)
		
		guard isLocal else { return }
		let modelObject = DocumentBrowserModelObject(URL: URL)
		documents.insert(modelObject, atIndex: 0)
		NSOperationQueue.mainQueue().addOperationWithBlock {
			self.delegate?.documentQueryResultsDidChangeWithResults(self.documents, animations: [.Add(index:0)])
		}
	}

	func moveFile(fromURL fromURL:NSURL, toURL:NSURL, documentIndex:Int? = nil) throws{
		try NSFileManager.defaultManager().moveItemAtURL(fromURL, toURL: toURL)
		if let path = toURL.path{
			try NSFileManager.defaultManager().setAttributes([NSFileExtensionHidden: true], ofItemAtPath: path)
		}
		guard isLocal else { return }
		guard let index = (documents.map{ $0.URL }).indexOf(fromURL) else {
			loadLocalDocuments()
			return
		}
		documents[index] = DocumentBrowserModelObject(URL: toURL)
		NSOperationQueue.mainQueue().addOperationWithBlock {
			self.delegate?.documentQueryResultsDidChangeWithResults(self.documents, animations: [.Update(index:0)])
		}
	}
	
	func deleteFileAtURL(URL:NSURL) throws{
		try NSFileManager.defaultManager().removeItemAtURL(URL)
		guard isLocal else { return }
		guard let idx = (documents.map{ $0.URL }).indexOf(URL) else {
			loadLocalDocuments()
			return
		}
		documents.removeAtIndex(idx)
		NSOperationQueue.mainQueue().addOperationWithBlock {
			self.delegate?.documentQueryResultsDidChangeWithResults(self.documents, animations: [.Delete(index:idx)])
		}
	}
	
}
