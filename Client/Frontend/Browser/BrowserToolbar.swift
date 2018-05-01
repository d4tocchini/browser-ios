/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import UIKit
import SnapKit
import Shared
import XCGLogger

private let log = Logger.browserLogger

@objc
protocol BrowserToolbarProtocol {
    weak var browserToolbarDelegate: BrowserToolbarDelegate? { get set }
    var shareButton: UIButton { get }
    var pwdMgrButton: UIButton { get }
    var forwardButton: UIButton { get }
    var backButton: UIButton { get }
    var searchButton: UIButton { get }
    
    // While implementing protocol lazy var `self` is not usable to access instance variables, so this needs to be a function/calc var
    var actionButtons: [UIButton] { get }

    func updateBackStatus(_ canGoBack: Bool)
    func updateForwardStatus(_ canGoForward: Bool)
    func updateReloadStatus(_ isLoading: Bool)
    func updatePageStatus(_ isWebPage: Bool)
}

@objc
protocol BrowserToolbarDelegate: class {
    func browserToolbarDidPressBack(_ browserToolbar: BrowserToolbarProtocol, button: UIButton)
    func browserToolbarDidPressForward(_ browserToolbar: BrowserToolbarProtocol, button: UIButton)
    func browserToolbarDidPressBookmark(_ browserToolbar: BrowserToolbarProtocol, button: UIButton)
    func browserToolbarDidPressShare(_ browserToolbar: BrowserToolbarProtocol, button: UIButton)
    func browserToolbarDidPressPwdMgr(browserToolbar: BrowserToolbarProtocol, button: UIButton)
}

@objc
open class BrowserToolbarHelper: NSObject {
    let toolbar: BrowserToolbarProtocol

    var buttonTintColor = BraveUX.ActionButtonTintColor { // TODO see if setting it here can be avoided
        didSet {
            setTintColor(buttonTintColor, forButtons: toolbar.actionButtons)
        }
    }

    fileprivate func setTintColor(_ color: UIColor, forButtons buttons: [UIButton]) {
      buttons.forEach { $0.tintColor = color }
    }

    init(toolbar: BrowserToolbarProtocol) {
        self.toolbar = toolbar
        super.init()

        // TODO: All of this should be configured directly inside the browser toolbar
        
        toolbar.backButton.setImage(UIImage(named: "back"), for: .normal)
        toolbar.backButton.accessibilityLabel = Strings.Back
        toolbar.backButton.addTarget(self, action: #selector(BrowserToolbarHelper.SELdidClickBack), for: UIControlEvents.touchUpInside)

        toolbar.forwardButton.setImage(UIImage(named: "forward"), for: .normal)
        toolbar.forwardButton.accessibilityLabel = Strings.Forward
        toolbar.forwardButton.addTarget(self, action: #selector(BrowserToolbarHelper.SELdidClickForward), for: UIControlEvents.touchUpInside)

        toolbar.shareButton.setImage(UIImage(named: "send"), for: .normal)
        toolbar.shareButton.accessibilityLabel = Strings.Share
        toolbar.shareButton.addTarget(self, action: #selector(BrowserToolbarHelper.SELdidClickShare), for: UIControlEvents.touchUpInside)
        
        toolbar.searchButton.setImage(UIImage(named: "toolbar_search"), for: .normal)
        toolbar.searchButton.accessibilityLabel = Strings.Search
        toolbar.searchButton.addTarget(self, action: #selector(BrowserToolbarHelper.SELdidClickSearch), for: UIControlEvents.touchUpInside)

        toolbar.pwdMgrButton.setImage(UIImage(named: "passhelper_1pwd")?.withRenderingMode(.alwaysTemplate), for: .normal)
        toolbar.pwdMgrButton.isHidden = true
        toolbar.pwdMgrButton.tintColor = UIColor.white
        toolbar.pwdMgrButton.accessibilityLabel = Strings.PasswordManager
        toolbar.pwdMgrButton.addTarget(self, action: #selector(BrowserToolbarHelper.SELdidClickPwdMgr), for: UIControlEvents.touchUpInside)

        setTintColor(buttonTintColor, forButtons: toolbar.actionButtons)
        
        
    }

    func SELdidClickBack() {
        guard let bvc = getApp().browserViewController else { return }
        if bvc.urlBar.inSearchMode {
            bvc.urlBar.leaveSearchMode()
            return
        }
        toolbar.browserToolbarDelegate?.browserToolbarDidPressBack(toolbar, button: toolbar.backButton)
    }

    func SELdidClickShare() {
        toolbar.browserToolbarDelegate?.browserToolbarDidPressShare(toolbar, button: toolbar.shareButton)
    }

    func SELdidClickForward() {
        toolbar.browserToolbarDelegate?.browserToolbarDidPressForward(toolbar, button: toolbar.forwardButton)
    }
    
    func SELdidClickSearch() {
        let app = UIApplication.shared.delegate as! AppDelegate
        app.browserViewController.urlBar.browserLocationViewDidTapLocation(app.browserViewController.urlBar.locationView)
    }
    
    func SELdidClickPwdMgr() {
        toolbar.browserToolbarDelegate?.browserToolbarDidPressPwdMgr(browserToolbar: toolbar, button: toolbar.pwdMgrButton)
    }
}

class BrowserToolbar: Toolbar, BrowserToolbarProtocol {
    weak var browserToolbarDelegate: BrowserToolbarDelegate?

    let shareButton = UIButton()
    
    // Just used to conform to protocol, never used on this class, see BraveURLBarView for the one that is used on iPad
    let pwdMgrButton = UIButton()
    
    let forwardButton = UIButton()
    let backButton = UIButton()
    let searchButton = UIButton()
    
    var actionButtons: [UIButton] {
        return [self.shareButton, self.forwardButton, self.backButton, self.searchButton]
    }

    var stopReloadButton: UIButton {
        get {
            return getApp().browserViewController.urlBar.locationView.stopReloadButton
        }
    }

    var helper: BrowserToolbarHelper?

    static let Themes: [String: Theme] = {
        var themes = [String: Theme]()
        var theme = Theme()
        theme.buttonTintColor = BraveUX.ActionButtonPrivateTintColor
        themes[Theme.PrivateMode] = theme

        theme = Theme()
        theme.buttonTintColor = BraveUX.ActionButtonTintColor
        theme.backgroundColor = UIColor.clear
        themes[Theme.NormalMode] = theme

        return themes
    }()

    // This has to be here since init() calls it
    override init(frame: CGRect) {

        shareButton.accessibilityIdentifier = "BrowserToolbar.shareButton"

        super.init(frame: frame)

        self.helper = BrowserToolbarHelper(toolbar: self)
        self.backgroundColor = UIColor.clear

        addButtons(actionButtons)

        accessibilityNavigationStyle = .combined
        accessibilityLabel = Strings.Navigation_Toolbar
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateBackStatus(_ canGoBack: Bool) {
        backButton.isEnabled = canGoBack
    }

    func updateForwardStatus(_ canGoForward: Bool) {
        forwardButton.isEnabled = canGoForward
    }

    func updateReloadStatus(_ isLoading: Bool) {
        getApp().browserViewController.urlBar.locationView.stopReloadButtonIsLoading(isLoading)
    }

    func updatePageStatus(_ isWebPage: Bool) {
        stopReloadButton.isEnabled = isWebPage
        shareButton.isEnabled = isWebPage
    }
}

// MARK: UIAppearance
extension BrowserToolbar {
    dynamic var actionButtonTintColor: UIColor? {
        get { return helper?.buttonTintColor }
        set {
            guard let value = newValue else { return }
            helper?.buttonTintColor = value
        }
    }
}

extension BrowserToolbar: Themeable {
    func applyTheme(_ themeName: String) {
        guard let theme = BrowserToolbar.Themes[themeName] else {
            log.error("Unable to apply unknown theme \(themeName)")
            return
        }
        actionButtonTintColor = theme.buttonTintColor!
    }
}
