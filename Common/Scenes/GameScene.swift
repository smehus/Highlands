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
    let ground = Prop(type: .base(name: "large-plane", lighting: true))
    let plane = Prop(type: .base(name: "large-plane", lighting: true))
    let skeleton = Character(name: "firstHuman_rigged_1_working_walk")
//    let car = Prop(name: "racing-car")
    let lantern = Prop(type: .base(name: "SA_LD_Medieval_Horn_Lantern", lighting: false))

    override func setupScene() {

        skybox = Skybox(textureName: nil)

        inputController.keyboardDelegate = self

        lights = lighting()
        camera.position = [0, 2, -4]
        camera.rotation = [0, 0, 0]

        ground.tiling = 16
        add(node: ground)

//        plane.position.z = 10
//        plane.rotation.x = radians(fromDegrees: 130)
//        plane.tiling = 1
//        add(node: plane)


        let singleTree = Prop(type: .base(name: "treefir", lighting: true))
        singleTree.position = [-2, 0, 0]
        add(node: singleTree)


//        let tree2 = Prop(type: .base(name: "treefir", lighting: true))
//        tree2.position = [2, 0, 0]
//        add(node: tree2)

//        let tree = Prop(type: .instanced(name: "treefir", instanceCount: 50))
//        add(node: tree)
////         TODO: Figure out a way to handle physics with instancing
////        physicsController.addStaticBody(node: tree)
//        for i in 0..<50 {
//            var transform = Transform()
//            transform.position = [Float(Int.random(in: -30...30)), 0, Float(Int.random(in: -30...30))]
//            tree.updateBuffer(instance: i, transform: transform, textureID: 0)
//        }
////
//        let textureNames = ["rock1-color", "rock2-color", "rock3-color"]
//        let morphTargetNames = ["rock1", "rock2", "rock3"]
//        let rock = Prop(type: .morph(textures: textureNames, morphTargets: morphTargetNames, instanceCount: 20))
//        add(node: rock)
//        for i in 0..<20 {
//            var transform = Transform()
//
//            if i == 0 {
//                transform.position = [0, 0, 3]
//            } else {
//                transform.position = [Float(Int.random(in: -10...10)), 0, Float(Int.random(in: -10...10))]
//            }
//
//            transform.scale = [0.5, 0.5, 0.5]
//            rock.updateBuffer(instance: i, transform: transform, textureID: .random(in: 0..<textureNames.count))
//        }


//        car.rotation = [0, radians(fromDegrees: 90), 0]
//        car.position = [-2, 0, 0]
//        add(node: car)
//        physicsController.addStaticBody(node: car)

//        lantern.position = [2.5, 3, 1]
//        add(node: lantern, parent: skeleton, render: true)

        skeleton.scale = [0.3, 0.3, 0.3]
//        skeleton.position.y -= 5
//        skeleton.rotation = [radians(fromDegrees: 90), 0, 0]
//        skeleton.boundingBox = MDLAxisAlignedBoundingBox(maxBounds: [0.4, 1.7, 0.4], minBounds: [-0.4, 0, -0.4])
        self.add(node: skeleton)
        skeleton.runAnimation(name: "walking")
        self.physicsController.dynamicBody = skeleton
        self.inputController.player = skeleton
//        skeleton.currentAnimation?.speed = 3.0
        skeleton.pauseAnimation()



        orthoCamera.position = [0, 2, 0]
        orthoCamera.rotation.x = .pi / 2
        cameras.append(orthoCamera)


        let tpCamera = ThirdPersonCamera(focus: skeleton)
        tpCamera.focusHeight = 1
        tpCamera.focusDistance = 2
        cameras.append(tpCamera)
        currentCameraIndex = 2
    }

    override func isHardCollision() -> Bool {
        return true
    }

    override func updateScene(deltaTime: Float) {
        for index in 0..<lights.count {
            guard lights[index].type == Spotlight || lights[index].type == Pointlight else { continue }
            let pos = inputController.player!.position
            let dir = inputController.player!.forwardVector


            // Lantern
            lights[index].position = inputController.player!.position
            lights[index].position.y = 1.0
            lights[index].position += inputController.player!.forwardVector / 4

            // Spotlight
//            lights[index].position = float3(pos.x, pos.y + 3.0, pos.z)
////            lights[index].position += (inputController.player!.forwardVector * 1.2)
//            lights[index].coneDirection = float3(dir.x, radians(fromDegrees: -120), dir.z)



//            lights[index].position = float3(pos.x, pos.y + 0.3, pos.z)
//            lights[index].position += (inputController.player!.forwardVector.x)
//            lights[index].coneDirection = float3(dir.x, -1.0, dir.z)
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
    func keyPressed(key: KeyboardControl, keysDown: Set<KeyboardControl>, state: InputState) -> Bool {
        switch key {
        case .key0:
            currentCameraIndex = 0
        case .key1:
            currentCameraIndex = 1
        case .w, .s, .a, .d, .left, .right, .up, .down:
            if state == .began {
                skeleton.resumeAnimation()
            }

            if state == .ended, keysDown.isEmpty {
                skeleton.pauseAnimation()
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
