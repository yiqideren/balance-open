//
//  SettingsViewController.swift
//  BalanceiOS
//
//  Created by Red Davis on 06/09/2017.
//  Copyright © 2017 Balanced Software, Inc. All rights reserved.
//

import LocalAuthentication
import UIKit


final class SettingsViewController: UIViewController
{
    // Fileprivate
    fileprivate var tableData = [TableSection]()
    
    // Private
    private let viewModel = AccountsTabViewModel()
    private let currencyViewModel = MainCurrencySelectionViewModel()
    
    private let tableView = UITableView(frame: CGRect.zero, style: .grouped)
    private let biometricLockEnabledSwitch = UISwitch()
    
    // MARK: Initialization
    
    required init()
    {
        super.init(nibName: nil, bundle: nil)
        self.title = "Settings"
        self.tabBarItem.image = UIImage(named: "Gear")
        
        // Notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.accountAddedNotification(_:)), name: Notifications.AccountAdded, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.accountRemovedNotification(_:)), name: Notifications.AccountRemoved, object: nil)
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        fatalError()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: View lifecycle
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.white
        
        // Navigation bar
        if #available(iOS 11.0, *) {
            self.navigationController?.navigationBar.prefersLargeTitles = true
        }
//        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Logout", style: .plain, target: self, action: #selector(self.logoutButtonTapped(_:)))
        
        // Table view
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.register(reusableCell: TableViewCell.self)
        self.tableView.register(reusableCell: SegmentedControlTableViewCell.self)
        self.view.addSubview(self.tableView)
        
        self.tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        // Biometric lock switch
        self.biometricLockEnabledSwitch.addTarget(self, action: #selector(self.biometricLockEnabledSwitchValueChanged(_:)), for: .valueChanged)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.reloadData()
        self.tableView.reloadData()
    }
    
    // MARK: Data
    
    private func reloadData() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(reloadDataDelayed), object: nil)
        self.perform(#selector(reloadDataDelayed), with: nil, afterDelay: 0.5)
    }
    
    @objc private func reloadDataDelayed()
    {
        self.viewModel.reloadData()
        
        // Table sections
        var tableSections = [TableSection]()
        
        // Biometrics
        let localAuthContext = LAContext()
        var localAuthError: NSError?
        localAuthContext.canEvaluatePolicy(LAPolicy.deviceOwnerAuthentication, error: &localAuthError)
        
        if localAuthError == nil {
            self.biometricLockEnabledSwitch.setOn(appLock.lockEnabled, animated: false)
            
            let biometricRow = TableRow { [weak self] (tableView, indexPath) -> UITableViewCell in
                let cell: TableViewCell = tableView.dequeueReusableCell(at: indexPath)
                cell.textLabel?.text = "Touch/Face ID"
                cell.accessoryView = self?.biometricLockEnabledSwitch
                cell.selectionStyle = .none
                return cell
            }
            
            let biometricSection = TableSection(title: "Security", rows: [biometricRow])
            tableSections.append(biometricSection)
        }
        
        // Main currency
        var mainCurrencyRow = TableRow { (tableView, indexPath) -> UITableViewCell in
            let cell: TableViewCell = tableView.dequeueReusableCell(at: indexPath)
            cell.textLabel?.text = self.currencyViewModel.currentCurrencyDisplay
            cell.accessoryType = .disclosureIndicator
            return cell
        }
        
        mainCurrencyRow.actionHandler = { [weak self] (indexPath) in
            self?.navigationController?.pushViewController(MainCurrencySelectionViewController(), animated: true)
        }
        
        let currencySection = TableSection(title: "Main Currency", rows: [mainCurrencyRow])
        tableSections.append(currencySection)
        
        // Insitutions
        var institutionRows = [TableRow]()
        let numberOfInstitutions = viewModel.numberOfSections()
        for index in 0 ..< numberOfInstitutions {
            guard let institution = viewModel.institution(forSection: index) else {
                continue
            }
            
            var row = TableRow(cellPreparationHandler: { (tableView, indexPath) -> UITableViewCell in
                let cell: TableViewCell = tableView.dequeueReusableCell(at: indexPath)
                cell.textLabel?.text = institution.displayName
                cell.accessoryType = .disclosureIndicator
                return cell
            })
            
            row.actionHandler = { [weak self] (indexPath) in
                self?.navigationController?.pushViewController(InstitutionSettingsViewController(institution: institution), animated: true)
            }
            
            row.deletionHandler = { [weak self] (indexPath) in
                self?.deleteAccount(at: indexPath)
            }
            
            institutionRows.append(row)
        }
        
        // Add account row
        var addAccountRow = TableRow(cellPreparationHandler: { (tableView, indexPath) -> UITableViewCell in
            let cell: TableViewCell = tableView.dequeueReusableCell(at: indexPath)
            cell.textLabel?.text = "Add Account"
            cell.accessoryType = .disclosureIndicator
            return cell
        })
        
        addAccountRow.actionHandler = { [weak self] (indexPath) in
            let navigationController = UINavigationController(rootViewController: AddAccountViewController())
            self?.present(navigationController, animated: true, completion: nil)
        }
        
        institutionRows.append(addAccountRow)
        
        // Accounts section
        let accountsSection = TableSection(title: "Accounts", rows: institutionRows)
        tableSections.append(accountsSection)
        
        // Help section
        var feedbackRow = TableRow { (tableView, indexPath) -> UITableViewCell in
            let cell: TableViewCell = tableView.dequeueReusableCell(at: indexPath)
            cell.textLabel?.text = "Send Feedback"
            cell.accessoryType = .disclosureIndicator
            return cell
        }
        
        feedbackRow.actionHandler = { [weak self] (indexPath) in
            self?.navigationController?.pushViewController(EmailIssueController(), animated: true)
        }
        
        let helpSection = TableSection(title: "Help", rows: [feedbackRow])
        tableSections.append(helpSection)
        
        self.tableData = tableSections
        self.tableView.reloadData()
    }
    
    // MARK: Actions

    @objc private func logoutButtonTapped(_ sender: Any) {
        // TODO: Logout
    }
    
    @objc private func biometricLockEnabledSwitchValueChanged(_ sender: Any) {
        appLock.lockEnabled = self.biometricLockEnabledSwitch.isOn
    }
    
    // MARK: Notifications
    
    @objc private func accountAddedNotification(_ notification: Notification) {
        self.reloadData()
        self.tableView.reloadData()
    }
    
    @objc private func accountRemovedNotification(_ notification: Notification) {
        self.reloadData()
        self.tableView.reloadData()
    }
    
    private func deleteAccount(at indexPath: IndexPath) {
        guard viewModel.removeInstitution(at: indexPath.row) else {
            log.error("Cant delete intitution for indexpath \(indexPath)")
            return
        }
        
        var sectionData = self.tableData[indexPath.section]
        sectionData.rows.remove(at: indexPath.row)
        tableData[indexPath.section] = sectionData
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }
}

// MARK: UITableViewDataSource

extension SettingsViewController: UITableViewDataSource
{
    func numberOfSections(in tableView: UITableView) -> Int
    {
        return self.tableData.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        let sectionData = self.tableData[section]
        return sectionData.rows.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let sectionData = self.tableData[indexPath.section]
        let rowData = sectionData.rows[indexPath.row]
        
        return rowData.cellPreparationHandler(tableView, indexPath)
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        let sectionData = self.tableData[section]
        return sectionData.title
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool
    {
        let sectionData = self.tableData[indexPath.section]
        let rowData = sectionData.rows[indexPath.row]
        
        return rowData.isDeletable
    }
}

// MARK: UITableViewDelegate

extension SettingsViewController: UITableViewDelegate
{
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return 44.0
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let sectionData = self.tableData[indexPath.section]
        let rowData = sectionData.rows[indexPath.row]
        rowData.actionHandler?(indexPath)
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath)
    {
        guard editingStyle == .delete else { return }
        
        let sectionData = self.tableData[indexPath.section]
        let rowData = sectionData.rows[indexPath.row]
        rowData.deletionHandler?(indexPath)
    }
}
