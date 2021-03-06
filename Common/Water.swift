//
//  Water.swift
//  Highlands
//
//  Created by Scott Mehus on 6/23/19.
//  Copyright © 2019 Scott Mehus. All rights reserved.
//

import Foundation
import MetalKit

class Water: Node {

    private let mesh: MTKMesh
    private let mdlMesh: MDLMesh
    private var pipelineState: MTLRenderPipelineState
    private var displacementPipelineState: MTLRenderPipelineState
    private var waterNormalTexture: MTLTexture
    private var timer: Float = 0
    private let refractionRenderPass: RenderPass
    private let reflectionRenderPass: RenderPass
    private let depthStencilState: MTLDepthStencilState
    private let reflectionCamera = ReflectionCamera()
    private let mainDepthStencilState: MTLDepthStencilState
    private let orthoCamera = OrthographicCamera()
    private var heightMap: MTLTexture!
    private var displacementMeshes: [(Transform, MTKMesh)] = []


    private lazy var reflectionDepthState: MTLDepthStencilState = {
        var depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less

        return Renderer.device.makeDepthStencilState(descriptor: depthStencilDescriptor)!
    }()

    private lazy var depthState: MTLDepthStencilState = {
        var depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        depthStencilDescriptor.frontFaceStencil.depthStencilPassOperation = .keep
        return Renderer.device.makeDepthStencilState(descriptor: depthStencilDescriptor)!
    }()

    init(size: Float) {
        do {
            let plane = Primitive.makePlane(device: Renderer.device, size: size)
//            let allocator = MTKMeshBufferAllocator(device: Renderer.device)
//            let plane = MDLMesh(boxWithExtent: [size, 3.0, size], segments: [1, 1, 1], inwardNormals: false, geometryType: .triangles, allocator: allocator)
            mdlMesh = plane

            mesh = try MTKMesh(mesh: plane, device: Renderer.device)
            waterNormalTexture = try Submesh.loadTexture(imageName: "normal-water.png")!.texture


            let library = Renderer.device.makeDefaultLibrary()!


            let makePipeline: ((MTKMesh, Bool) -> MTLRenderPipelineState) = { mesh, value in

                let constants = MTLFunctionConstantValues()
                var isDisplacement = value
                constants.setConstantValue(&isDisplacement, type: .bool, index: 0)

                let descriptor = MTLRenderPipelineDescriptor()

                descriptor.vertexFunction = library.makeFunction(name: "vertex_water")
                descriptor.fragmentFunction = try! library.makeFunction(name: "fragment_water", constantValues: constants)
                descriptor.colorAttachments[0].pixelFormat = Renderer.colorPixelFormat
                descriptor.depthAttachmentPixelFormat = .depth32Float_stencil8
                descriptor.stencilAttachmentPixelFormat = .depth32Float_stencil8
                descriptor.colorAttachments[0].isBlendingEnabled = true
                descriptor.colorAttachments[0].rgbBlendOperation = .add
                descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
                descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
                descriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)
                return try! Renderer.device.makeRenderPipelineState(descriptor: descriptor)
            }


            pipelineState = makePipeline(mesh, false)
            displacementPipelineState = makePipeline(mesh, true)

            reflectionRenderPass = RenderPass(name: "reflection", size: Renderer.drawableSize)
            refractionRenderPass = RenderPass(name: "refraction", size: Renderer.drawableSize)
            TextureController.maskRenderPass = RenderPass(name: "MaskPass", size: Renderer.drawableSize)

            let stencilDescriptor = MTLDepthStencilDescriptor()
            stencilDescriptor.depthCompareFunction = .less
            stencilDescriptor.isDepthWriteEnabled = true
            depthStencilState = Renderer.device.makeDepthStencilState(descriptor: stencilDescriptor)!

            let depthStencilDescriptor = MTLDepthStencilDescriptor()
            depthStencilDescriptor.depthCompareFunction = .less
            depthStencilDescriptor.isDepthWriteEnabled = true
            mainDepthStencilState = Renderer.device.makeDepthStencilState(descriptor: depthStencilDescriptor)!

        } catch {
            fatalError(error.localizedDescription)
        }

        super.init()
    }
}

extension Water: Renderable {

    func renderStencilBuffer(renderEncoder: MTLRenderCommandEncoder, uniforms: Uniforms) {
//        render(renderEncoder: renderEncoder, pipelineState: stencilPipelineState, uniforms: uniforms)
    }

    func createTexturesBuffer() {
        
    }

    //        // Reflection
    //        let reflectEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: reflectionRenderPass.descriptor)!
    //        reflectEncoder.setDepthStencilState(depthStencilState)
    //
    //        reflectionCamera.position = camera.position
    //        reflectionCamera.position.y = -camera.position.y
    //        reflectionCamera.rotation.x = -camera.rotation.x
    //        uniforms.viewMatrix = reflectionCamera.viewMatrix
    //
    //        for renderable in renderables {
    //            reflectEncoder.pushDebugGroup("Water Refract \(renderable.name)")
    //            renderable.render(renderEncoder: reflectEncoder, uniforms: uniforms)
    //            reflectEncoder.popDebugGroup()
    //        }
    //
    //        reflectEncoder.endEncoding()
    //
    //
    //        // Refraction
    //        uniforms.viewMatrix = camera.viewMatrix
    //        let refractEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: refractionRenderPass.descriptor)!
    //        refractEncoder.setDepthStencilState(depthStencilState)
    //
    //        for renderable in renderables {
    //            refractEncoder.pushDebugGroup("Water Refract \(renderable.name)")
    //            renderable.render(renderEncoder: refractEncoder, uniforms: uniforms)
    //            refractEncoder.popDebugGroup()
    //        }
    //
    //        refractEncoder.endEncoding()


    func renderToTarget(with commandBuffer: MTLCommandBuffer, camera: Camera, lights: [Light], uniforms: Uniforms, renderables: [Renderable], shadowColorTexture: MTLTexture, shadowDepthTexture: MTLTexture, player: Node) {
        var reflectionUnifroms = Uniforms()
        reflectionUnifroms.clipPlane = SIMD4<Float>(0, 1, 0, 6);

        // Reflection
        let reflectEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: reflectionRenderPass.descriptor)!
        reflectEncoder.setDepthStencilState(reflectionDepthState)

        // set the transform
        reflectionCamera.focus = player
//        reflectionCamera.position = camera.position
        reflectionCamera.scale = camera.scale

        // Move to the negative value (if 6 move to -6) and angle upwards
        // This might have always been right, its just a weird angle

        // Just let ThirdPersonCamera handle the rotation
//        reflectionCamera.position.y = -camera.position.y

        // Should this really be from the characters perspective? Or maybe the light? Kinda weird that we can
        // rotate around and the reflection shifts but hte character doesn't
        reflectionCamera.focusDistance = (camera as! ThirdPersonCamera).focusDistance
        reflectionCamera.focusHeight = -(camera as! ThirdPersonCamera).focusHeight //

        reflectionUnifroms.projectionMatrix = reflectionCamera.projectionMatrix
        reflectionUnifroms.viewMatrix = reflectionCamera.viewMatrix

        // fragment uniforms
        var fragmentUniforms = FragmentUniforms()
        fragmentUniforms.cameraPosition = reflectionCamera.position
        fragmentUniforms.lightCount = UInt32(lights.count)
        fragmentUniforms.tiling = 1

        reflectEncoder.setFragmentTexture(shadowColorTexture, index: Int(ShadowColorTexture.rawValue))
        reflectEncoder.setFragmentTexture(shadowDepthTexture, index: Int(ShadowDepthTexture.rawValue))
        reflectEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<FragmentUniforms>.size, index: Int(BufferIndexFragmentUniforms.rawValue))

        var lights = lights
        let l = buildDefaultLight()
        lights.append(l)
        reflectEncoder.setFragmentBytes(&lights, length: MemoryLayout<Light>.stride * lights.count, index: Int(BufferIndexLights.rawValue))

        var farZ = Camera.FarZ
        reflectEncoder.setFragmentBytes(&farZ, length: MemoryLayout<Float>.stride, index: 24)

        for renderable in renderables {
            switch renderable {
            case let prop as Prop where prop.name == "treefir":
                renderable.render(renderEncoder: reflectEncoder, uniforms: reflectionUnifroms)
            case is Terrain:
                renderable.render(renderEncoder: reflectEncoder, uniforms: reflectionUnifroms)
            default:
                continue
            }
        }

        reflectEncoder.endEncoding()




        // Refraction

        // Need to calculate height thing.
        // I could just pass in the height map & sample. Then based on some arbitrary number, do some stuff.
        // Do this in the main pass



        // Water Displacement!
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: TextureController.maskRenderPass.descriptor)!
        renderEncoder.setDepthStencilState(mainDepthStencilState)
        for renderable in renderables {

            var uniforms = uniforms

            if let prop = renderable as? Prop, prop.name != "treefir" {

                uniforms.projectionMatrix = camera.projectionMatrix
                uniforms.viewMatrix = camera.viewMatrix

                for (transform, plane) in zip(prop.transforms, prop.instanceStencilPlanes) {

                    // Render Prop \\
                    prop.render(renderEncoder: renderEncoder, uniforms: uniforms, type: .stencil)


                    // Render displacement mask models \\

                    let planeTransform = Transform()
                    planeTransform.position = transform.position
                    planeTransform.position.x -= 8
                    planeTransform.scale = transform.scale
                    planeTransform.rotation = [0, 0, radians(fromDegrees: -90)]

                    uniforms.modelMatrix = prop.worldTransform * planeTransform.modelMatrix
                    uniforms.maskMatrix = orthoCamera.projectionMatrix * camera.viewMatrix
                    renderEncoder.setRenderPipelineState(prop.maskPipeline)

                    renderEncoder.setVertexBuffer(plane.vertexBuffers.first!.buffer, offset: 0, index: 0)
                    renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: Int(BufferIndexUniforms.rawValue))

                    plane.submeshes.enumerated().forEach { (_, submesh) in
                        renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                            indexCount: submesh.indexCount,
                                                            indexType: submesh.indexType,
                                                            indexBuffer: submesh.indexBuffer.buffer,
                                                            indexBufferOffset: submesh.indexBuffer.offset,
                                                            instanceCount: 1)
                    }
                }

                displacementMeshes = zip(prop.transforms, prop.instanceStencilPlanes).map { return ($0, $1) }

            } else if let char = renderable as? Character {
                // do characterrrr
                let transform = Transform()
                transform.position = char.position
                transform.position.x -= 0.3

                uniforms.modelMatrix = transform.modelMatrix

                renderEncoder.setRenderPipelineState(char.maskPipeline)
                renderEncoder.setVertexBuffer(char.boundingMask.vertexBuffers.first!.buffer, offset: 0, index: 0)
                renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: Int(BufferIndexUniforms.rawValue))

                char.boundingMask.submeshes.forEach { (submesh) in
                    renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                        indexCount: submesh.indexCount,
                                                        indexType: submesh.indexType,
                                                        indexBuffer: submesh.indexBuffer.buffer,
                                                        indexBufferOffset: submesh.indexBuffer.offset)
                }
            }
        }

        renderEncoder.endEncoding()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        reflectionRenderPass.updateTextures(size: size)
        refractionRenderPass.updateTextures(size: size)
        TextureController.maskRenderPass.updateTextures(size: size)

        let cameraSize: Float = 10
        let ratio = Float(size.width / size.height)
        let rect = Rectangle(left: -cameraSize * ratio, right: cameraSize * ratio, top: cameraSize, bottom: -cameraSize)
        orthoCamera.rect = rect

    }

    func render(renderEncoder: MTLRenderCommandEncoder, uniforms vertex: Uniforms) {
        renderEncoder.pushDebugGroup("Water")

//        renderEncoder.setStencilReferenceValue(0)
        render(renderEncoder: renderEncoder, pipelineState: pipelineState, uniforms: vertex)

//        renderEncoder.setStencilReferenceValue(0)
        renderEncoder.popDebugGroup()
    }


    private func render(renderEncoder: MTLRenderCommandEncoder, pipelineState: MTLRenderPipelineState, uniforms: Uniforms) {

        var uniforms = uniforms
        timer += 0.00017

        // Render water plane
        renderEncoder.setDepthStencilState(depthState)
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(mesh.vertexBuffers.first!.buffer, offset: 0, index: 0)

        uniforms.modelMatrix = worldTransform
        uniforms.normalMatrix = float3x3(normalFrom4x4: modelMatrix)

        renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: Int(BufferIndexUniforms.rawValue))

        renderEncoder.setFragmentTexture(reflectionRenderPass.texture, index: 0)
        renderEncoder.setFragmentTexture(refractionRenderPass.texture, index: 1)
        renderEncoder.setFragmentTexture(waterNormalTexture, index: 2)
        renderEncoder.setFragmentTexture(TextureController.maskRenderPass.texture, index: 7)
        renderEncoder.setFragmentTexture(heightMap, index: 8)


        renderEncoder.setFragmentBytes(&timer, length: MemoryLayout<Float>.size, index: 3)
        for (index, submesh) in mesh.submeshes.enumerated() {

            // Not a great way to do this
            let mdlSubmesh = mdlMesh.submeshes?[index] as! MDLSubmesh
            var material = Material(material: mdlSubmesh.material)
            renderEncoder.setFragmentBytes(&material, length: MemoryLayout<Material>.stride, index: Int(BufferIndexMaterials.rawValue))

            renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                indexCount: submesh.indexCount,
                                                indexType: submesh.indexType,
                                                indexBuffer: submesh.indexBuffer.buffer,
                                                indexBufferOffset: submesh.indexBuffer.offset)
        }





        renderEncoder.setDepthStencilState(mainDepthStencilState)
        // Render displacement meshes
        return
        let allocator = MTKMeshBufferAllocator(device: Renderer.device)

        displacementMeshes.forEach { (transform, _) in
//            let mdlMesh = MDLMesh(planeWithExtent: [15, 10, 1],
//                                   segments: [1, 1],
//                                   geometryType: .triangles,
//                                   allocator: allocator)


            let mdlMesh = MDLMesh(boxWithExtent: [15, 1, 8], segments: [1, 1, 1], inwardNormals: true, geometryType: .triangles, allocator: allocator)
            let mesh = try! MTKMesh(mesh: mdlMesh, device: Renderer.device)

            let newTrans = Transform()
            newTrans.position = transform.position
//            newTrans.position.y -= 3
            newTrans.position.x -= 10
//            newTrans.position.z += 1.6
            newTrans.scale = transform.scale
            newTrans.rotation = transform.rotation

            renderEncoder.setRenderPipelineState(displacementPipelineState)
            renderEncoder.setVertexBuffer(mesh.vertexBuffers.first!.buffer, offset: 0, index: 0)

            newTrans.rotation = [0, 0, 0]
            uniforms.modelMatrix = newTrans.modelMatrix
            uniforms.normalMatrix = newTrans.normalMatrix

            renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: Int(BufferIndexUniforms.rawValue))

            renderEncoder.setFragmentTexture(reflectionRenderPass.texture, index: 0)
            renderEncoder.setFragmentTexture(refractionRenderPass.texture, index: 1)
            renderEncoder.setFragmentTexture(waterNormalTexture, index: 2)
            renderEncoder.setFragmentTexture(TextureController.maskRenderPass.texture, index: 7)
            renderEncoder.setFragmentTexture(heightMap, index: 8)


            renderEncoder.setFragmentBytes(&timer, length: MemoryLayout<Float>.size, index: 3)
            for (index, submesh) in mesh.submeshes.enumerated() {

                // Not a great way to do this
                let mdlSubmesh = mdlMesh.submeshes?[index] as! MDLSubmesh
                var material = Material(material: mdlSubmesh.material)
                renderEncoder.setFragmentBytes(&material, length: MemoryLayout<Material>.stride, index: Int(BufferIndexMaterials.rawValue))

                renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                    indexCount: submesh.indexCount,
                                                    indexType: submesh.indexType,
                                                    indexBuffer: submesh.indexBuffer.buffer,
                                                    indexBufferOffset: submesh.indexBuffer.offset)
            }


        }
    }

    func renderShadow(renderEncoder: MTLRenderCommandEncoder, uniforms: Uniforms, startingIndex: Int) {

    }

    func calculateHeight(computeEncoder: MTLComputeCommandEncoder, heightMapTexture: MTLTexture, terrainParams: TerrainParams, uniforms: Uniforms, controlPointsBuffer: MTLBuffer?) {
        heightMap = heightMapTexture
    }
}


