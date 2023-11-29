//
//  ViewController.swift
//  Shared (App)
//
//  Created by Nano Anderson on 10/17/23.
//

import WebKit

#if os(iOS)
import UIKit
typealias PlatformViewController = UIViewController
typealias Image = UIImage
#elseif os(macOS)
import Cocoa
import SafariServices
typealias PlatformViewController = NSViewController
typealias Image = NSImage
#endif

let extensionBundleIdentifier = "com.kagimacOS.Kagi-Search.WebExtension"
let appWindowFrameAutosaveName = "KagiSearchForSafariWindowFrame"

class ViewController: PlatformViewController, WKNavigationDelegate, WKScriptMessageHandler {

    @IBOutlet var webView: WKWebView!
    
    var cachedSize: CGSize?
    var initialSize: CGSize?
    var shouldShowStatusBar = true

    override func viewDidLoad() {
        super.viewDidLoad()
        
        #if os(macOS)
        view.window?.setFrameAutosaveName(appWindowFrameAutosaveName)
        initialSize = self.webView.bounds.size
        #elseif os(iOS)
        
        #endif

        self.webView.navigationDelegate = self
        if #available(macOS 13.3, iOS 16.4, *) {
            self.webView.isInspectable = true
        }

#if os(iOS)
        self.webView.scrollView.isScrollEnabled = true
#endif

        self.webView.configuration.userContentController.add(self, name: "controller")

        self.webView.loadFileURL(Bundle.main.url(forResource: "Main", withExtension: "html")!, allowingReadAccessTo: Bundle.main.resourceURL!)
    }
#if os(iOS)
    override func viewDidAppear(_ animated: Bool) {
        if let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first,
            let statusBarFrame = view.window?.windowScene?.statusBarManager?.statusBarFrame {
            let blur = UIBlurEffect(style: .regular)
            let effectView = UIVisualEffectView(effect: blur)
            effectView.frame = statusBarFrame
            view.addSubview(effectView)
        }
    }
#endif

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        
        // No way at the moment to target specific profiles from the app.
        guard let currentEngine = Preferences.shared.engine(for: nil) else {
            return
        }
        
        let currentPrivateSessionLink = Preferences.shared.privateSessionLink(for: nil) ?? ""
        
        webView.evaluateJavaScript("addEngineListener();")
        webView.evaluateJavaScript("addPrivateSessionLinkListener();")
        webView.evaluateJavaScript("selectCurrentEngine('\(currentEngine.name)')")
        webView.evaluateJavaScript("setCurrentPrivateSessionLink('\(currentPrivateSessionLink)')")
        
        let iconDataString = Image(named: "LargeIcon")?.pngData()?.base64EncodedString() ?? ""
//        let toolbarIconDataString = Image(named: "ToolbarItemIcon")?.pngData()?.base64EncodedString() ?? ""
        webView.evaluateJavaScript("document.getElementById('icon').setAttribute('src', 'data:image/png;base64,\(iconDataString)')")
//        webView.evaluateJavaScript("document.getElementById('toolbar-icon').setAttribute('src', 'data:image/png;base64,\(toolbarIconDataString)')")
        
#if os(iOS)
        webView.evaluateJavaScript("show('ios')")
#elseif os(macOS)
        webView.evaluateJavaScript("show('mac')")

        detectMacOSExtensionStateChange()
#endif
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let messageBody = message.body as? [String: Any],
            let messageAction = messageBody["action"] as? String else {
            return
        }
        
        switch messageAction {
        case "open-preferences":
            #if os(macOS)
            SFSafariApplication.showPreferencesForExtension(withIdentifier: extensionBundleIdentifier) { error in
                guard error == nil else {
                    // TODO: Insert code to inform the user that something went wrong.
                    return
                }
            }
            #elseif os(iOS)
            if let url = URL(string: "App-Prefs:SAFARI&path=WEB_EXTENSIONS") {
                UIApplication.shared.open(url)
            }
            #endif
            break
        case "engine-changed":
            guard let engineName = messageBody["newEngine"] as? String,
                  let engine = SearchSource.named(engineName) else {
                return
            }
            Preferences.shared.setEngine(engine, profile: nil)
            
            break
            case "private-session-link-changed":
                guard let newLink = messageBody["newLink"] as? String else {
                    return
                }
                Preferences.shared.setPrivateSessionLink(newLink, profile: nil)
                
                break
        case "sync-with-safari":
            #if os(macOS)
            syncDataToSafari(nil)
            #elseif os(iOS)
            
            #endif
            break
        case "update-window-size":
            #if os(macOS)
            guard let currentWindow = view.window else {
                return
            }
            var newHeight: CGFloat = 0
            var newWidth: CGFloat = 0
            if let cachedSize = cachedSize,
               let useCachedSize = messageBody["useCachedSize"] as? Bool,
               useCachedSize == true {
                newHeight = cachedSize.height + currentWindow.titlebarHeight
                newWidth = cachedSize.width
                self.cachedSize = nil
            } else if let messageHeight = messageBody["newHeight"] as? CGFloat,
                      let messageWidth = messageBody["newWidth"] as? CGFloat {
                newHeight = messageHeight + currentWindow.titlebarHeight + 25 // some extra buffer to prevent scrollbars
                newWidth = messageWidth
            }
           
            if let initialSize = initialSize {
                newWidth = max(initialSize.width, newWidth)
                newHeight = max(initialSize.height, newHeight)
            }
            
            let newFrame = currentWindow.frame.insetBy(dx: ((currentWindow.frame.width - newWidth)/2), dy: ((currentWindow.frame.height - newHeight)/2))
            currentWindow.setFrame(newFrame, display: true, animate: true)
            #endif
            break
        case "cache-prescreenshot-size":
            cachedSize = self.webView.bounds.size
            break
        case "open-external-link":
            guard let urlString = messageBody["url"] as? String,
                  let url = URL(string: urlString) else {
                return
            }
            #if os(macOS)
            NSWorkspace.shared.open(url)
            #elseif os(iOS)
            UIApplication.shared.open(url)
            #endif
            break
        case "toggle-statusbar":
            #if os(iOS)
            guard let isVisible = messageBody["isVisible"] as? Bool else {
                return
            }
            shouldShowStatusBar = isVisible
            UIView.animate(withDuration: 0.5) {
                self.setNeedsStatusBarAppearanceUpdate()
            }
            
            #endif
            break
        default:
            break
        }
    }
    
    #if os(iOS)
    override var prefersStatusBarHidden: Bool {
        get {
            !shouldShowStatusBar
        }
    }
    #endif
    
    #if os(macOS)
    @IBAction func syncDataToSafari(_ sender: AnyObject?) {
        guard let currentEngine = Preferences.shared.engine(for: nil) else {
            return
        }
        SFSafariApplication.dispatchMessage(withName: "syncData", toExtensionWithIdentifier: extensionBundleIdentifier, userInfo: [
                "currentEngine": currentEngine.name,
                "privateSessionLink": Preferences.shared.privateSessionLink(for: nil) ?? ""
            ]) { error in
//                DispatchQueue.main.async {
//                    Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
//                        self?.webView.evaluateJavaScript("document.querySelector('button.sync-with-safari').innerText = 'Sync Data to Safari';")
//                    }
//                }
        }
    }
    func detectMacOSExtensionStateChange() {
        SFSafariExtensionManager.getStateOfSafariExtension(withIdentifier: extensionBundleIdentifier) { (state, error) in
            guard let state = state, error == nil else {
                // Insert code to inform the user that something went wrong.
                return
            }

            DispatchQueue.main.async { [weak self] in
                if #available(macOS 13, *) {
                    self?.webView.evaluateJavaScript("show('mac', \(state.isEnabled), true)")
                } else {
                    self?.webView.evaluateJavaScript("show('mac', \(state.isEnabled), false)")
                }
            }
        }
    }
    #endif

}
