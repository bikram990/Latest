//
//  MainWindowController.swift
//  Latest
//
//  Created by Max Langer on 27.02.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa

/**
 This class controls the main window of the app. It includes the list of apps that have an update available as well as the release notes for the specific update.
 */
class MainWindowController: NSWindowController, NSMenuItemValidation, NSMenuDelegate, UpdateListViewControllerDelegate, UpdateCheckerProgress {
    
    private let ShowInstalledUpdatesKey = "ShowInstalledUpdatesKey"
    
    /// The list view holding the apps
    lazy var listViewController : UpdateTableViewController = {
        guard let splitViewController = self.contentViewController as? NSSplitViewController,
            let firstItem = splitViewController.splitViewItems[0].viewController as? UpdateTableViewController else {
                return UpdateTableViewController()
        }
        
        return firstItem
    }()
    
    /// The detail view controller holding the release notes
    lazy var releaseNotesViewController : ReleaseNotesViewController = {
        guard let splitViewController = self.contentViewController as? NSSplitViewController,
            let secondItem = splitViewController.splitViewItems[1].viewController as? ReleaseNotesViewController else {
                return ReleaseNotesViewController()
        }
        
        return secondItem
    }()
    
    /// The progress indicator showing how many apps have been checked for updates
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    
    /// The button that triggers an reload/recheck for updates
    @IBOutlet weak var reloadButton: NSButton!
    @IBOutlet weak var reloadTouchBarButton: NSButton!
    
    /// The button thats action opens all apps (or Mac App Store) to begin the update process
    @IBOutlet weak var openAllAppsButton: NSButton!
    @IBOutlet weak var openAllAppsTouchBarButton: NSButton!
    
    override func windowDidLoad() {
        super.windowDidLoad()
    
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        
        self.window?.titlebarAppearsTransparent = true
        self.window?.titleVisibility = .hidden
        
        if let splitViewController = self.contentViewController as? NSSplitViewController {
            splitViewController.splitViewItems[1].isCollapsed = true
        }
        
        self.window?.makeFirstResponder(self.listViewController)
        
        self.listViewController.updateChecker.progressDelegate = self
        self.listViewController.delegate = self
        self.listViewController.checkForUpdates()
        self.listViewController.releaseNotesViewController = self.releaseNotesViewController
        
        self.updateShowInstalledUpdatesState(with: UserDefaults.standard.bool(forKey: ShowInstalledUpdatesKey))
    }

    
    // MARK: - Action Methods
    
    /// Reloads the list / checks for updates
    @IBAction func reload(_ sender: Any?) {
        self.listViewController.checkForUpdates()
    }
    
    /// Open all apps that have an update available. If apps from the Mac App Store are there as well, open the Mac App Store
    @IBAction func openAll(_ sender: Any?) {
        let apps = self.listViewController.apps
        
        if apps.countOfAvailableUpdates > 4 {
            // Display warning
            let alert = NSAlert()
            alert.alertStyle = .warning
            
            alert.messageText = String.init(format: NSLocalizedString("You are going to open %d apps.", comment: "Open a lot of apps - informative text"), apps.count)
            
            alert.informativeText = NSLocalizedString("This may slow down your Mac. Are you sure you want to open all apps at once?", comment: "Open a lot of apps - message text")
            
            alert.addButton(withTitle: NSLocalizedString("Open Apps", comment: "Open all apps button"))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Cancel button"))
            
            alert.beginSheetModal(for: self.window!, completionHandler: { (response) in
                if response.rawValue == 1000 {
                    // Open apps anyway
                    self.open(apps)
                }
            })
        } else {
            self.open(apps)
        }
    }
    
    /// Shows/hides the detailView which presents the release notes
    @IBAction func toggleDetail(_ sender: Any?) {
        guard let splitViewController = self.contentViewController as? NSSplitViewController else {
            return
        }
        
        let detailItem = splitViewController.splitViewItems[1]
        
        detailItem.animator().isCollapsed = !detailItem.isCollapsed
    }
    
    @IBAction func toggleShowInstalledUpdates(_ sender: NSMenuItem?) {
        self.updateShowInstalledUpdatesState(with: !UserDefaults.standard.bool(forKey: ShowInstalledUpdatesKey), from: sender)
    }
    
    
    // MARK: Menu Item Validation

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let action = menuItem.action else {
            return true
        }
        
        switch action {
        case #selector(openAll(_:)):
            return self.listViewController.apps.count != 0
        case #selector(reload(_:)):
            return self.reloadButton.isEnabled
        case #selector(toggleShowInstalledUpdates(_:)):
            menuItem.state = self.listViewController.showInstalledUpdates ? .on : .off
            return true
        case #selector(toggleDetail(_:)):
            guard let splitViewController = self.contentViewController as? NSSplitViewController else {
                return false
            }
            
            let detailItem = splitViewController.splitViewItems[1]
            
            menuItem.title = detailItem.isCollapsed ?
                NSLocalizedString("Show Version Details", comment: "MenuItem Show Version Details") :
                NSLocalizedString("Hide Version Details", comment: "MenuItem Hide Version Details")
            
            return self.listViewController.tableView.selectedRow != -1
        default:
            return true
        }
    }
    
    
    // MARK: - Update Checker Progress Delegate
    
    /// This implementation activates the progress indicator, sets its max value and disables the reload button
    func startChecking(numberOfApps: Int) {
        self.reloadButton.isEnabled = false
        self.reloadTouchBarButton.isEnabled = false
    
        self.progressIndicator.doubleValue = 0
        self.progressIndicator.isHidden = false
        self.progressIndicator.maxValue = Double(numberOfApps - 1)
    }
    
    /// Update the progress indicator
    func didCheckApp() {
        self.openAllAppsButton.isEnabled = self.listViewController.apps.countOfAvailableUpdates != 0
        self.openAllAppsTouchBarButton.isEnabled = self.openAllAppsButton.isEnabled
        
        if self.progressIndicator.doubleValue == self.progressIndicator.maxValue {
            self.reloadButton.isEnabled = true
            self.reloadTouchBarButton.isEnabled = true
            self.progressIndicator.isHidden = true
            self.listViewController.finishedCheckingForUpdates()
        } else {
            self.progressIndicator.increment(by: 1)
        }
    }
    
    
    // MARK: - Update List View Controller Delegate

    /// Expands the detail view of the main window
    func shouldExpandDetail() {
        guard let splitViewController = self.contentViewController as? NSSplitViewController else {
            return
        }
        
        let detailItem = splitViewController.splitViewItems[1]
        
        detailItem.animator().isCollapsed = false
    }
    
    /// Collapses the detail view of the main window
    func shouldCollapseDetail() {
        guard let splitViewController = self.contentViewController as? NSSplitViewController else {
            return
        }
        
        let detailItem = splitViewController.splitViewItems[1]
        
        detailItem.animator().isCollapsed = true
    }
    
    
    // MARK: - Private Methods
    
    /**
     Open all apps in the array
     - parameter apps: The apps to be opened
     */
    
    private func open(_ apps: AppCollection) {
        var showedMacAppStore = false
        
        apps.forEach { (app) in
            if !app.updateAvailable { return }
            if !showedMacAppStore, app is MacAppStoreAppBundle {
                showedMacAppStore = true
                NSWorkspace.shared.open(URL(string: "macappstore://showUpdatesPage")!)
                return
            }
            
            NSWorkspace.shared.open(app.url)
        }
    }
    
    private func updateShowInstalledUpdatesState(with newState: Bool, from sender: NSMenuItem? = nil) {
        self.listViewController.showInstalledUpdates = newState
    
        if let sender = sender {
            sender.state = newState ? .on : .off
        }
        
        UserDefaults.standard.set(newState, forKey: ShowInstalledUpdatesKey)
    }
    
}
