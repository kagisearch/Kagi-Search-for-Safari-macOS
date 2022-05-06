//
//  SafariExtensionHandler.swift
//  Kagi Search Extension
//

import SafariServices

class SafariExtensionHandler: SFSafariExtensionHandler {
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
           let textQuery = URLComponents(string: url.absoluteString)?.queryItems?.first(where: { $0.name == source.queryParameter })?.value {
            return URL(string: "https://kagi.com/search?q=\(textQuery)")
        }
        return nil
    }
    
    override func page(_ page: SFSafariPage, willNavigateTo url: URL?) {
        guard let url = url,
              let kagiSearchURL = kagiSearchURL(url: url) else {
            return
        }
        page.getContainingTab { tab in
            tab.navigate(to: kagiSearchURL)
        }
    }
    
    // only called for domains specified in Info.plist
    override func additionalRequestHeaders(for url: URL, completionHandler: @escaping ([String : String]?) -> Void) {
        func privateSessionToken() -> String? {
            if let privateSessionLink = UserDefaults.standard.string(forKey: SafariExtensionViewController.key),
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
