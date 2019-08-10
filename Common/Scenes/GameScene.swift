//
//  GameScene.swift
//  Highlands
//
//  Created by Scott Mehus on 12/21/18.
//  Copyright © 2018 Scott Mehus. All rights reserved.
//

import Foundation
import MetalKit
import ModelIO

final class GameScene: Scene {

    let orthoCamera = OrthographicCamera()
    let ground = Prop(type: .base(name: "floor_grid", lighting: true))
    let plane = Prop(type: .base(name: "large-plane", lighting: true))
//    let skeleton = Character(name: "firstHuman_rigged_1_working_walk")
//    let skeleton = Character(name: "claire")
//    let skeleton = Character(name: "skeleton")
    let skeleton = Character(name: "boy_walking")
    let lantern = Prop(type: .base(name: "SA_LD_Medieval_Horn_Lantern", lighting: false))
    let water = Water(size: 100)

    override func setupScene() {

        skybox = Skybox(textureName: nil)

        inputController.keyboardDelegate = self

        lights = lighting()
        camera.position = [0, 2, -4]
        camera.rotation = [0, 0, 0]

        water.position.y = -1
        water.rotation = [0, 0, radians(fromDegrees: -90)]
        add(node: water)

        ground.tiling = 4
        ground.scale = [4, 1, 4]
        ground.position = float3(0, -0.03, 0)
        add(node: ground)



        let count = 10
        let offset = 10
        let tree = Prop(type: .instanced(name: "tree_tile", instanceCount: count))
        add(node: tree)
        physicsController.addStaticBody(node: tree)
        for i in 0..<count {
            var transform = Transform()
            transform.position = [Float(Int.random(in: -offset...offset)), 0, Float(Int.random(in: -offset...offset))]
            tree.updateBuffer(instance: i, transform: transform, textureID: 0)
        }

        let textureNames = ["rock1-color", "rock2-color", "rock3-color"]
        let morphTargetNames = ["rock1", "rock2", "rock3"]
        let rock = Prop(type: .morph(textures: textureNames, morphTargets: morphTargetNames, instanceCount: count))

        add(node: rock)
        physicsController.addStaticBody(node: rock)
        for i in 0..<count {
            var transform = Transform()

            if i == 0 {
                transform.position = [0, 0, 3]
            } else {
                transform.position = [Float(Int.random(in: -offset...offset)), 0, Float(Int.random(in: -offset...offset))]
            }

            rock.updateBuffer(instance: i, transform: transform, textureID: .random(in: 0..<textureNames.count))
        }



        skeleton.scale = [0.015, 0.015, 0.015]
        skeleton.rotation = [radians(fromDegrees: 90), 0, 0]
        skeleton.needsXRotationFix = true
        skeleton.boundingBox = MDLAxisAlignedBoundingBox(maxBounds: [0.4, 1.7, 0.4], minBounds: [-0.4, 0, -0.4])
        add(node: skeleton)
        skeleton.runAnimation(name: "Armature|mixamo.com|Layer0")
        self.physicsController.dynamicBody = skeleton
        self.inputController.player = skeleton
//        skeleton.currentAnimation?.speed = 2.0
        skeleton.pauseAnimation()

        lantern.position = [2.5, 3, 1.2]
        add(node: lantern)

        orthoCamera.position = [0, 2, 0]
        orthoCamera.rotation.x = .pi / 2
        cameras.append(orthoCamera)


        let tpCamera = ThirdPersonCamera(focus: skeleton)
        tpCamera.focusHeight = 6
        tpCamera.focusDistance = 4
        cameras.append(tpCamera)
        currentCameraIndex = 2
    }

    override func isHardCollision() -> Bool {
        return true
    }

    override func updateScene(deltaTime: Float) {
        for index in 0..<lights.count {
            guard lights[index].type == Spotlight || lights[index].type == Pointlight else { continue }
            let position = inputController.player!.position
            let forward = inputController.player!.forwardVector
            let rotation = inputController.player!.rotation


            // Lantern
            lights[index].position = position
            lights[index].position.y = 1.0
            lights[index].position += (forward * 4)


//            lights[index].position = camera.position

            // Spotlight
//            lights[index].position = float3(pos.x, pos.y + 3.0, pos.z)
////            lights[index].position += (inputController.player!.forwardVector * 1.2)
//            lights[index].coneDirection = float3(dir.x, radians(fromDegrees: -120), dir.z)



//            lights[index].position = float3(pos.x, pos.y + 0.3, pos.z)
//            lights[index].position += (inputController.player!.forwardVector.x)
//            lights[index].coneDirection = float3(dir.x, -1.0, dir.z)



            lantern.rotation = [0, -rotation.z, 0]
            lantern.position = position
            lantern.position.y += 2
            lantern.position += forward * 1.5
//            lantern.position.z -= 0.5
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
        case .key0: currentCameraIndex = 0
        case .key1: currentCameraIndex = 1
        case .key2: currentCameraIndex = 2
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
