//
//  HelpBarButtonItem.swift
//  StudyCards +
//
//  Created by Robbie Markwick on 7/23/15.
//
//

import UIKit

public class HelpBarButtonItem: UIBarButtonItem {

	public convenience init(viewController:UIViewController){
		self.init()
		self.viewController = viewController
	}

	public override init(){
		super.init()
		title = "Help"
		target = self
		action = "showHelp"
	}

	public required convenience init?(coder aDecoder: NSCoder) {
	    self.init()
	}
	
	@IBOutlet public var viewController:UIViewController?
	
	func showHelp(){
		let helpStoryBoard = UIStoryboard(name: "Help", bundle: NSBundle(identifier: "com.markwick.DocumentKit"))
		guard let helpVC = helpStoryBoard.instantiateInitialViewController() else { return }
		helpVC.preparePopover(self)
		viewController?.presentViewController(helpVC, animated: true, completion: nil)
	}
	
}

extension UIViewController {
	func preparePopover(sender:AnyObject?) {
		modalPresentationStyle = .Popover
		popoverPresentationController?.barButtonItem = sender as? UIBarButtonItem
		popoverPresentationController?.sourceView = sender as? UIView
		if let gesture = sender as? UIGestureRecognizer {
			popoverPresentationController?.sourceView = gesture.view
			popoverPresentationController?.sourceRect = CGRect(origin: gesture.locationInView(gesture.view), size: CGSize(width: 0, height: 0))
		}
		popoverPresentationController?.permittedArrowDirections = .Any
	}
}
