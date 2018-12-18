//
//  Submesh.swift
//  Highlands
//
//  Created by Scott Mehus on 12/6/18.
//  Copyright © 2018 Scott Mehus. All rights reserved.
//

import MetalKit

class Submesh {

    struct Textures {
        let baseColor: MTLTexture?
        let normal: MTLTexture?
        let roughness: MTLTexture?
    }

    let textures: Textures
    var submesh: MTKSubmesh
    let pipelineState: MTLRenderPipelineState
    let material: Material

    init(submesh: MTKSubmesh, mdlSubmesh: MDLSubmesh) {

        self.submesh = submesh
        textures = Textures(material: mdlSubmesh.material)
        material = Material(material: mdlSubmesh.material)
        pipelineState = Submesh.buildPipelineState(textures: textures)
    }

    private static func buildPipelineState(textures: Textures) -> MTLRenderPipelineState {
        let functionConstants = makeFunctionConstants(textures: textures)
        let library = Renderer.library
        let vertexFunction = library?.makeFunction(name: "vertex_main")
        let fragmentFunction: MTLFunction?
        do {
             fragmentFunction = try library?.makeFunction(name: "fragment_main", constantValues: functionConstants)
        } catch {
            fatalError(error.localizedDescription)
        }

        let pipelineState: MTLRenderPipelineState
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        pipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(Prop.defaultVertexDescriptor)
        pipelineDescriptor.colorAttachments[0].pixelFormat = Renderer.colorPixelFormat

        do {
            pipelineState = try Renderer.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError(error.localizedDescription)
        }

        return pipelineState
    }

    static func makeFunctionConstants(textures: Textures) -> MTLFunctionConstantValues {
        let functionConstants = MTLFunctionConstantValues()
        var property = textures.baseColor != nil
        functionConstants.setConstantValue(&property, type: .bool, index: 0)
        property = textures.normal != nil
        functionConstants.setConstantValue(&property, type: .bool, index: 1)
        property = textures.roughness != nil
        functionConstants.setConstantValue(&property, type: .bool, index: 2)

        // Metallic & Ambeion Occlusion (AO) - Not bothering to use these
        property = false
        functionConstants.setConstantValue(&property, type: .bool, index: 3)
        functionConstants.setConstantValue(&property, type: .bool, index: 4)
        return functionConstants
    }
}

extension Submesh: Texturable { }

private extension Submesh.Textures {
    init(material: MDLMaterial?) {
        func property(with semantic: MDLMaterialSemantic) -> MTLTexture? {

            guard let property = material?.property(with: semantic),
                property.type == .string,
                let filename = property.stringValue,
                let texture = try? Submesh.loadTexture(imageName: filename) else {
                    return nil
            }
            return texture
        }
        baseColor = property(with: .baseColor)
        normal = property(with: .tangentSpaceNormal)
        roughness = property(with: .roughness)
    }
}

private extension Material {
    init(material: MDLMaterial?) {
        self.init()

        if let baseColor = material?.property(with: .baseColor), baseColor.type == .float3 {
            self.baseColor = baseColor.float3Value
        }

        if let specular = material?.property(with: .specular), specular.type == .float3 {
            self.specularColor = specular.float3Value
        }

        if let shininess = material?.property(with: .specularExponent), shininess.type == .float {
            self.shininess = shininess.floatValue
        }

        if let roughness = material?.property(with: .roughness), roughness.type == .float3 {
            self.roughness = roughness.floatValue
        }
    }
}
