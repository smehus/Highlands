
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

    init(submesh: MTKSubmesh, mdlSubmesh: MDLSubmesh, isGround: Bool = false) {
        self.submesh = submesh
        textures = Textures(material: mdlSubmesh.material)
        material = Material(material: mdlSubmesh.material)
        pipelineState = Submesh.makePipelineState(textures: textures, isGround: isGround)
    }
}

// Pipeline state
private extension Submesh {
    static func makeFunctionConstants(textures: Textures, isGround: Bool) -> MTLFunctionConstantValues {
        let functionConstants = MTLFunctionConstantValues()

        var isGround = isGround
        var property = textures.baseColor != nil
        functionConstants.setConstantValue(&property, type: .bool, index: 0)

        property = textures.normal != nil
        functionConstants.setConstantValue(&property, type: .bool, index: 1)

        property = textures.roughness != nil
        functionConstants.setConstantValue(&property, type: .bool, index: 2)

        property = false
        functionConstants.setConstantValue(&property, type: .bool, index: 3)
        functionConstants.setConstantValue(&property, type: .bool, index: 4)

        functionConstants.setConstantValue(&isGround, type: .bool, index: 5)


        return functionConstants
    }

    static func makePipelineState(textures: Textures, isGround: Bool) -> MTLRenderPipelineState {
        let functionConstants = makeFunctionConstants(textures: textures, isGround: isGround)

        let library = Renderer.library
        let vertexFunction = library?.makeFunction(name: "vertex_main")
        let fragmentFunction: MTLFunction?

        do {
            fragmentFunction = try library?.makeFunction(name: "fragment_main", constantValues: functionConstants)
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
        if let baseColor = material?.property(with: .baseColor), baseColor.type == .float3 {
            self.baseColor = baseColor.float3Value
        }

        if let specular = material?.property(with: .specular), specular.type == .float3 {
            self.specularColor = specular.float3Value
        }

        if let shininess = material?.property(with: .specularExponent), shininess.type == .float {
            self.shininess = shininess.floatValue
        }

        if let roughness = material?.property(with: .roughness), roughness.type == .float {
            self.roughness = roughness.floatValue
        }
    }
}
