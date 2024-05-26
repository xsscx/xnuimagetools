/**
 *  @file ViewController.swift
 *  @brief XNU Image Generator for iOS
 *  @date 21 MAY 2024
 *  @version 1.7.0
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 *  @section CHANGES
 *  - 21/05/2024: Initial commit.
 *
 */

import UIKit

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        
        // Add any additional setup you need here
        let label = UILabel()
        label.text = "Hello, World!"
        label.textAlignment = .center
        label.frame = view.bounds
        view.addSubview(label)
    }
}
