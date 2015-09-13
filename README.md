# DocumentKit
DocumentKit Provides a document browser for document based apps on iOS, with access to both iCloud and Local Documents.

#To use DocumentKit:
1. Import the DocumentKit framework and Link Your app against it
2. Set your info plist keys.
3. Subclass DocumentAppDelegate.
4. Implement DocumentEditor
5. Leave Main Interface in your Application Target blank. DocumentKit will create the root view controller.


#Settting Info plist keys
Add the "DocumentKit" key to your info.plist and set it as a dictionary with the following keys:
- "File Extension": the file extension that the document browser should look for
- "Help File": The name of the HTML file in your app bundle that displays help information
- "Document Browser Title": The title to be displayed by the Document browser. The back button will display "Documents"
- "Document Storyboard": The storyboard containing your document editor. The Root View Controller must implement the DocumentEditor protocol.
- "Quick Action Recents": YES if recent documents should be available as quick actions on devices that support 3D touch. NO if your app sets its own quick actions


#Subclassing DocumentAppDelegate
DocumentAppDelegate is a UIResponder subclass that implements the UIApplicationDelegate Protocol. If you choose to override any of the Applicatoin Delegate Functions listed in the public header you must call super.
You must override two properties of DocumentAppDelegate:
- documentSubclass should return your UIDocument Subclass so that the UIDocument can be initialized properly.
- browserTintColor should return the tint color for your app. this will be applied to the Document Browser

#Implementing DocumentEditor
The root view controller in your storyboard must implement DocumentEditor.
When a document is selected, DocumentKit will call presentDocument and pass the UIDocument object to your root view controller before it is presented.
