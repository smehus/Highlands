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

        lights = lighting()
        camera.position = [0, 1.2, -4]

        ground.tiling = 32
        add(node: ground)

        car.rotation = [0, radians(fromDegrees: 90), 0]
        car.position = [-0.8, 0, 0]
        add(node: car)

//        skeleton.position = [-0.35, -0.2, -0.35]
//        add(node: skeleton, parent: car)
//        skeleton.runAnimation(name: "Armature_sit")
//        skeleton.pauseAnimation()

        inputController.player = camera
    }

    override func updateScene(deltaTime: Float) {
        let pos = inputController.player!.position
        let dir = inputController.player!.forwardVector
        lights[0].position = float3(pos.x, pos.y + 1, pos.z)
        lights[0].position += (inputController.player!.forwardVector * 2)
        lights[0].coneDirection = float3(dir.x, -1, dir.z)
    }
}
