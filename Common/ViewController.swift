//
//  ViewController.swift
//  Highlands
//
//  Created by Scott Mehus on 12/6/18.
//  Copyright © 2018 Scott Mehus. All rights reserved.
//

import MetalKit
class ViewController: LocalViewController {

    var renderer: Renderer?

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let metalView = view as? MTKView else {
            fatalError("metal view not set up in storyboard")
        }

        renderer = Renderer(metalView: metalView)
        let scene = GameScene(sceneSize: metalView.drawableSize)
        renderer?.scene = scene

        if let gameView = metalView as? GameView {
            gameView.inputController = scene.inputController
        }
    }
}
