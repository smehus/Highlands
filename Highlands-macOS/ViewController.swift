//
//  ViewController.swift
//  Highlands-macOS
//
//  Created by Scott Mehus on 12/5/18.
//  Copyright © 2018 Scott Mehus. All rights reserved.
//

import Cocoa
import MetalKit

class ViewController: NSViewController {

    private var renderer: Renderer?

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let metalView = view as? MTKView else {
            fatalError()
        }

        renderer = Renderer(metalView: metalView)
    }
}

