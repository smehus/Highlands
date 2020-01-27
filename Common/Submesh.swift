
import MetalKit

class Submesh {

    let mtkSubmesh: MTKSubmesh
    struct Textures {
      let baseColor: MTLTexture?
      let normal: MTLTexture?
      let roughness: MTLTexture?
      let metallic: MTLTexture?
      let ao: MTLTexture?
    }

    let textures: Textures
    var material: Material

    let pipelineState: MTLRenderPipelineState!
    let shadowPipelineState: MTLRenderPipelineState!

    required init(submesh: MTKSubmesh, mdlSubmesh: MDLSubmesh, type: ModelType) {
        mtkSubmesh = submesh

        switch type {
//        case .morph(let texNames, _, _):
//            textures = Textures(material: mdlSubmesh.material, origin: type.textureOrigin, overrideTextures: texNames)
        case .character:
            print("*** CHARACTER MDLSUBMESH MATERIAL \(String(describing: mdlSubmesh.material?.name))")
            textures = Textures(material: mdlSubmesh.material)
        default:
            textures = Textures(material: mdlSubmesh.material)
//            textures = Textures(material: mdlSubmesh.material, origin: type.textureOrigin)
        }

        material = Material(material: mdlSubmesh.material)

        pipelineState = Submesh.makePipelineState(textures: textures, type: type)
        shadowPipelineState = Submesh.buildShadowPipelineState()
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
    static func makeFunctionConstants(textures: Textures, type: ModelType) -> MTLFunctionConstantValues {
        let functionConstants = MTLFunctionConstantValues()

        var isGround = type.isGround
        var lighting = type.lighting
        var blending = type.blending
        var property = (textures.baseColor != nil && !type.isTextureArray)

        functionConstants.setConstantValue(&property, type: .bool, index: 0)

        property = textures.normal != nil
        functionConstants.setConstantValue(&property, type: .bool, index: 1)

        property = textures.roughness != nil
        functionConstants.setConstantValue(&property, type: .bool, index: 2)

        property = false
        functionConstants.setConstantValue(&property, type: .bool, index: 3)
        functionConstants.setConstantValue(&property, type: .bool, index: 4)

        functionConstants.setConstantValue(&isGround, type: .bool, index: 5)

        // Lighting
        functionConstants.setConstantValue(&lighting, type: .bool, index: 6)

        // ShouldBlend
        functionConstants.setConstantValue(&blending, type: .bool, index: 7)

        var isTextureArray = type.isTextureArray
        functionConstants.setConstantValue(&isTextureArray, type: .bool, index: 8)

        return functionConstants
    }

    static func makeFunctionConstants(textures: Textures) -> MTLFunctionConstantValues {
            let functionConstants = MTLFunctionConstantValues()
            var property = textures.baseColor != nil
            functionConstants.setConstantValue(&property, type: .bool, index: 0)
            property = textures.normal != nil
            functionConstants.setConstantValue(&property, type: .bool, index: 1)
            property = textures.roughness != nil
            functionConstants.setConstantValue(&property, type: .bool, index: 2)
            property = false
            functionConstants.setConstantValue(&property, type: .bool, index: 3)
            property = false
            functionConstants.setConstantValue(&property, type: .bool, index: 4)
            return functionConstants
    }

    static func makePipelineState(textures: Textures, type: ModelType) -> MTLRenderPipelineState {
        let functionConstants: MTLFunctionConstantValues
        switch type {
        case .character:
            functionConstants = makeFunctionConstants(textures: textures)
        default:
            functionConstants = makeFunctionConstants(textures: textures, type: type)
        }


        let library = Renderer.library
        let vertexFunction: MTLFunction?
        let fragmentFunction: MTLFunction?

        do {
            fragmentFunction = try library?.makeFunction(name: type.fragmentFunctionName, constantValues: functionConstants)
            vertexFunction = try library?.makeFunction(name: type.vertexFunctionName, constantValues: functionConstants)
        } catch {
            fatalError("No Metal function exists")
        }

        var pipelineState: MTLRenderPipelineState
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction


        pipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(type.vertexDescriptor)
        pipelineDescriptor.colorAttachments[0].pixelFormat = Renderer.colorPixelFormat
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

    static func buildShadowPipelineState() -> MTLRenderPipelineState {

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

extension Submesh.Textures {
    init(material: MDLMaterial?) {
        func property(with semantic: MDLMaterialSemantic) -> MTLTexture? {
            guard let property = material?.property(with: semantic),
                property.type == .string,
                let filename = property.stringValue,
                let texture = try? Submesh.loadTexture(imageName: filename)
            else {
                    if let property = material?.property(with: semantic),
                        property.type == .texture,
                        let mdlTexture = property.textureSamplerValue?.texture {

                        return try? Submesh.loadTexture(texture: mdlTexture)
                    }
                    return nil
            }


            return texture
        }
        baseColor = property(with: MDLMaterialSemantic.baseColor)
        normal = property(with: .tangentSpaceNormal)
        roughness = property(with: .roughness)
        metallic = property(with: .metallic)
        ao = property(with: .ambientOcclusion)
    }
}

extension Material {
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
      roughness.type == .float3 {
      self.roughness = roughness.floatValue
    }
  }
}
