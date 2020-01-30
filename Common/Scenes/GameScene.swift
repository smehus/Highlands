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
    let terrain = Terrain(textureName: "hills")
//    let ground = Prop(type: .base(name: "floor_grid", lighting: true))
//    let plane = Prop(type: .base(name: "large-plane", lighting: true))
    let skeleton = Character(name: "boy_tpose.usdz")
//    let lantern = Prop(type: .base(name: "SA_LD_Medieval_Horn_Lantern", lighting: false))
//    let lantern = CharacterTorch(type: .base(name: "Torch", lighting: true))
    let water = Water(size: 500)

    override func setupScene() {

        skybox = Skybox(textureName: nil)

        inputController.keyboardDelegate = self

        terrain.position = SIMD3<Float>([0, 0, 0])
//        terrain.rotation = float3(radians(fromDegrees: -20), 0, 0)
        add(node: terrain)


        lights = lighting()
        camera.position = [0, 0, -1.8]
        camera.rotation = [0, 0, 0]


        water.position.y = -7
        water.rotation = [0, 0, radians(fromDegrees: -90)]
        add(node: water)
  /*
        ground.tiling = 4
        ground.scale = [4, 1, 4]
        ground.position = float3(0, -0.03, 0)
        add(node: ground)
        */
        let count = 2
        let offset = 10

        let tree = Prop(type: .instanced(name: "treefir", instanceCount: count))
        add(node: tree)
        physicsController.addStaticBody(node: tree)
        for i in 0..<count {
            var transform = Transform()
            transform.scale = [3.0, 3.0, 3.0]

            var position: SIMD3<Float>
            repeat {
                position = [Float(Int.random(in: -offset...offset)), 0, Float(Int.random(in: -offset...offset))]
            } while position.x > 2 && position.z > 2

            transform.position = position
            tree.updateBuffer(instance: i, transform: transform, textureID: 0)
        }
//
//        let textureNames = ["rock1-color", "rock2-color", "rock3-color"]
//        let morphTargetNames = ["rock1", "rock2", "rock3"]
//        let rock = Prop(type: .morph(textures: textureNames, morphTargets: morphTargetNames, instanceCount: count))
//
//        add(node: rock)
//        physicsController.addStaticBody(node: rock)
//        for i in 0..<count {
//            var transform = Transform()
//
//            if i == 0 {
//                transform.position = [0, 0, 3]
//            } else {
//                var position: SIMD3<Float>
//                repeat {
//                    position = [Float(Int.random(in: -offset...offset)), 0, Float(Int.random(in: -offset...offset))]
//                } while position.x > 2 && position.z > 2
//
//                transform.position = position
//            }
//
//            rock.updateBuffer(instance: i, transform: transform, textureID: .random(in: 0..<textureNames.count))
//        }


        skeleton.scale = [0.015, 0.015, 0.015]
        skeleton.rotation = [radians(fromDegrees: 90), 0, radians(fromDegrees: 180)]
        skeleton.position = [0, 0, 0]
        skeleton.boundingBox = MDLAxisAlignedBoundingBox(maxBounds: [0.4, 1.7, 0.4], minBounds: [-0.4, 0, -0.4])
//        skeleton.currentAnimation.speed = 1.0
        add(node: skeleton)

        physicsController.dynamicBody = skeleton
        inputController.player = skeleton

//        lantern.position = CharacterTorch.localPosition
//        add(node: lantern, parent: skeleton)

        orthoCamera.position = [0, 2, 0]
        orthoCamera.rotation.x = .pi / 2
        cameras.append(orthoCamera)


        let tpCamera = ThirdPersonCamera(focus: skeleton)
        tpCamera.focusHeight = 6
        tpCamera.focusDistance = 4
        cameras.append(tpCamera)
        cameras.first?.position = [0, 4 , 3]
        currentCameraIndex = cameras.endIndex - 1


    }

    override func isHardCollision() -> Bool {
        return true
    }

    override func updateScene(deltaTime: Float) {
        for index in 0..<lights.count {
            /* TODO: - Uncomment these blocks
            guard lights[index].type == Spotlight || lights[index].type == Pointlight else { continue }
            let position = inputController.player!.position
            let forward = inputController.player!.forwardVector
            let rotation = inputController.player!.rotation


//            // Lantern
            lights[index].position = position
            lights[index].position.y = position.y + 4
            lights[index].position += (forward * 0.8)
            lights[index].position.x -= 0.2
 */


//
//
////            lights[index].position = camera.position
//
//            // Spotlight
////            lights[index].position = float3(pos.x, pos.y + 3.0, pos.z)
//////            lights[index].position += (inputController.player!.forwardVector * 1.2)
////            lights[index].coneDirection = float3(dir.x, radians(fromDegrees: -120), dir.z)
//
//
//
////            lights[index].position = float3(pos.x, pos.y + 0.3, pos.z)
////            lights[index].position += (inputController.player!.forwardVector.x)
////            lights[index].coneDirection = float3(dir.x, -1.0, dir.z)
//
//
//            if let hand = skeleton.nodes.compactMap({ self.find(name: "Boy:RightHand", in: $0) }).first {
//
//                var localTranslation = hand.globalTransform.columns.3.xyz
//
//                let x = skeleton.worldTransform.columns.3.x
//                let y = skeleton.worldTransform.columns.3.y
//                let z = skeleton.worldTransform.columns.3.z
//                let concatenatedPosition = float3(x + localTranslation.x, y + localTranslation.y, z + localTranslation.z)
//
//                print("*** hand translation \(concatenatedPosition)")
////                lantern.position.z = CharacterTorch.localPosition.z + (localTranslation.x * 0.7)
////                lantern.position.x = CharacterTorch.localPosition.x + (localTranslation.z * 0.2)
//                lantern.position.z = concatenatedPosition.x
//                lantern.position.x = concatenatedPosition.z
//            }
        }
    }

    // Trying to recursively find a bone
//    private func find(name: String, in node: CharacterNode) -> CharacterNode? {
//        guard node.name != name else { return node }
//
//        return node.children.compactMap ({ self.find(name: name, in: $0) }).first
//    }

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
//                skeleton.resumeAnimation()
            }

            if state == .ended, keysDown.isEmpty {
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
//        skeleton.resumeAnimation()
    }

    func didEndMove() {
//        skeleton.pauseAnimation()
    }
}

#endif
