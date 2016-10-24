//
//  ViewController.swift
//  Padaco launcher
//
//  Created by (unknown) on 8/18/16.
//  Copyright (c) 2016 Informaton. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    @IBOutlet var splashImage =  NSImage(named:"splash_wide.png")
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
    }

    // occrus after viewDidLoad
    override func viewDidAppear() {
        super.viewDidAppear()
        
        
        self.view.window!.title = "Padaco"
        self.view.window!.center();
        

        self.view.window!.backgroundColor = NSColor.whiteColor()
        self.view.window!.titleVisibility = NSWindowTitleVisibility.Hidden;
      //  self.view.window!.titlebarAppearsTransparent = true;
        
//        self.view.window!.styleMask |= NSFullSizeContentViewWindowMask;
        
    }
    
    
    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

