
import MetalKit

class Submesh {

    let mtkSubmesh: MTKSubmesh
    struct Textures {
        let baseColor: MTLTexture?
        let normal: MTLTexture?
        let roughness: MTLTexture?
    }

    let textures: Textures
    var material: Material
    let type: ModelType
    let pipelineState: MTLRenderPipelineState!
    let shadowPipelineState: MTLRenderPipelineState!

    required init(submesh: MTKSubmesh, mdlSubmesh: MDLSubmesh, type: ModelType) {
        mtkSubmesh = submesh
        self.type = type

        switch type {
        case .morph(let texNames, _, _):
            textures = Textures(material: mdlSubmesh.material, origin: type.textureOrigin, overrideTextures: texNames)
        case .character:
            print("*** CHARACTER MDLSUBMESH MATERIAL \(String(describing: mdlSubmesh.material?.name))")
            textures = Textures(material: mdlSubmesh.material, origin: type.textureOrigin)
        default:
            textures = Textures(material: mdlSubmesh.material, origin: type.textureOrigin)
        }

        material = Material(material: mdlSubmesh.material)

        pipelineState = Submesh.makePipelineState(textures: textures, type: type)
        shadowPipelineState = Submesh.buildShadowPipelineState(type: type)
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

    static func makePipelineState(textures: Submesh.Textures, type: ModelType) -> MTLRenderPipelineState {
        let vertexContants = type.vertexFunctionConstants(textures: textures)
        let fragmentConstants = type.fragmentFunctionConstants(textures: textures)


        let library = Renderer.library
        let vertexFunction: MTLFunction?
        let fragmentFunction: MTLFunction?

        do {
            vertexFunction = try library?.makeFunction(name: type.vertexFunctionName, constantValues: vertexContants)
            fragmentFunction = try library?.makeFunction(name: type.fragmentFunctionName, constantValues: fragmentConstants)
        } catch {
            fatalError(error.localizedDescription)
        }

        var pipelineState: MTLRenderPipelineState
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction


        pipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(type.vertexDescriptor)
        pipelineDescriptor.colorAttachments[0].pixelFormat = Renderer.colorPixelFormat
        pipelineDescriptor.colorAttachments[1].pixelFormat = .rgba16Float
        pipelineDescriptor.colorAttachments[2].pixelFormat = .rgba16Float
        pipelineDescriptor.depthAttachmentPixelFormat = Renderer.depthPixelFormat
//        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
//        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
//        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
//        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.sampleCount = Renderer.sampleCount


        do {
            pipelineState = try Renderer.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch let error {
            fatalError(error.localizedDescription)
        }
        return pipelineState
    }

    static func buildShadowPipelineState(type: ModelType) -> MTLRenderPipelineState {

        let constants = MTLFunctionConstantValues()
        var isSkinned = false
        constants.setConstantValue(&isSkinned, type: .bool, index: 0)
        var isInstanced = true
        constants.setConstantValue(&isInstanced, type: .bool, index: 1)


        var pipelineState: MTLRenderPipelineState
        do {
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = try Renderer.library!.makeFunction(name: "vertex_omni_depth", constantValues: constants)
            pipelineDescriptor.fragmentFunction = try Renderer.library!.makeFunction(name: "fragment_depth", constantValues: constants)
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
            pipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(Prop.defaultVertexDescriptor)
            pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
            pipelineDescriptor.inputPrimitiveTopology = .triangle
            pipelineState = try Renderer.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch let error {
            fatalError(error.localizedDescription)
        }

        return pipelineState
    }
}

extension Submesh: Texturable {}

private extension Submesh.Textures {
    init(material: MDLMaterial?, origin: MTKTextureLoader.Origin = .topLeft, overrideTextures: [String]? = nil) {
        func property(with semantic: MDLMaterialSemantic, name: String) -> MTLTexture? {
            guard
                let property = material?.property(with: semantic),
                property.type == .string,
                let filename = property.stringValue
            else {
                if let property = material?.property(with: semantic),
                    property.type == .texture,
                    let mdlTexture = property.textureSamplerValue?.texture {

                    return try? Submesh.loadTexture(texture: mdlTexture)
                }

                return nil
            }

            guard let texture = ((try? Submesh.loadTexture(imageName: filename, origin: origin)) as MTLTexture??) else {
                print("😡 Failed to load texture \(filename)")
                return nil
            }

            print("🛠 Loaded Texture \(filename)")
            return texture
        }

        if let texNames = overrideTextures {
            baseColor = Submesh.loadTextureArray(textureNames: texNames)
        } else {
            baseColor = property(with: .baseColor, name: "baseColor")
        }

//        baseColor = property(with: .baseColor, name: "baseColor")
        normal = property(with: .tangentSpaceNormal, name: "tangentSpaceNormal")
        roughness = property(with: .roughness, name: "roughness")
    }
}

extension Material {
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
