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
	
	var openedDocument:UIDocument?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		//Set Up UI
		clearsSelectionOnViewWillAppear = true
		navigationItem.leftBarButtonItem = editButtonItem()
		//Look for Documents
		documentController.delegate = self
	}
	
	override func viewWillAppear(_ animated:Bool){
		super.viewDidAppear(animated)
		navigationItem.title = browserTitle
		tableView.reloadData()
		openedDocument?.saveAndClose()
	}
	override func viewWillDisappear(_ animated: Bool) {
		navigationItem.title = "Documents"
	}

	
	/// Table View
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		return 2
	}
	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		switch section {
		case DocumentBrowserViewController.recentsSection: return "Recents"
		case DocumentBrowserViewController.documentSection: return "All Documents"
		default: return ""
		}
	}
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		switch section {
		case DocumentBrowserViewController.recentsSection: return documentController.numberOfRecents
		case DocumentBrowserViewController.documentSection: return documentController.numberOfDocuments
		default: return 0
		}
	}
	override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		if isEditing && (indexPath as NSIndexPath).section == DocumentBrowserViewController.recentsSection {
			return 0.0
		}
		return super.tableView(tableView,heightForRowAt:indexPath)
	}
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "Document Cell", for: indexPath)
		if let cell = cell as? DocumentCell {
			
			if (indexPath as NSIndexPath).section == DocumentBrowserViewController.recentsSection {
				let document = DocumentController.sharedDocumentController.recents[(indexPath as NSIndexPath).item]
				cell.documentName?.text = document.displayName
			} else if (indexPath as NSIndexPath).section == DocumentBrowserViewController.documentSection {
				let document = DocumentController.sharedDocumentController.documents[(indexPath as NSIndexPath).item]
				cell.documentName?.text = document.displayName
			}
			
			cell.documentName?.isEnabled = isEditing && (indexPath as NSIndexPath).section == DocumentBrowserViewController.documentSection
			cell.documentBrowser = self
		}
		return cell
	}
	override func editButtonItem() -> UIBarButtonItem {
		return UIBarButtonItem(title: isEditing ? "Done" : "Edit", style: isEditing ? .done : .plain, target: self,  action: #selector(DocumentBrowserViewController.pressEdit(_:)))
	}
	@objc func pressEdit(_ sender:UIBarButtonItem){
		//Animation
		setEditing(!isEditing, animated: true)
		tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
	}
	
	override func setEditing(_ editing:Bool, animated:Bool){
		super.setEditing(editing, animated:animated)
		navigationItem.leftBarButtonItem = editButtonItem()
		navigationItem.rightBarButtonItem?.isEnabled = !editing
		for i in 0..<tableView.numberOfRows(inSection: DocumentBrowserViewController.documentSection){
			if let cell = tableView.cellForRow(at: IndexPath(row:i, section:DocumentBrowserViewController.documentSection)) as? DocumentCell {
				cell.documentName?.isEnabled = self.isEditing
			}
		}
	}
	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		return (indexPath as NSIndexPath).section == DocumentBrowserViewController.documentSection
	}
	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
		guard editingStyle == .delete && (indexPath as NSIndexPath).section == DocumentBrowserViewController.documentSection else { return }
		documentController.deleteFileAtIndex((indexPath as NSIndexPath).row)
	}
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if (indexPath as NSIndexPath).section == DocumentBrowserViewController.recentsSection {
			openDocumentAtURL(documentController.recents[(indexPath as NSIndexPath).row].url as URL)
		} else if (indexPath as NSIndexPath).section == DocumentBrowserViewController.documentSection {
			openDocumentAtURL(documentController.documents[(indexPath as NSIndexPath).row].url as URL)
		}
	}

	
/// Document Controller Delegate
	func reloadData() {
		tableView.reloadData()
	}
	func processAnimations(_ animations: [DocumentBrowserAnimation]) {
		processAnimations(animations, section: DocumentBrowserViewController.documentSection)
	}
	func processRecentsAnimations(_ animations: [DocumentBrowserAnimation]) {
		processAnimations(animations, section: DocumentBrowserViewController.recentsSection)
	}
	private func processAnimations(_ animations: [DocumentBrowserAnimation], section:Int){
		tableView.beginUpdates()
		var indexPathsNeedingReload = [IndexPath]()
		for animation in animations {
			switch animation {
			case .add(let row):
				let indexPath = IndexPath(row: row, section: section)
				tableView.insertRows(at: [indexPath], with: .automatic)
			case .delete(let row):
				let indexPath = IndexPath(row: row, section: section)
				tableView.deleteRows(at: [indexPath], with: .automatic)
			case .move(let from, let to):
				let fromIndexPath = IndexPath(row: from, section: section)
				let toIndexPath = IndexPath(row: to, section: section)
				tableView.moveRow(at: fromIndexPath, to: toIndexPath)
			case .update(let row):
				indexPathsNeedingReload += [ IndexPath(row: row, section: section)]
			case .reload: break
			}
		}
		tableView.reloadRows(at: indexPathsNeedingReload, with: .automatic)
		tableView.endUpdates()
	}
	
	
/// Document Handling
	@IBAction func newDocument(){
		documentController.createNewDocument { self.openDocumentAtURL($0 as URL) }
	}
	
	private func initializeDocumentStoryboard() -> UIViewController? {
		do {
			let plistData = try loadDocumentKitPlistData()
			guard let storyBoardName = plistData["Document Storyboard"] as? String else { throw DocumentBrowserError.infoPlistKeysMissing }
			let storyboard = UIStoryboard(name: storyBoardName, bundle: Bundle.main())
			return storyboard.instantiateInitialViewController()
		} catch { return nil}
	}
	
	func openDocumentAtURL(_ url:URL, handoffState:[NSObject:AnyObject]? = nil){
		let document = documentController.openDocumentAtURL(url,handoffState: handoffState)
		openedDocument = document
		guard let destVC = initializeDocumentStoryboard() else { return }
		(destVC as? DocumentEditor)?.presentDocument(document)
		destVC.title = (document.fileURL.lastPathComponent as NSString?)?.deletingPathExtension
		navigationController?.pushViewController(destVC, animated: true)
	}
	override func restoreUserActivityState(_ activity: NSUserActivity) {
		guard let handoffState = activity.userInfo else { return }
		guard let url = handoffState[NSUserActivityDocumentURLKey] as? URL  else { return }
		openDocumentAtURL(url, handoffState: handoffState)
}
	func renameDocumentForCell(_ cell:DocumentCell){
		guard let index = (tableView.indexPath(for: cell) as NSIndexPath?)?.item else { return }
		guard let documentName = cell.documentName?.text else { return }
		
		let oldURL = documentController.documents[index].url
		let directory = try! oldURL.deletingLastPathComponent()
		let newURL = try! directory.appendingPathComponent("\(documentName).flshcrdx")
		
		documentController.moveFile(fromURL:oldURL,toURL:newURL)
	}
	
}

class DocumentCell: UITableViewCell, UITextFieldDelegate {
	@IBOutlet var documentName:UITextField?
	
	var documentBrowser:DocumentBrowserViewController?
	
	func textFieldDidEndEditing(_ textField: UITextField){
		documentBrowser?.renameDocumentForCell(self)
	}
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textFieldDidEndEditing(textField)
		textField.resignFirstResponder()
		return true
	}
	
}








