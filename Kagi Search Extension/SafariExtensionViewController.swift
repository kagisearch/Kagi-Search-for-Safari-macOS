//
//  SafariExtensionViewController.swift
//  Kagi Search Extension
//

import SafariServices

class SafariExtensionViewController: SFSafariExtensionViewController, NSTextFieldDelegate {
    
    @IBOutlet weak var linkField: NSTextField!
    static let key = "kagiSessionLink"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        linkField.delegate = self
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        linkField.stringValue = UserDefaults.standard.string(forKey: Self.key) ?? ""
    }
    
    func controlTextDidChange(_ obj: Notification) {
        UserDefaults.standard.set(linkField.stringValue, forKey: Self.key)
    }
    
    @IBAction func getLinkTapped(_ sender: Any) {
        SFSafariApplication.getActiveWindow { window in
            window?.openTab(
                with: URL(string: "https://kagi.com/settings?p=user_details#sessionlink")!,
                makeActiveIfPossible: true
            )
        }
    }
    
    static let shared: SafariExtensionViewController = {
        let shared = SafariExtensionViewController()
        shared.preferredContentSize = NSSize(width: 372, height: 190)
        return shared
    }()
}
