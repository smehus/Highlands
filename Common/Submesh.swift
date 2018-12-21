/**
 * Copyright (c) 2018 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import MetalKit

class Submesh {

    var submesh: MTKSubmesh?
    struct Textures {
        let baseColor: MTLTexture?
        let normal: MTLTexture?
        let roughness: MTLTexture?
    }
    let textures: Textures
    var material: Material

    let pipelineState: MTLRenderPipelineState!

    init(pipelineState: MTLRenderPipelineState, material: MDLMaterial?) {
        textures = Textures(material: material)
        self.material = Material(material: material)
        self.pipelineState = pipelineState
    }

    init(submesh: MTKSubmesh, mdlSubmesh: MDLSubmesh) {
        self.submesh = submesh
        textures = Textures(material: mdlSubmesh.material)
        material = Material(material: mdlSubmesh.material)
        pipelineState = Submesh.makePipelineState(textures: textures)
    }
}

// Pipeline state
private extension Submesh {
    static func makeFunctionConstants(textures: Textures)
        -> MTLFunctionConstantValues {
            let functionConstants = MTLFunctionConstantValues()
            var property = textures.baseColor != nil
            functionConstants.setConstantValue(&property, type: .bool, index: 0)
            property = textures.normal != nil
            functionConstants.setConstantValue(&property, type: .bool, index: 1)
            property = textures.roughness != nil
            functionConstants.setConstantValue(&property, type: .bool, index: 2)
            property = false
            functionConstants.setConstantValue(&property, type: .bool, index: 3)
            functionConstants.setConstantValue(&property, type: .bool, index: 4)

            return functionConstants
    }

    static func makePipelineState(textures: Textures) -> MTLRenderPipelineState {
        let functionConstants = makeFunctionConstants(textures: textures)

        let library = Renderer.library
        let vertexFunction = library?.makeFunction(name: "vertex_main")
        let fragmentFunction: MTLFunction?
        do {
            fragmentFunction = try library?.makeFunction(name: "fragment_main",
                                                         constantValues: functionConstants)
        } catch {
            fatalError("No Metal function exists")
        }

        var pipelineState: MTLRenderPipelineState
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction

        pipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(Prop.defaultVertexDescriptor)
        pipelineDescriptor.colorAttachments[0].pixelFormat = Renderer.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        do {
            pipelineState = try Renderer.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch let error {
            fatalError(error.localizedDescription)
        }
        return pipelineState
    }
}

extension Submesh: Texturable {}

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
        if let baseColor = material?.property(with: .baseColor),
            baseColor.type == .float3 {
            self.baseColor = baseColor.float3Value
        }
        if let specular = material?.property(with: .specular),
            specular.type == .float3 {
            self.specularColor = specular.float3Value
        }
        if let shininess = material?.property(with: .specularExponent),
            shininess.type == .float {
            self.shininess = shininess.floatValue
        }
        if let roughness = material?.property(with: .roughness),
            roughness.type == .float {
            self.roughness = roughness.floatValue
        }
    }
}
