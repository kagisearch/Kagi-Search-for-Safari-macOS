//
//  SafariExtensionHandler.swift
//  Kagi Search Extension
//

import SafariServices
import os

class SafariExtensionHandler: SFSafariExtensionHandler {
    
    let debugLog = OSLog(subsystem: "com.kagimacOS.Kagi-Search.SafariExtensionHandler", category: "debug")
    
    struct SearchSource {
        let host: String
        let queryParameter: String
    }

    let sources = [
        SearchSource(host: "google.", queryParameter: "q"),
        SearchSource(host: "search.yahoo.com", queryParameter: "p"),
        SearchSource(host: "bing.", queryParameter: "q"),
        SearchSource(host: "bi.ng", queryParameter: "q"),
        SearchSource(host: "duckduckgo.com", queryParameter: "q"),
        SearchSource(host: "baidu.", queryParameter: "wd"),
        SearchSource(host: "yandex.", queryParameter: "text"),
        SearchSource(host: "ya.", queryParameter: "text"),
        SearchSource(host: "ecosia.org", queryParameter: "q"),
        SearchSource(host: "search.brave.com", queryParameter: "q"),
        SearchSource(host: "startpage.com", queryParameter: "query"),
        SearchSource(host: "neeva.com", queryParameter: "q"),
        SearchSource(host: "qwant.com", queryParameter: "q"),
    ]

    func kagiSearchURL(url: URL) -> URL? {
        if let host = url.host,
           let source = sources.first(where: { host.contains($0.host) }),
           let textQuery = URLComponents(string: url.absoluteString)?.percentEncodedQueryItems?.first(where: { $0.name == source.queryParameter })?.value,
           !self.shouldSkipRedirect(url: url) {
            return URL(string: "https://kagi.com/search?q=\(textQuery)")
        }
        return nil
    }
    
    // bangs handling
    func shouldSkipRedirect(url: URL) -> Bool {
        let host = url.host?.replacingOccurrences(of: "www.", with: "")
        
        func paramWithName(_ name: String) -> Any? {
            URLComponents(string: url.absoluteString)?.queryItems?.first(where: { $0.name == name })?.value
        }
        return [
            host?.contains("google.") == true && paramWithName("client") == nil,
            host?.contains("google.") == true && ((paramWithName("sxsrf") as? String)?.isEmpty == false || (paramWithName("source") as? String)?.isEmpty == false),
            host?.contains("google.") == true && paramWithName("client") as? String == "internal-element-cse",

            host?.contains("bing.") == true && paramWithName("form") == nil,
            host?.contains("bing.") == true && (((paramWithName("cvid") as? String)?.isEmpty == false) || ((paramWithName("sc") as? String)?.isEmpty == false) || ((paramWithName("qs") as? String)?.isEmpty == false)),
            
            host?.contains("duckduckgo.") == true && paramWithName("t") == nil,
            host?.contains("duckduckgo.") == true && ((paramWithName("t") == nil) || ((paramWithName("t") as? String) == "h_")),
            
            host?.contains("search.yahoo.") == true && paramWithName("fr") == nil,
            host?.contains("search.yahoo.") == true && (paramWithName("fp") as? String == "1"),
        ].contains(true)
    }
    
    override func page(_ page: SFSafariPage, willNavigateTo url: URL?) {
        if let url = url,
           url.host?.hasPrefix("kagi") == true {
            os_log("<< skipping redirect checks for a kagi.com url", log: debugLog, type: .debug)
        }
        let isExtensionEnabled = UserDefaults.standard.bool(forKey: SafariExtensionViewController.enableExtensionKey)
        os_log(">> willNavigateTo: %@", log: debugLog, type: .debug, String(describing: url))
        os_log(isExtensionEnabled ? ">> Extension enabled" : ">> Extension disabled", log: debugLog, type: .debug)
        os_log(url != nil ? ">> url exists" : ">> url is nil", log: debugLog, type: .debug)
        var kagiSearchURL: URL? = nil
        if (url != nil) {
            kagiSearchURL = self.kagiSearchURL(url: url!)
            os_log(">> kagiSearchURL requested. Result: %@", log: debugLog, type: .debug, String(describing: kagiSearchURL))
        }
        os_log(kagiSearchURL != nil ? ">> attempting redirect" : ">> will not attempt redirect")
        guard isExtensionEnabled,
              let kagiSearchURL = kagiSearchURL else {
            os_log(">>>> Officially **Not** redirecting to Kagi", log: debugLog, type: .debug)
            return
        }
        os_log(">>>> requesting tabs for page: %@", log: debugLog, type: .debug, String(describing: page))
        let timer = Timer(timeInterval: 1, repeats: false) { [weak page] thetimer in
            if page != nil {
                os_log("<<<< no tab returned for page: %@", log: self.debugLog, type: .debug, String(describing: page))
            } else {
                os_log("<<<< no tab returned for page: nil", log: self.debugLog, type: .debug)
            }
        }
        page.getContainingTab { tab in
            if tab != nil {
                os_log(">>>> found tab: %@", log: self.debugLog, type: .debug, String(describing: tab))
            } else {
                os_log(">>>> found nil tab", log: self.debugLog, type: .debug)
            }
            timer.invalidate()
            tab.navigate(to: kagiSearchURL)
        }
    }
    
    // only called for domains specified in Info.plist
    override func additionalRequestHeaders(for url: URL, completionHandler: @escaping ([String : String]?) -> Void) {
        func privateSessionToken() -> String? {
            if let privateSessionLink = UserDefaults.standard.string(forKey: SafariExtensionViewController.sessionLinkKey),
               let url = URL(string: privateSessionLink.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!),
               let token = URLComponents(string: url.absoluteString)?.queryItems?.first(where: { $0.name == "token" })?.value {
                return token
            }
            return nil
        }
        
        if let token = privateSessionToken() {
            completionHandler(["Authorization": token])
        }
    }
    
    override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping ((Bool, String) -> Void)) {
        validationHandler(true, "")
    }
    
    override func popoverViewController() -> SFSafariExtensionViewController {
        return SafariExtensionViewController.shared
    }
}
