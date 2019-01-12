
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

    required init(submesh: MTKSubmesh, mdlSubmesh: MDLSubmesh, type: PropType) {
        self.submesh = submesh
        switch type {
        case .morph(let texNames, _, _):
            textures = Textures(material: mdlSubmesh.material, overrideTexture: texNames.first!)
        default:
            textures = Textures(material: mdlSubmesh.material)
        }

        material = Material(material: mdlSubmesh.material)

        pipelineState = Submesh.makePipelineState(textures: textures,
                                                  vertexFunction: type.vertexFunctionName,
                                                  fragmentFunctionName: type.fragmentFunctionName,
                                                  isGround: type.isGround,
                                                  blending: type.blending)

    }

//    required init(submesh: MTKSubmesh, mdlSubmesh: MDLSubmesh, vertexFunction: String, fragmentFunction: String, isGround: Bool = false, blending: Bool = false) {
//        self.submesh = submesh
//        textures = Textures(material: mdlSubmesh.material)
//        material = Material(material: mdlSubmesh.material)
//        pipelineState = Submesh.makePipelineState(textures: textures,
//                                                  vertexFunction: vertexFunction,
//                                                  fragmentFunctionName: fragmentFunction,
//                                                  isGround: isGround,
//                                                  blending: blending)
//    }
}

// Pipeline state
private extension Submesh {
    static func makeFunctionConstants(textures: Textures, isGround: Bool, blending: Bool) -> MTLFunctionConstantValues {
        let functionConstants = MTLFunctionConstantValues()

        var isGround = isGround
        var lighting = true
        var blending = blending
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

        // ShouldBlend
        functionConstants.setConstantValue(&blending, type: .bool, index: 7)

        return functionConstants
    }

    static func makePipelineState(textures: Textures, vertexFunction: String, fragmentFunctionName: String, isGround: Bool, blending: Bool) -> MTLRenderPipelineState {
        let functionConstants = makeFunctionConstants(textures: textures,
                                                      isGround: isGround,
                                                      blending: blending)

        let library = Renderer.library
        let vertexFunction = library?.makeFunction(name: vertexFunction)
        let fragmentFunction: MTLFunction?

        do {
            fragmentFunction = try library?.makeFunction(name: fragmentFunctionName, constantValues: functionConstants)
        } catch {
            fatalError("No Metal function exists")
        }

        var pipelineState: MTLRenderPipelineState
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction

        pipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(Prop.defaultVertexDescriptor)
        pipelineDescriptor.colorAttachments[0].pixelFormat = Renderer.colorPixelFormat
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha

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
    init(material: MDLMaterial?, overrideTexture: String? = nil) {
        func property(with semantic: MDLMaterialSemantic, name: String) -> MTLTexture? {
//            print("🛠 Loading Material \(name)")
            guard
                let property = material?.property(with: semantic),
                property.type == .string,
                let filename = property.stringValue else {
                    return nil
            }

            guard let texture = try? Submesh.loadTexture(imageName: filename) else {
                print("😡 Failed to load texture")
                return nil
            }

            print("🛠 Loaded Texture \(name)")
            return texture
        }

        if let texName = overrideTexture {
            baseColor = try! Submesh.loadTexture(imageName: texName)
        } else {
            baseColor = property(with: .baseColor, name: "baseColor")
        }
        normal = property(with: .tangentSpaceNormal, name: "tangentSpaceNormal")
        roughness = property(with: .roughness, name: "roughness")
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
        } else {
            self.shininess = 1.0
        }

        if let roughness = material?.property(with: .roughness), roughness.type == .float {
            self.roughness = roughness.floatValue
        } else {
            self.roughness = 0.5
        }
    }
}
