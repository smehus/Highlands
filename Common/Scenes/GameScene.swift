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
//    let terrain = Terrain(textureName: "hills")
//    let ground = Prop(type: .base(name: "floor_grid", lighting: true))
//    let plane = Prop(type: .base(name: "large-plane", lighting: true))
    let skeleton = Character(name: "walking_boy")
//    let lantern = Prop(type: .base(name: "SA_LD_Medieval_Horn_Lantern", lighting: false))
//    let lantern = CharacterTorch(type: .base(name: "Torch", lighting: true))
    let water = Water(size: 500)

    private var updateTerrain = true
    private var instanceParamBuffer: MTLBuffer!
    private let shadowRenderPassDescriptor = MTLRenderPassDescriptor()
    private var shadowDepthTexture: MTLTexture!
    private var shadowColorTexture: MTLTexture!
    private var secondTile = TileScene()

    override func setupScene() {

        instanceParamBuffer = Renderer.device
            .makeBuffer(length: MemoryLayout<InstanceParams>.stride * Renderer.InstanceParamsBufferCapacity, options: .storageModeShared)!

        skybox = Skybox(textureName: nil)

        inputController.keyboardDelegate = self

        lights = lighting()
        camera.position = [0, 0, -1.8]
        camera.rotation = [0, 0, 0]


        // Add tiles here

        let tile = TileScene()
        tile.position = [0, 0, 0]
        tile.name = "Tile 1"
        tile.setupTile()
        add(node: tile)

        secondTile.name = "Tile 2"
        secondTile.position = [0, 0, -50]
        secondTile.setupTile()
        add(node: secondTile)


        skeleton.scale = [0.015, 0.015, 0.015]
        skeleton.rotation = [radians(fromDegrees: 90), 0, radians(fromDegrees: 180)]
        skeleton.position = [0, 0, 0]
        skeleton.boundingBox = MDLAxisAlignedBoundingBox(maxBounds: [0.4, 1.7, 0.4], minBounds: [-0.4, 0, -0.4])
//        skeleton.currentAnimation.speed = 1.0
        add(node: skeleton)
//
        physicsController.dynamicBody = skeleton
        inputController.player = skeleton

//        lantern.position = CharacterTorch.localPosition
//        add(node: lantern, parent: skeleton)

        orthoCamera.position = [0, 2, 0]
        orthoCamera.rotation.x = .pi / 2
        cameras.append(orthoCamera)


        let tpCamera = ThirdPersonCamera(focus: skeleton)
        tpCamera.focusHeight = 10
        tpCamera.focusDistance = 6
        cameras.append(tpCamera)
        cameras.first?.position = [0, 4 , 3]
        currentCameraIndex = cameras.endIndex - 1



        super.setupScene()

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


//            // Lantern
            lights[index].position = position
            lights[index].position.y = position.y + 4
            lights[index].position += (forward * 0.8)
            lights[index].position.x -= 0.2


            if secondTile.position.y > -100 {
//                secondTile.position.y -= 0.05
            }

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

        buildShadowTexture(size: size)
    }


    func buildShadowTexture(size: CGSize) {
        //        shadowTexture = buildTexture(pixelFormat: .depth32Float, size: size, label: "Shadow")
        //        shadowRenderPassDescriptor.setUpDepthAttachment(texture: shadowTexture)

        // Pointlights
        shadowDepthTexture = buildCubeTexture(pixelFormat: .depth32Float, size: Int(size.width))
        shadowColorTexture = buildCubeTexture(pixelFormat: .bgra8Unorm_srgb, size: Int(size.width))
        shadowRenderPassDescriptor.setUpCubeDepthAttachment(depthTexture: shadowDepthTexture, colorTexture: shadowColorTexture)
    }

    func buildCubeTexture(pixelFormat: MTLPixelFormat, size: Int) -> MTLTexture {
        let descriptor = MTLTextureDescriptor
            .textureCubeDescriptor(pixelFormat: pixelFormat,
                                   size: size,
                                   mipmapped: false)

        descriptor.usage = [.shaderRead, .renderTarget]
        descriptor.storageMode = .private

        guard let texture = Renderer.device.makeTexture(descriptor: descriptor) else {
            fatalError()
        }

        texture.label = "CUBE POINTLIGHT TEXTURE"
        return texture
    }


    override func render(view: MTKView, descriptor: MTLRenderPassDescriptor, commandBuffer: MTLCommandBuffer) {

        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { fatalError("Failed to make compute encoder") }
        computeEncoder.pushDebugGroup("Tessellation Pass")

        // compute each terrain
        for renderable in renderables {
            renderable.generateTerrain(computeEncoder: computeEncoder, uniforms: uniforms)
        }

        computeEncoder.popDebugGroup()
        computeEncoder.endEncoding()


        guard let computeNormalEncoder = commandBuffer.makeComputeCommandEncoder() else { fatalError() }
        computeNormalEncoder.pushDebugGroup("Terrain Normal Compute")

        for renderable in renderables {
            renderable.generateTerrainNormalMap(computeEncoder: computeNormalEncoder)
        }

        computeNormalEncoder.popDebugGroup()
        computeNormalEncoder.endEncoding()

//        // general terrain normal map
//        Terrain.generateTerrainNormalMap(heightMap: terrain.heightMap, normalTexture: terrain.normalMapTexture, commandBuffer: commandBuffer)


        // Calculate Height

        guard let heightEncoder = commandBuffer.makeComputeCommandEncoder() else { fatalError() }
        heightEncoder.pushDebugGroup("Height pass")
        for renderable in renderables {
            renderable.calculateHeight(computeEncoder: heightEncoder, terrainParams: Terrain.terrainParams, uniforms: uniforms)

            // Need to test if character is inside this tile or not
            if let tile = renderable as? TileScene {
                let bottomLeft: SIMD3<Float> = [tile.position.x - (Terrain.terrainParams.size.x / 2), 0, tile.position.z - (Terrain.terrainParams.size.y / 2)]
                let topRight: SIMD3<Float> = [tile.position.x + (Terrain.terrainParams.size.x / 2), 0, tile.position.z + (Terrain.terrainParams.size.y / 2)]

                let horizontal = skeleton.position.x > bottomLeft.x && skeleton.position.x < topRight.x
                let vertical = skeleton.position.z > bottomLeft.z && skeleton.position.z < topRight.z

                if horizontal && vertical {
                    skeleton.currentTile = tile
                    skeleton.calculateHeight(computeEncoder: heightEncoder, heightMapTexture: tile.terrain.heightMap, terrainParams: Terrain.terrainParams, uniforms: uniforms, controlPointsBuffer: tile.terrain.controlPointsBuffer)
                }
            }
        }
        heightEncoder.popDebugGroup()
        heightEncoder.endEncoding()


        // Shadow pass
        let previousUniforms = uniforms
        guard let shadowEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: shadowRenderPassDescriptor) else {  return }
        renderShadowPass(renderEncoder: shadowEncoder, view: view)


        // Main pass
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { fatalError() }
        renderEncoder.pushDebugGroup("Main pass")
        renderEncoder.label = "Main encoder"
        renderEncoder.setDepthStencilState(Renderer.depthStencilState)
        renderEncoder.setCullMode(.back)

        if let heap = TextureController.heap {
            renderEncoder.useHeap(heap)
        }

        var fragmentUniforms = FragmentUniforms()
        fragmentUniforms.cameraPosition = camera.position
        fragmentUniforms.lightCount = UInt32(lights.count)
        fragmentUniforms.tiling = 1
        // I think i need to set tilin herer for the character
        //        fragmentUniforms.lightProjectionMatrix = float4x4(projectionFov: radians(fromDegrees: 90),
        //                                                          near: 0.01,
        //                                                          far: 16,
        //                                                          aspect: Float(view.bounds.width) / Float(view.bounds.height))

        // Reset uniforms so projection is correct
        // GOOOOOOD LOORD i'm totally resetting the shadow matrix here
        // goodddddddd damniiitttttt
        //        scene.uniforms = previousUniforms
        //        scene.uniforms.modelMatrix = previousUniforms.modelMatrix
        //        scene.uniforms.normalMatrix = previousUniforms.normalMatrix
        uniforms.viewMatrix = previousUniforms.viewMatrix
        uniforms.projectionMatrix = previousUniforms.projectionMatrix

        renderEncoder.setFragmentBytes(&fragmentUniforms,
                                       length: MemoryLayout<FragmentUniforms>.stride,
                                       index: Int(BufferIndexFragmentUniforms.rawValue))


        renderEncoder.setFragmentBytes(&lights,
                                       length: MemoryLayout<Light>.stride * lights.count,
                                       index: Int(BufferIndexLights.rawValue))

        renderEncoder.setFragmentTexture(shadowColorTexture, index: Int(ShadowColorTexture.rawValue))
        renderEncoder.setFragmentTexture(shadowDepthTexture, index: Int(ShadowDepthTexture.rawValue))

        var farZ = Camera.FarZ
        renderEncoder.setFragmentBytes(&farZ, length: MemoryLayout<Float>.stride, index: 24)

        for renderable in renderables {
            // Allow set up for off screen targets
            renderable.renderToTarget(with: commandBuffer)
        }

        for renderable in renderables {
            renderEncoder.pushDebugGroup(renderable.name)
            renderable.render(renderEncoder: renderEncoder, uniforms: uniforms)
            renderEncoder.popDebugGroup()
        }

        skybox?.render(renderEncoder: renderEncoder, uniforms: uniforms)

        drawDebug(encoder: renderEncoder)

        renderEncoder.endEncoding()
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


extension GameScene {
    func renderShadowPass(renderEncoder: MTLRenderCommandEncoder, view: MTKView) {

        renderEncoder.pushDebugGroup("Shadow pass")
        renderEncoder.label = "Shadow encoder"
        renderEncoder.setCullMode(.none)
        renderEncoder.setDepthStencilState(Renderer.depthStencilState)

        renderEncoder.setDepthBias(0.01, slopeScale: 1.0, clamp: 0.01)

        var sunlight = lights.first!

        //        let rect = Rectangle(left: -8, right: 8, top: 8, bottom: -8)
        //        scene.uniforms.projectionMatrix = float4x4(orthographic: rect, near: 0.1, far: 16)

        //        setSpotlight(view: view, sunlight: sunlight)
        setLantern(view: view, renderEncoder: renderEncoder, sunlight: sunlight)

        renderEncoder.setVertexBytes(&sunlight, length: MemoryLayout<Light>.stride, index: Int(BufferIndexLights.rawValue))
        renderEncoder.setFragmentBytes(&sunlight, length: MemoryLayout<Light>.stride, index: Int(BufferIndexLights.rawValue))

        for (actorIdx, renderable) in renderables.enumerated() {
            renderEncoder.pushDebugGroup(renderable.name)
            renderable.renderShadow(renderEncoder: renderEncoder, uniforms: uniforms, startingIndex: actorIdx * Renderer.MaxVisibleFaces)
            renderEncoder.popDebugGroup()
        }

        renderEncoder.endEncoding()
        renderEncoder.popDebugGroup()
    }

    private func drawDebug(encoder: MTLRenderCommandEncoder) {
        encoder.pushDebugGroup("DEBUG LIGHTS")
        debugLights(renderEncoder: encoder, lightType: Pointlight, direction: camera.position)
        encoder.popDebugGroup()
    }

    private func setLantern(view: MTKView, renderEncoder: MTLRenderCommandEncoder, sunlight: Light) {

        let aspect: Float = 1
        var near: Float = Camera.NearZ
        var far: Float = Camera.FarZ

        let projection = float4x4(projectionFov: radians(fromDegrees: 90), aspectRatio: aspect, nearZ: near, farZ: far)


        //        let projection = float4x4(perspectiveProjectionFov: radians(fromDegrees: 90), aspectRatio: aspect, nearZ: near, farZ: far)
        uniforms.projectionMatrix = projection
        var viewMatrices = [CubeMap]()

        // Is this just because the sphere in demo spinning??
        let directions: [float3] = [
            [1, 0, 0],  // Right
            [-1, 0, 0], // Left
            [0, 1,  0], // Top
            [0, -1, 0], // Down
            [0, 0, 1],  // Front
            [0, 0, -1]  // Back
        ]

        let ups: [float3] = [
            [0, 1,  0], // Right
            [0, 1,  0], // Left
            [0, 0, -1], // Top
            [0, 0,  1], // Down
            [0, 1,  0], // Front
            [0, 1,  0]  // Back
        ]

        var culler_probe = [FrustumCuller]()

        // Build view matrix for each face of the cube map
        for i in 0..<6 {
            var map = CubeMap()
            map.direction = directions[i]
            map.up = ups[i]

            let position: float3 = [sunlight.position.x, sunlight.position.y, sunlight.position.z]
            let lookAt = float4x4(lookAtLHEye: position, target: position + directions[i], up: ups[i])
            map.faceViewMatrix = projection * lookAt
            viewMatrices.append(map)

            // Create frustums
            let cullerProbe = FrustumCuller(viewMatrix: map.faceViewMatrix,
                                            viewPosition: position,
                                            aspect: 1,
                                            halfAngleApertureHeight: .pi / 4,
                                            nearPlaneDistance: near,
                                            farPlaneDistance: far)

            culler_probe.append(cullerProbe)
        }


        for (actorIdx, renderable) in renderables.enumerated() {
            guard let prop = renderable as? Prop else { continue }

            let bSphere = vector_float4((prop.boundingBox.maxBounds + prop.boundingBox.minBounds) * 0.5, simd_length(prop.boundingBox.maxBounds - prop.boundingBox.minBounds) * 0.5)

            for (transformIdx, transform) in prop.transforms.enumerated() {

                for (faceIdx, probe) in culler_probe.enumerated() {
                    //                    if probe.Intersects(actorPosition: transform.position, bSphere: bSphere) {

                    //                        prop.updateShadowBuffer(transformIndex: (transformIdx * 6) + faceIdx, viewPortIndex: faceIdx)
                    //                    }
                }
            }
        }

        // setVertexBytes instanceParams

        renderEncoder.setVertexBytes(&viewMatrices,
                                     length: MemoryLayout<CubeMap>.stride * viewMatrices.count,
                                     index: Int(BufferIndexCubeFaces.rawValue))

        renderEncoder.setVertexBuffer(instanceParamBuffer,
                                      offset: 0,
                                      index: Int(BufferIndexInstanceParams.rawValue))

        renderEncoder.setFragmentBytes(&far, length: MemoryLayout<Float>.stride, index: 10)
        renderEncoder.setFragmentBytes(&near, length: MemoryLayout<Float>.stride, index: 11)
    }

}
