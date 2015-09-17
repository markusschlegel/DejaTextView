//
//  ViewController.swift
//  DejaTextView
//
//  Created by Markus Schlegel on 17/09/15.
//  Copyright © 2015 Markus Schlegel. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var textView: DejaTextView!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.textView.textContainerInset = UIEdgeInsets(top: 42, left: 16, bottom: 42, right: 16)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

