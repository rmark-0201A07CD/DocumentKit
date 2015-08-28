//
//  DocumentSelectionViewController.swift
//  StudyCards
//
//  Created by Robbie Markwick on 12/17/14.
//
//

import UIKit



class DocumentBrowserViewController: UITableViewController,DocumentControllerDelegate {
	
	private static let recentsSection = 0
	private static let documentSection = 1
	
	private var documentController = DocumentController.sharedDocumentController
	

/// View Management
	var browserTitle:String = "" {
		didSet {
			navigationItem.title = browserTitle
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		//Set Up UI
		clearsSelectionOnViewWillAppear = true
		navigationItem.leftBarButtonItem = editButtonItem()
		//Look for Documents
		documentController.delegate = self
	}
	
	override func viewWillAppear(animated:Bool){
		super.viewDidAppear(animated)
		navigationItem.title = browserTitle
		tableView.reloadData()
	}
	override func viewWillDisappear(animated: Bool) {
		navigationItem.title = "Documents"
	}

	
	/// Table View
	
	override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return 2
	}
	override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		switch section {
		case DocumentBrowserViewController.recentsSection: return "Recents"
		case DocumentBrowserViewController.documentSection: return "All Documents"
		default: return ""
		}
	}
	override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		switch section {
		case DocumentBrowserViewController.recentsSection: return documentController.numberOfRecents
		case DocumentBrowserViewController.documentSection: return documentController.numberOfDocuments
		default: return 0
		}
	}
	override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
		if editing && indexPath.section == DocumentBrowserViewController.recentsSection {
			return 0.0
		}
		return super.tableView(tableView,heightForRowAtIndexPath:indexPath)
	}
	override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier("Document Cell", forIndexPath: indexPath)
		if let cell = cell as? DocumentCell {
			
			if indexPath.section == DocumentBrowserViewController.recentsSection {
				let document = DocumentController.sharedDocumentController.recents[indexPath.item]
				cell.documentName?.text = document.displayName
			} else if indexPath.section == DocumentBrowserViewController.documentSection {
				let document = DocumentController.sharedDocumentController.documents[indexPath.item]
				cell.documentName?.text = document.displayName
			}
			
			cell.documentName?.enabled = editing && indexPath.section == DocumentBrowserViewController.documentSection
			cell.documentBrowser = self
		}
		return cell
	}
	override func editButtonItem() -> UIBarButtonItem {
		return UIBarButtonItem(title: editing ? "Done" : "Edit", style: editing ? .Done : .Plain, target: self,  action: "pressEdit:")
	}
	@objc func pressEdit(sender:UIBarButtonItem){
		//Animation
		setEditing(!editing, animated: true)
		tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .Automatic)
	}
	
	override func setEditing(editing:Bool, animated:Bool){
		super.setEditing(editing, animated:animated)
		navigationItem.leftBarButtonItem = editButtonItem()
		navigationItem.rightBarButtonItem?.enabled = !editing
		for i in 0..<tableView.numberOfRowsInSection(DocumentBrowserViewController.documentSection){
			if let cell = tableView.cellForRowAtIndexPath(NSIndexPath(forRow:i, inSection:DocumentBrowserViewController.documentSection)) as? DocumentCell {
				cell.documentName?.enabled = self.editing
			}
		}
	}
	override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
		return indexPath.section == DocumentBrowserViewController.documentSection
	}
	override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
		guard editingStyle == .Delete && indexPath.section == DocumentBrowserViewController.documentSection else { return }
		documentController.deleteFileAtIndex(indexPath.row)
	}
	override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		if indexPath.section == DocumentBrowserViewController.recentsSection {
			openDocumentAtURL(documentController.recents[indexPath.row].URL)
		} else if indexPath.section == DocumentBrowserViewController.documentSection {
			openDocumentAtURL(documentController.documents[indexPath.row].URL)
		}
	}

	
/// Document Controller Delegate
	func reloadData() {
		tableView.reloadData()
	}
	func processAnimations(animations: [DocumentBrowserAnimation]) {
		processAnimations(animations, section: DocumentBrowserViewController.documentSection)
	}
	func processRecentsAnimations(animations: [DocumentBrowserAnimation]) {
		processAnimations(animations, section: DocumentBrowserViewController.recentsSection)
	}
	private func processAnimations(animations: [DocumentBrowserAnimation], section:Int){
		tableView.beginUpdates()
		var indexPathsNeedingReload = [NSIndexPath]()
		for animation in animations {
			switch animation {
			case .Add(let row):
				let indexPath = NSIndexPath(forRow: row, inSection: section)
				tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
			case .Delete(let row):
				let indexPath = NSIndexPath(forRow: row, inSection: section)
				tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
			case .Move(let from, let to):
				let fromIndexPath = NSIndexPath(forRow: from, inSection: section)
				let toIndexPath = NSIndexPath(forRow: to, inSection: section)
				tableView.moveRowAtIndexPath(fromIndexPath, toIndexPath: toIndexPath)
			case .Update(let row):
				indexPathsNeedingReload += [ NSIndexPath(forRow: row, inSection: section)]
			case .Reload: break
			}
		}
		tableView.reloadRowsAtIndexPaths(indexPathsNeedingReload, withRowAnimation: .Automatic)
		tableView.endUpdates()
	}
	
	
/// Document Handling
	@IBAction func newDocument(){
		documentController.createNewDocument { self.openDocumentAtURL($0) }
	}
	
	private func initializeDocumentStoryboard() -> UIViewController? {
		do {
			let plistData = try loadDocumentKitPlistData()
			guard let storyBoardName = plistData["Document Storyboard"] as? String else { throw DocumentBrowserError.InfoPlistKeysMissing }
			let storyboard = UIStoryboard(name: storyBoardName, bundle: NSBundle.mainBundle())
			return storyboard.instantiateInitialViewController()
		} catch { return nil}
	}
	
	func openDocumentAtURL(url:NSURL, handoffState:[NSObject:AnyObject]? = nil){
		let document = documentController.openDocumentAtURL(url,handoffState: handoffState)
		guard let destVC = initializeDocumentStoryboard() else { return }
		(destVC as? DocumentEditor)?.presentDocument(document)
		navigationController?.pushViewController(destVC, animated: true)
	}
	override func restoreUserActivityState(activity: NSUserActivity) {
		guard let handoffState = activity.userInfo else { return }
		guard let url = handoffState[NSUserActivityDocumentURLKey] as? NSURL  else { return }
		openDocumentAtURL(url, handoffState: handoffState)
}
	func renameDocumentForCell(cell:DocumentCell){
		guard let index = tableView.indexPathForCell(cell)?.item else { return }
		guard let documentName = cell.documentName?.text else { return }
		
		let oldURL = documentController.documents[index].URL
		let directory = oldURL.URLByDeletingLastPathComponent
		guard let newURL = directory?.URLByAppendingPathComponent("\(documentName).flshcrdx") else { return }
		
		documentController.moveFile(fromURL:oldURL,toURL:newURL)
	}
	
}

class DocumentCell: UITableViewCell, UITextFieldDelegate {
	@IBOutlet var documentName:UITextField?
	
	var documentBrowser:DocumentBrowserViewController?
	
	func textFieldDidEndEditing(textField: UITextField){
		documentBrowser?.renameDocumentForCell(self)
	}
	func textFieldShouldReturn(textField: UITextField) -> Bool {
		textFieldDidEndEditing(textField)
		textField.resignFirstResponder()
		return true
	}
	
}








