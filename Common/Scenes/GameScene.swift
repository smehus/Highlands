//
//  GameScene.swift
//  Highlands
//
//  Created by Scott Mehus on 12/21/18.
//  Copyright © 2018 Scott Mehus. All rights reserved.
//

import Foundation

final class GameScene: Scene {

    let ground = Prop(name: "large-plane")
    let car = Prop(name: "racing-car")
    let skeleton = Character(name: "skeleton")

    override func setupScene() {
        
        ground.tiling = 32
        add(node: ground)
        car.rotation = [0, radians(fromDegrees: 90), 0]
        car.position = [-0.8, 0, 0]
        add(node: car)
        skeleton.position = [1.6, 0, 0]
        skeleton.rotation.y = .pi
        add(node: skeleton)
        skeleton.runAnimation(name: "Armature_idle")
        skeleton.pauseAnimation()
        camera.position = [0, 1.2, -4]
    }
}
