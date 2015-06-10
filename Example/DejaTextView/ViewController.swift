//
//  ViewController.swift
//  DejaTextView
//
//  Created by Markus Schlegel on 17/05/15.
//  Copyright (c) 2015 Markus Schlegel. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var textView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        textView.textContainerInset = UIEdgeInsetsMake(32.0, 12.0, 16.0, 12.0)
        textView.alwaysBounceVertical = true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}

