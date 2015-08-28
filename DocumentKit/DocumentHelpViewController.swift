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
			guard let helpFile = try loadDocumentKitPlistData()["Help File"] as? String else { throw DocumentBrowserError.InfoPlistKeysMissing }
			guard let contentURL = NSBundle.mainBundle().URLForResource(helpFile, withExtension: "html") else { throw DocumentBrowserError.HelpFileMissing }
			let htmlString = try String(contentsOfURL: contentURL, encoding: NSASCIIStringEncoding)
			webView?.loadHTMLString(htmlString, baseURL: contentURL)
		} catch { }
	}
	func webView(webView: UIWebView, shouldStartLoadWithRequest request: NSURLRequest, navigationType: UIWebViewNavigationType) -> Bool {
		webView.loadRequest(request)
		return true
	}
	@IBAction func dismiss(sender:AnyObject?){
		dismissViewControllerAnimated(true, completion: nil)
	}
}