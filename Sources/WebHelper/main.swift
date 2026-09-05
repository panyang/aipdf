import Foundation
import AppKit
import WebKit

final class WebRenderer: NSObject, WKNavigationDelegate {
    let view = WKWebView(frame: NSRect(x: 0,y: 0,width: 794,height: 1123), configuration: {
        let c=WKWebViewConfiguration()
        c.websiteDataStore = .nonPersistent()
        return c
    }())
    let output: URL
    init(output: URL) { self.output=output; super.init(); view.navigationDelegate=self }
    func finish(_ success: Bool) { exit(success ? 0 : 1) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(false) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(false) }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline:.now()+1) {
            webView.evaluateJavaScript("Math.max(document.body.scrollHeight, document.documentElement.scrollHeight)") { value,error in
                let height=min(200000,max(1123,(value as? Double) ?? 1123))
                let configuration=WKPDFConfiguration()
                configuration.rect=CGRect(x:0,y:0,width:794,height:height)
                webView.createPDF(configuration:configuration) { result in
                    switch result {
                    case .success(let data):
                        do { try data.write(to:self.output,options:.atomic); self.finish(true) } catch { self.finish(false) }
                    case .failure: self.finish(false)
                    }
                }
            }
        }
    }
}

guard CommandLine.arguments.count==3, let source=URL(string:CommandLine.arguments[1]), ["https","http"].contains(source.scheme ?? "") else { exit(1) }
let app=NSApplication.shared
app.setActivationPolicy(.prohibited)
let renderer=WebRenderer(output:URL(fileURLWithPath:CommandLine.arguments[2]))
renderer.view.load(URLRequest(url:source,timeoutInterval:45))
DispatchQueue.main.asyncAfter(deadline:.now()+60) { exit(1) }
withExtendedLifetime(renderer) { app.run() }
