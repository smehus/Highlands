//
//  GameScene.swift
//  Highlands
//
//  Created by Scott Mehus on 12/21/18.
//  Copyright © 2018 Scott Mehus. All rights reserved.
//

import Foundation
import ModelIO

final class GameScene: Scene {

    let orthoCamera = OrthographicCamera()
    let ground = Prop(name: "large-plane", isGround: true)
//    let car = Prop(name: "racing-car")

//    let lantern = Prop(name: "SA_LD_Medieval_Horn_Lantern", isGround: false, lighting: false)
    var inCar = false

    override func setupScene() {

        inputController.keyboardDelegate = self

        lights = lighting()
        camera.position = [0, 1.2, -4]

        ground.tiling = 32
        add(node: ground)
//
//        for _ in 0..<50 {
//            let tree = Prop(name: "treefir")
//            tree.position = [Float(Int.random(in: -30...30)), 0, Float(Int.random(in: -30...30))]
//            add(node: tree)
//            physicsController.addStaticBody(node: tree)
//        }
//
//
//        car.rotation = [0, radians(fromDegrees: 90), 0]
//        car.position = [-2, 0, 0]
//        add(node: car)
//        physicsController.addStaticBody(node: car)
//
//        lantern.position = [2.5, 2.5, 1]
//        add(node: lantern, parent: skeleton, render: true)


//        DispatchQueue.global().async {

            let skeleton = Character(name: "claire_waking")

//            DispatchQueue.main.async {
                skeleton.scale = [0.02, 0.02, 0.02]
                //        skeleton.position = [1.2, 0, 100]
                        skeleton.rotation = [radians(fromDegrees: 90), 0, radians(fromDegrees: 180)]
                //        skeleton.boundingBox = MDLAxisAlignedBoundingBox(maxBounds: [0.4, 1.7, 0.4], minBounds: [-0.4, 0, -0.4])
                print("*** ADDING CLAIRE")
                self.add(node: skeleton)
                skeleton.runAnimation(name: "Armature|mixamo.com|Layer0")
                self.physicsController.dynamicBody = skeleton
                self.inputController.player = skeleton
//            }
//        }

//        skeleton.currentAnimation?.speed = 3.0
//        skeleton.pauseAnimation()






        orthoCamera.position = [0, 2, 0]
        orthoCamera.rotation.x = .pi / 2
        cameras.append(orthoCamera)

//
//        let tpCamera = ThirdPersonCamera(focus: skeleton)
//        tpCamera.focusHeight = 10
//        tpCamera.focusDistance = 5
//        cameras.append(tpCamera)
//        currentCameraIndex = 2
    }

    override func isHardCollision() -> Bool {
        return true
    }

    override func updateScene(deltaTime: Float) {
        for index in 0..<lights.count {
            guard lights[index].type == Spotlight || lights[index].type == Pointlight else { continue }
            let pos = inputController.player!.position
            let dir = inputController.player!.forwardVector


            lights[index].position = float3(pos.x, pos.y + 1, pos.z)
            lights[index].position += (inputController.player!.forwardVector * 1.2)
            lights[index].coneDirection = float3(dir.x, -0.5, dir.z)

        }
    }

    override func sceneSizeWillChange(to size: CGSize) {
        super.sceneSizeWillChange(to: size)

        let cameraSize: Float = 10
        let ratio = Float(sceneSize.width / sceneSize.height)

        let rect = Rectangle(left: -cameraSize * ratio,
                             right: cameraSize * ratio,
                             top: cameraSize,
                             bottom: -cameraSize)

        orthoCamera.rect = rect
    }
}

#if os(macOS)
extension GameScene: KeyboardDelegate {
    func keyPressed(key: KeyboardControl, state: InputState) -> Bool {
        switch key {
        case .c where state == .ended:
            let camera = cameras[0]

//            if inCar {
//                remove(node: car)
//                add(node: car)
//                car.position = camera.position + (camera.rightVector * 1.3)
//                car.position.y = 0
//                car.rotation = camera.rotation
//                inputController.translationSpeed = 2.0
//            } else {
//                remove(node: skeleton)
//                remove(node: car)
//                add(node: car, parent: camera)
//                car.position = [0.35, -1, 0.1]
//                car.rotation = [0, 0, 0]
//                inputController.translationSpeed = 10.0
//            }

            inCar = !inCar
            return false
        case .key0:
            currentCameraIndex = 0
        case .key1:
            currentCameraIndex = 1
        case .w, .s, .a, .d, .left, .right, .up, .down:
            if state == .began {
//                skeleton.resumeAnimation()
            }
            if state == .ended {
//                skeleton.pauseAnimation()
            }
        default:
            break
        }

        return true
    }
}

#endif

#if os(iOS)

extension GameScene: KeyboardDelegate {
    func didStartMove() {
        skeleton.resumeAnimation()
    }

    func didEndMove() {
        skeleton.pauseAnimation()
    }
}

#endif
