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
    var inCar = false

    override func setupScene() {

        inputController.keyboardDelegate = self

        lights = lighting()
        camera.position = [0, 1.2, -4]

        ground.tiling = 32
        add(node: ground)

        car.rotation = [0, radians(fromDegrees: 90), 0]
        car.position = [-0.8, 0, 0]
        add(node: car)

        lantern.position = [2.5, 1, 2]
        add(node: lantern, parent: camera, render: true)

        skeleton.position = [-0.35, -0.2, -0.35]
        add(node: skeleton, parent: car)
        skeleton.runAnimation(name: "Armature_sit")
        skeleton.pauseAnimation()

        inputController.player = camera
    }

    override func updateScene(deltaTime: Float) {
        for index in 0..<lights.count{
            let pos = inputController.player!.position
            let dir = inputController.player!.forwardVector


            lights[index].position = float3(pos.x, pos.y + 1, pos.z)
//            lights[index].position -= (inputController.player!.forwardVector * 1.2)
            lights[index].coneDirection = float3(dir.x, -0.5, dir.z)

        }
    }
}

extension GameScene: KeyboardDelegate {
    func keyPressed(key: KeyboardControl, state: InputState) -> Bool {
        switch key {
        case .c where state == .ended:
            let camera = cameras[0]

            if inCar {
                remove(node: car)
                add(node: car)
                car.position = camera.position + (camera.rightVector * 1.3)
                car.position.y = 0
                car.rotation = camera.rotation
                inputController.translationSpeed = 2.0
            } else {
                remove(node: skeleton)
                remove(node: car)
                add(node: car, parent: camera)
                car.position = [0.35, -1, 0.1]
                car.rotation = [0, 0, 0]
                inputController.translationSpeed = 10.0
            }

            inCar = !inCar
            return false
        default:
            break
        }

        return true
    }
}
