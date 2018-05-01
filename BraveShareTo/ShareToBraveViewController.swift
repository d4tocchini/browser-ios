/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import Social
import MobileCoreServices

class ShareToBraveViewController: SLComposeServiceViewController {

    // TODO: Separate scheme for debug builds, so it can be tested without need to uninstall production app.
    private func urlScheme(for url: String) -> NSURL? {
        return NSURL(string: "brave://open-url?url=\(url)")
    }

    override func configurationItems() -> [Any]! {
        guard let inputItems = extensionContext?.inputItems as? [NSExtensionItem], let attachment = inputItems.first?.attachments?.first as? NSItemProvider else {
            return []
        }

        var itemProvider: NSItemProvider?
        // Look for the first URL the host application is sharing.
        // If there isn't a URL grab the first text item
        if attachment.isUrl || attachment.isText {
            itemProvider = attachment
        }

        guard let provider = itemProvider else {
            // If no item was processed. Cancel the share action to prevent the extension from locking the host application
            // due to the hidden ViewController.
            cancel()
            return []
        }

        provider.loadItem(of: provider.isUrl ? kUTTypeURL : kUTTypeText) { item, error in
            var urlItem: NSURL!

            // We can get urls from other apps as a kUTTypeText type, for example from Apple's mail.app.
            if let text = item as? String {
                urlItem = NSURL(string: text)
            } else if let url = item as? NSURL {
                urlItem = url
            } else {
                self.cancel()
                return
            }

            if let braveUrl = urlItem.encodedUrl.flatMap(self.urlScheme) {
                self.handleUrl(braveUrl)
            }
        }

        return []
    }

    private func handleUrl(_ url: NSURL) {
        // From http://stackoverflow.com/questions/24297273/openurl-not-work-in-action-extension
        var responder = self as UIResponder?
        while let strongResponder = responder {
            let selector = #selector(UIApplication.openURL(_:))
            if strongResponder.responds(to: selector) {
                strongResponder.callSelector(selector, object: url, delay: 0)
            }
            responder = strongResponder.next
        }

        DispatchQueue.main.asyncAfter(deadline: DispatchTime(uptimeNanoseconds: UInt64(0.1 * Double(NSEC_PER_SEC)))) {
            self.cancel()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        // Stop keyboard from showing
        textView.resignFirstResponder()
        textView.isEditable = false

        super.viewDidAppear(animated)
    }

    override func willMove(toParentViewController parent: UIViewController?) {
        view.alpha = 0
    }
}

extension NSItemProvider {
    var isText: Bool { return hasItemConformingToTypeIdentifier(String(kUTTypeText)) }
    var isUrl: Bool { return hasItemConformingToTypeIdentifier(String(kUTTypeURL)) }

    func loadItem(of type: CFString, completion: CompletionHandler?) {
        loadItem(forTypeIdentifier: String(type), options: nil, completionHandler: completion)
    }
}

extension NSURL {
    var encodedUrl: String? { return absoluteString?.addingPercentEncoding(withAllowedCharacters:NSCharacterSet.alphanumerics) }
}

extension NSObject {
    func callSelector(_ selector: Selector, object: AnyObject?, delay: TimeInterval) {
        let delay = delay * Double(NSEC_PER_SEC)
        let time = DispatchTime.now() + Double(Int64(delay)) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: time) {
            Thread.detachNewThreadSelector(selector, toTarget:self, with: object)
        }
    }
}
