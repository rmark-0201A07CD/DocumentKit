//
//  DocumentHelpViewController.swift
//  StudyCards +
//
//  Created by Robbie Markwick on 7/23/15.
//
//

import UIKit


class DocumentHelpViewController: UIViewController,UIWebViewDelegate {

	@IBOutlet var webView:UIWebView?
	override func viewDidLoad() {
		super.viewDidLoad()
		do {
			guard let helpFile = DocumentAppDelegate.plistData["Help File"] as? String else { throw DocumentBrowserError.infoPlistKeysMissing }
			guard let contentURL = Bundle.main().urlForResource(helpFile, withExtension: "html") else { throw DocumentBrowserError.helpFileMissing }
			let htmlString = String(contentsOfURL: contentURL, encoding: String.Encoding.ascii)
			webView?.loadHTMLString(htmlString, baseURL: contentURL)
		} catch { }
	}
	func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
		webView.loadRequest(request)
		return true
	}
	@IBAction func dismiss(_ sender:AnyObject?){
		self.dismiss(animated: true, completion: nil)
	}
}
