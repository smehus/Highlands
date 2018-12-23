//
//  GameScene.swift
//  Highlands
//
//  Created by Scott Mehus on 12/21/18.
//  Copyright © 2018 Scott Mehus. All rights reserved.
//

import Foundation

final class GameScene: Scene {


    let ground = Prop(name: "large-plane", isGround: true)
    let car = Prop(name: "racing-car")
    let skeleton = Character(name: "skeleton")
    let lantern = Prop(name: "SA_LD_Medieval_Horn_Lantern")

    override func setupScene() {

        lights = lighting()
        camera.position = [0, 1.2, -4]



        ground.tiling = 32
        add(node: ground)

        car.rotation = [0, radians(fromDegrees: 90), 0]
        car.position = [-0.8, 0, 0]
        add(node: car)

//        lantern.rotation = [0, radians(fromDegrees: 0), 0]
        lantern.position = [0, 1, 3]
        add(node: lantern, parent: nil, render: true)

//        skeleton.position = [-0.35, -0.2, -0.35]
//        add(node: skeleton, parent: car)
//        skeleton.runAnimation(name: "Armature_sit")
//        skeleton.pauseAnimation()

        inputController.player = camera
    }

    override func updateScene(deltaTime: Float) {

        guard let index = lights.lastIndex (where: { (light) -> Bool in
            return light.type == Spotlight
        }) else { return }


        let pos = inputController.player!.position
        let dir = inputController.player!.forwardVector
        lights[index].position = float3(pos.x, pos.y + 1, pos.z)
        lights[index].position += (inputController.player!.forwardVector * 1.2)
        lights[index].coneDirection = float3(dir.x, -0.5, dir.z)
    }
}
