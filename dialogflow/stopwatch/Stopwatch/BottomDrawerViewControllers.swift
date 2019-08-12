// Copyright 2018-present the Material Components for iOS authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import MaterialComponents.MaterialColorScheme
import MaterialComponents.MaterialNavigationDrawer

enum BetaFeatureMenu: Int {
  case sentimentAnalysis = 0, textToSpeech, knowledgeConnector
  func stringValue() -> String {
    switch self {
    case .sentimentAnalysis:
      return ApplicationConstants.sentimentAnalysis
    case .textToSpeech:
      return ApplicationConstants.textToSpeech
    case .knowledgeConnector:
      return ApplicationConstants.knowledgeConnector
    }
  }
}

class DrawerContentViewController: UITableViewController {
  var preferredHeight: CGFloat = 200
  var menuItems = [BetaFeatureMenu.sentimentAnalysis,  BetaFeatureMenu.textToSpeech,
                   BetaFeatureMenu.knowledgeConnector]

  override var preferredContentSize: CGSize {
    get {
      return CGSize(width: view.bounds.width, height: preferredHeight)
    }
    set {
      super.preferredContentSize = newValue
    }
  }

  init() {
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
  override func viewDidLoad() {
    super.viewDidLoad()
    self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: ApplicationConstants.tableViewCellID)
    tableView.separatorStyle = .none
    tableView.allowsMultipleSelection = true
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: ApplicationConstants.tableViewCellID, for: indexPath)
    cell.textLabel?.text = "\(menuItems[indexPath.item].stringValue())"
    cell.tintColor = ApplicationScheme.shared.colorScheme.primaryColor
    //cell.backgroundColor = colorScheme.surfaceColor
    print(cell.textLabel?.text ?? "")
    let defaults = UserDefaults.standard
    if let defaultItems = defaults.value(forKey: ApplicationConstants.selectedMenuItems) as? [Int],
      defaultItems.count > 0 {
      if defaultItems.contains(indexPath.row) {
        cell.accessoryView = UIImageView(image: #imageLiteral(resourceName: "ic_done"))
      } else {
        cell.accessoryView = nil
      }
    }

    return cell
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return menuItems.count
  }

  override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let cell = tableView.cellForRow(at: indexPath)
    tableView.deselectRow(at: indexPath, animated: true)
    let defaults = UserDefaults.standard
    var items = [Int]()
    if let defaultItems = defaults.value(forKey: ApplicationConstants.selectedMenuItems) as? [Int],
      defaultItems.count > 0 {
      items = defaultItems
    }
    if let index = items.firstIndex(of: indexPath.row) {
      if BetaFeatureMenu.knowledgeConnector.rawValue == items[indexPath.row] {
        //Remove knowledge connector path from user defaults
        UserDefaults.standard.removeObject(forKey: "knowledgeBasePath")
      }
      items.remove(at: index)
      cell?.accessoryView = nil

    } else {
      if BetaFeatureMenu.knowledgeConnector.rawValue == indexPath.row {
        //Call getKnowledge connector path api
        //save knowledge connector path in user defaults
        StopwatchService.sharedInstance.getKnowledgeBasePath { (knowledgeBasePath) in
          UserDefaults.standard.set(knowledgeBasePath, forKey: "knowledgeBasePath")
        }

      }
      items.append(indexPath.row)
      cell?.accessoryView = UIImageView(image: #imageLiteral(resourceName: "ic_done") )
    }
    defaults.set(items, forKey: ApplicationConstants.selectedMenuItems)
  }
}

class DrawerHeaderViewController: UIViewController,MDCBottomDrawerHeader {
  let preferredHeight: CGFloat = 80
  let titleLabel : UILabel = {
    let label = UILabel(frame: .zero)
    label.text = ApplicationConstants.menuDrawerTitle
    label.sizeToFit()
    return label
  }()
  
  override var preferredContentSize: CGSize {
    get {
      return CGSize(width: view.bounds.width, height: preferredHeight)
    }
    set {
      super.preferredContentSize = newValue
    }
  }
  
  init() {
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    view.addSubview(titleLabel)
  }
  
  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    titleLabel.center =
      CGPoint(x: self.view.frame.size.width / 2, y: self.preferredHeight - 20)
  }
  
}
