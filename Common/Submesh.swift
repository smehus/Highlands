
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

    init(submesh: MTKSubmesh, mdlSubmesh: MDLSubmesh, isGround: Bool = false, lighting: Bool = true) {
        self.submesh = submesh
        textures = Textures(material: mdlSubmesh.material)
        material = Material(material: mdlSubmesh.material)
        pipelineState = Submesh.makePipelineState(textures: textures, isGround: isGround, lighting: lighting)
    }
}

// Pipeline state
private extension Submesh {
    static func makeFunctionConstants(textures: Textures, isGround: Bool, lighting: Bool) -> MTLFunctionConstantValues {
        let functionConstants = MTLFunctionConstantValues()

        var isGround = isGround
        var lighting = lighting
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

        functionConstants.setConstantValue(&lighting, type: .bool, index: 6)


        return functionConstants
    }

    static func makePipelineState(textures: Textures, isGround: Bool, lighting: Bool) -> MTLRenderPipelineState {
        let functionConstants = makeFunctionConstants(textures: textures, isGround: isGround, lighting: lighting)

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
        print("ATTEMTING TO LOAD MATERIAL \(material)")
        func property(with semantic: MDLMaterialSemantic) -> MTLTexture? {
            guard let property = material?.property(with: semantic),
                property.type == .string,
                let filename = property.stringValue else {
                    print("❌ Something wrong with material property \(material?.property(with: semantic))")
                    return nil
            }

            guard let texture = try? Submesh.loadTexture(imageName: filename) else {
//                assertionFailure("Failed to load texture \(filename)")
                print("😡 Failed to load texture")
                return nil
            }

            return texture
        }

//        guard let b = property(with: .baseColor) else {
//            fatalError()
//        }

        baseColor = property(with: .baseColor)
        normal = nil
        roughness = nil
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
