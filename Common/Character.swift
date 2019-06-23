//
//  Character.swift
//  Highlands
//
//  Created by Scott Mehus on 12/19/18.
//  Copyright © 2018 Scott Mehus. All rights reserved.
//

import MetalKit

public class CharacterNode {
    var name: String = " "
    public var nodeIndex: Int = 0  //
    public var childIndices = [Int]()
    public var skin: GLTFSkin?
    public var jointName: String?
    public var mesh: GLTFMesh?
    public var rotationQuaternion = simd_quatf()
    public var scale = float3(1)
    public var translation = float3(0)
    public var matrix: float4x4?
    public var approximateBounds = ""
    public var inverseBindTransform = float4x4.identity()

    // generated
    public var parent: CharacterNode?
    public var children = [CharacterNode]()

    public var localTransform: float4x4 {
        if let matrix = matrix {
            return matrix
        }
        let T = float4x4(translation: translation)
        let R = float4x4(rotationQuaternion)
        let S = float4x4(scaling: scale)
        return T * R * S
    }

    var globalTransform: float4x4 {
        if let parent = parent {
            return parent.globalTransform * self.localTransform
        }
        return localTransform
    }
}

extension Character: Texturable { }

class Character: Node {

    class CharacterSubmesh: Submesh {

        // Adding properties that are already in the MTKSubmesh
        var attributes: [Attributes] = []
        var indexCount: Int = 0
        var indexBuffer: MTLBuffer?
        var indexBufferOffset: Int = 0
        var indexType: MTLIndexType = .uint16
    }

    var debugBoundingBox: DebugBoundingBox?
    override var boundingBox: MDLAxisAlignedBoundingBox {
        didSet {
            debugBoundingBox = DebugBoundingBox(boundingBox: boundingBox)
        }
    }

//    let buffers: [MTLBuffer]
//    let meshNodes: [GLTFNode]
    let animations: [GLTFAnimation]
    let rootNode: GLTFNode
    let asset: GLTFAsset
//    let textures: [String: MTLTexture]
    var currentTime: Float = 0
    var currentAnimation: GLTFAnimation?
    var currentAnimationPlaying = false
    var samplerState: MTLSamplerState
    var shadowInstanceCount: Int = 0
    let glRenderer = GLTFMTLRenderer(device: Renderer.device)

    init(name: String) {
        let url = Bundle.main.url(forResource: name, withExtension: "gltf")!
        let allocator = GLTFMTLBufferAllocator(device: Renderer.device)
        asset = GLTFAsset(url: url, bufferAllocator: allocator)

//        buffers = asset.buffers
        animations = asset.animations
        guard !asset.scenes.isEmpty else { fatalError() }

        // The nodes that contain skinning data which bind vertices to joints.
//        meshNodes = asset.defaultScene!.nodes.first!.children
//        nodes = asset.defaultScene!.nodes

        rootNode = asset.defaultScene!.nodes.first!
        samplerState = Character.buildSamplerState()

        super.init()
        self.name = name
    }

    private static func buildSamplerState() -> MTLSamplerState {
        let descriptor = MTLSamplerDescriptor()
        descriptor.sAddressMode = .repeat
        descriptor.tAddressMode = .repeat
        descriptor.mipFilter = .linear
        // TODO: I don't know why this is crashing me....
//        descriptor.maxAnisotropy = 0
        guard let state = Renderer.device.makeSamplerState(descriptor: descriptor) else {
            fatalError()
        }

        return state
    }

    override func update(deltaTime: Float) {
        guard let animation = currentAnimation, currentAnimationPlaying == true else {
            return
        }

        /*
        currentTime += deltaTime
        let time = fmod(currentTime, animation.duration)
        for nodeAnimation in animation.nodeAnimations {

            let speed = animation.speed
            let animation = nodeAnimation.value
            animation.speed = speed

            guard let node = animation.node else { continue }

            if let translation = animation.getTranslation(time: time) {
                node.translation = translation
            }

            if let rotationQuaternion = animation.getRotation(time: time) {
                node.rotationQuaternion = rotationQuaternion
            }
        }
 */
    }
}

extension Character: Renderable {
/*
    func runAnimation(clip animationClip: AnimationClip? = nil) {
        var clip = animationClip
        if clip == nil {
            guard animations.count > 0 else { return }
            clip = animations[0]
        } else {
            clip = animationClip
        }
        currentAnimation = clip
        currentTime = 0
        currentAnimationPlaying = true
        // immediately update the initial pose
        update(deltaTime: 0)
    }

    func runAnimation(name: String) {
        guard let clip = (animations.filter { $0.name == name }).first else {
            return
        }

        runAnimation(clip: clip)
    }

    func pauseAnimation() {
        currentAnimationPlaying = false
    }

    func resumeAnimation() {
        currentAnimationPlaying = true
    }

    func stopAnimation() {
        currentAnimation = nil
        currentAnimationPlaying = false
    }
 */
    func render(renderEncoder: MTLRenderCommandEncoder, uniforms vertex: Uniforms) {
//        renderEncoder.setFrontFacing(.clockwise)

        for node in rootNode.children {
            guard let mesh = node.mesh else { continue }

//            if let skin = node.skin {
////                // FIXME: -- Need to figure out what this does and assign values
////                for (i, jointNode) in skin.jointNodes.enumerated() {
////                    skin.jointMatrixPalette[i] = node.globalTransform.inverse * jointNode.globalTransform * jointNode.inverseBindTransform
////                }
////
////                let length = MemoryLayout<float4x4>.stride * skin.jointMatrixPalette.count
////                let buffer = Renderer.device.makeBuffer(bytes: &skin.jointMatrixPalette, length: length, options: [])
////                renderEncoder.setVertexBuffer(buffer, offset: 0, index: 21)
//
//            }

            var uniforms = vertex
            uniforms.modelMatrix = worldTransform
            uniforms.normalMatrix = float3x3(normalFrom4x4: modelMatrix)

            renderEncoder.setFragmentSamplerState(samplerState, index: 0)

            renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: Int(BufferIndexUniforms.rawValue))

            for submesh in mesh.submeshes {
                guard let indexAcessor = submesh.indexAccessor else { fatalError() }

                if let skin = node.skin {
                    let buffer = Renderer.device.makeBuffer(length: skin.jointNodes.count * MemoryLayout<simd_float4x4>.size, options: .storageModeShared)
                    glRenderer.computeJoints(for: submesh, in: node, buffer: buffer!)
                    renderEncoder.setVertexBuffer(buffer!, offset: 0, index: 21)
                }

                let pipeline = asset.createPipelineState(submesh: submesh)
                renderEncoder.setRenderPipelineState(pipeline)

                // Set the actual texture image
                guard var material = submesh.material else { fatalError() }
                guard let image = material.baseColorTexture?.texture.image else { fatalError() }
                let texture = glRenderer.texture(for: image, preferSRGB: true)


                renderEncoder.setFragmentTexture(texture, index: Int(BaseColorTexture.rawValue))

                // Set Material - basically just the hard coded color

                renderEncoder.setFragmentBytes(&material,
                                               length: MemoryLayout<Material>.stride,
                                               index: Int(BufferIndexMaterials.rawValue))

                for (index, attribute) in submesh.vertexDescriptor.attributes.enumerated() {
                    guard !attribute.semantic.isEmpty else { continue }
                    guard let accessor = submesh.accessorsForAttributes[attribute.semantic] else { continue }
                    guard let bufferView = accessor.bufferView else { fatalError() }
                    guard let buffer = (bufferView.buffer as? GLTFMTLBuffer)?.buffer else { fatalError() }

                    renderEncoder.setVertexBuffer(buffer,
                                                  offset: accessor.offset + bufferView.offset,
                                                  index: index)
                }

                guard let indexBuffer = indexAcessor.bufferView?.buffer as? GLTFMTLBuffer else { fatalError() }
                let indexType = (indexAcessor.componentType == .dataTypeUShort) ? MTLIndexType.uint16 : MTLIndexType.uint32

                renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                    indexCount: indexAcessor.count,
                                                    indexType: indexType,
                                                    indexBuffer: indexBuffer.buffer,
                                                    indexBufferOffset: indexAcessor.offset + indexAcessor.bufferView!.offset)
            }

            if debugRenderBoundingBox {
                debugBoundingBox?.render(renderEncoder: renderEncoder, uniforms: uniforms)
            }
        }
    }

    func renderShadow(renderEncoder: MTLRenderCommandEncoder, uniforms vertex: Uniforms, startingIndex: Int) {
/*
        for node in meshNodes {
            guard let mesh = node.mesh else { continue }

            if let skin = node.skin {
                for (i, jointNode) in skin.jointNodes.enumerated() {
                    skin.jointMatrixPalette[i] = node.globalTransform.inverse * jointNode.globalTransform * jointNode.inverseBindTransform
                }

                let length = MemoryLayout<float4x4>.stride * skin.jointMatrixPalette.count
                let buffer = Renderer.device.makeBuffer(bytes: &skin.jointMatrixPalette, length: length, options: [])
                renderEncoder.setVertexBuffer(buffer, offset: 0, index: 21)
            }

            var uniforms = vertex
            uniforms.modelMatrix = worldTransform
            uniforms.normalMatrix = float3x3(normalFrom4x4: modelMatrix)

            renderEncoder.setFragmentSamplerState(samplerState, index: 0)

            renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: Int(BufferIndexUniforms.rawValue))

            for submesh in mesh.submeshes {
                renderEncoder.setRenderPipelineState(submesh.shadowPipelineSTate)

                if submesh.textures.baseColor == nil {
                    print("🧲 TEXTURE BASE COLOR NIL")
                }

                // Set the texture
                renderEncoder.setFragmentTexture(submesh.textures.baseColor, index: Int(BaseColorTexture.rawValue))

                // Set Material
                var material = submesh.material
                renderEncoder.setFragmentBytes(&material,
                                               length: MemoryLayout<Material>.stride,
                                               index: Int(BufferIndexMaterials.rawValue))

                for attribute in submesh.attributes {
                    renderEncoder.setVertexBuffer(buffers[attribute.bufferIndex],
                                                  offset: attribute.offset,
                                                  index: attribute.index)
                }

                renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                    indexCount: submesh.indexCount,
                                                    indexType: submesh.indexType,
                                                    indexBuffer: submesh.indexBuffer!,
                                                    indexBufferOffset: submesh.indexBufferOffset)
            }

        }
 */
    }
}

extension GLTFAsset {

    func pipelineProperties(for submesh: GLTFSubmesh) -> (MTLVertexDescriptor, MTLFunctionConstantValues) {
        let vertexDescriptor = MTLVertexDescriptor()
        let functionConstants = MTLFunctionConstantValues()

        var hasPosition    = false
        var hasNormal      = false
        var hasTangent     = false
        var hasTexCoord0   = false
        var hasTexCoord1   = false
        var hasColor       = false
        var hasWeights0    = false
        var hasWeights1    = false
        var hasJoints0     = false
        var hasJoints1     = false
        var hasRoughness   = false
        var hasMetalness   = false

        let descriptor = submesh.vertexDescriptor
        for attributeIndex in 0..<GLTFVertexDescriptorMaxAttributeCount {
            let attribute = descriptor.attributes[attributeIndex]
            let layout = descriptor.bufferLayouts[attributeIndex]

            var bufferIndex = attributeIndex
            switch attribute.semantic {
            case GLTFAttributeSemanticPosition:
                hasPosition = true
                bufferIndex = 0
            case GLTFAttributeSemanticTangent:
                hasTangent = true
                bufferIndex = 2
            case GLTFAttributeSemanticNormal:
                hasNormal = true
                bufferIndex = 1
            case GLTFAttributeSemanticTexCoord0:
                hasTexCoord0 = true
                bufferIndex = 3
            case GLTFAttributeSemanticTexCoord1:
                hasTexCoord1 = true
                bufferIndex = 4
            case GLTFAttributeSemanticColor0:
                hasColor = true
                bufferIndex = 5
            case GLTFAttributeSemanticJoints0:
                hasJoints0 = true
                bufferIndex = 8
            case GLTFAttributeSemanticJoints1:
                hasJoints1 = true
                bufferIndex = 9
            case GLTFAttributeSemanticWeights0:
                hasWeights0 = true
                bufferIndex = 6
            case GLTFAttributeSemanticWeights1:
                hasWeights1 = true
                bufferIndex = 7
            case GLTFAttributeSemanticRoughness:
                hasRoughness = true
                bufferIndex = 10
            case GLTFAttributeSemanticMetallic:
                hasMetalness = true
                bufferIndex = 11
            default: break
            }

            functionConstants.setConstantValue(&hasPosition, type: .bool, index: 0)
            functionConstants.setConstantValue(&hasNormal, type: .bool, index: 1)
            functionConstants.setConstantValue(&hasTangent, type: .bool, index: 2)
            functionConstants.setConstantValue(&hasTexCoord0, type: .bool, index: 3)
            functionConstants.setConstantValue(&hasTexCoord1, type: .bool, index: 4)
            functionConstants.setConstantValue(&hasColor, type: .bool, index: 5)
            functionConstants.setConstantValue(&hasWeights0, type: .bool, index: 6)
            functionConstants.setConstantValue(&hasWeights1, type: .bool, index: 7)
            functionConstants.setConstantValue(&hasJoints0, type: .bool, index: 8)
            functionConstants.setConstantValue(&hasJoints1, type: .bool, index: 9)
            functionConstants.setConstantValue(&hasRoughness, type: .bool, index: 10)
            functionConstants.setConstantValue(&hasMetalness, type: .bool, index: 11)


            guard attribute.componentType.rawValue != 0 else { continue }

            let vertexFormat = GLTFMTLVertexFormatForComponentTypeAndDimension(attribute.componentType, attribute.dimension)
            vertexDescriptor.attributes[attributeIndex].offset = 0;
            vertexDescriptor.attributes[attributeIndex].format = vertexFormat;
            vertexDescriptor.attributes[attributeIndex].bufferIndex = bufferIndex;

            vertexDescriptor.layouts[attributeIndex].stride = layout.stride;
            vertexDescriptor.layouts[attributeIndex].stepRate = 1;
            vertexDescriptor.layouts[attributeIndex].stepFunction = .perInstance;
        }



        return(vertexDescriptor, functionConstants)
    }

    private func createVertexDescriptor(for submesh: GLTFSubmesh) -> (MTLVertexDescriptor, MTLFunctionConstantValues) {
        let functionConstants = MTLFunctionConstantValues()
        var hasNormal      = false
        var hasTangent      = false
        var hasTexCoord      = true
        var hasBitangent   = false
        var hasColor       = false
        var hasWeights    = false
        var hasJoints     = false

        functionConstants.setConstantValue(&hasTexCoord, type: .bool, index: 3)

        let layouts = NSMutableArray(capacity: 8)
        for _ in 0..<8 {
            layouts.add(MDLVertexBufferLayout(stride: 0))
        }
        let vertexDescriptor = defaultMDLVertexDescriptor

        for accessorAttribute in submesh.accessorsForAttributes {
            let accessor = accessorAttribute.value
            var attributeName = "Untitled"
            var layoutIndex = 0

            guard let key = GLTFAttribute(rawValue: accessorAttribute.key) else {
                print("WARNING! - Attribute: \(accessorAttribute.key) not supported")
                continue
            }

            switch key {
            case .position:
                attributeName = MDLVertexAttributePosition

            case .normal:
                attributeName = MDLVertexAttributeNormal
                hasNormal = true
            case .texCoord_zero:
                attributeName = MDLVertexAttributeTextureCoordinate
            case .texCoord_one:
                attributeName = MDLVertexAttributeTextureCoordinate
            case .joints:
                attributeName = MDLVertexAttributeJointIndices
                hasJoints = true
            case .weights:
                attributeName = MDLVertexAttributeJointWeights
                hasWeights = true
            case .tangent:
                attributeName = MDLVertexAttributeTangent
                hasTangent = true
            case .bitangent:
                attributeName = MDLVertexAttributeBitangent
                hasBitangent = true
            case .color:
                attributeName = MDLVertexAttributeColor
                hasColor = true
            default: continue
            }

            layoutIndex = key.bufferIndex()

            let bufferView = accessor.bufferView!
            let format: MDLVertexFormat = GLTFGetVertexFormat(componentType: accessor.componentType.rawValue, type: accessor.dimension)
            // the accessor and bufferView offsets are picked up during rendering,
            // as all layouts start from 0
            let offset = 0
            let attribute = MDLVertexAttribute(name: attributeName,
                                               format: format,
                                               offset: offset,
                                               bufferIndex: layoutIndex)

            vertexDescriptor.addOrReplaceAttribute(attribute)

            // update the layout
            var stride = bufferView.stride

            if stride <= 0 {
                stride = GLTFStrideOf(vertexFormat: format)
            }

            layouts[layoutIndex] = MDLVertexBufferLayout(stride: stride);
        }
        vertexDescriptor.layouts  = layouts

        return (MTKMetalVertexDescriptorFromModelIO(vertexDescriptor)!, functionConstants)
    }

    var defaultMDLVertexDescriptor: MDLVertexDescriptor {
        let vertexDescriptor = MDLVertexDescriptor()
        (vertexDescriptor.attributes[0] as! MDLVertexAttribute).name = MDLVertexAttributePosition
        (vertexDescriptor.attributes[1] as! MDLVertexAttribute).name = MDLVertexAttributeNormal
        (vertexDescriptor.attributes[2] as! MDLVertexAttribute).name = MDLVertexAttributeTextureCoordinate
        (vertexDescriptor.attributes[3] as! MDLVertexAttribute).name = MDLVertexAttributeTangent
        (vertexDescriptor.attributes[4] as! MDLVertexAttribute).name = MDLVertexAttributeBitangent
        (vertexDescriptor.attributes[5] as! MDLVertexAttribute).name = MDLVertexAttributeColor
        (vertexDescriptor.attributes[6] as! MDLVertexAttribute).name = MDLVertexAttributeJointIndices
        (vertexDescriptor.attributes[7] as! MDLVertexAttribute).name = MDLVertexAttributeJointWeights
        return vertexDescriptor
    }

    public func GLTFGetVertexFormat(componentType: Int, type: GLTFDataDimension) -> MDLVertexFormat {
        var dataType = MDLVertexFormat.invalid
        switch componentType {
        case 5120 where type == .scalar:
            dataType = .char
        case 5120 where type == .vector2:
            dataType = .char2
        case 5120 where type == .vector3:
            dataType = .char3
        case 5120 where type == .vector4:
            dataType = .char4
        case 5121 where type == .scalar:
            dataType = .uChar
        case 5121 where type == .vector2:
            dataType = .uChar2
        case 5121 where type == .vector3:
            dataType = .uChar3
        case 5121 where type == .vector4:
            dataType = .uChar4
        case 5122 where type == .scalar:
            dataType = .short
        case 5122 where type == .vector2:
            dataType = .short2
        case 5122 where type == .vector3:
            dataType = .short3
        case 5122 where type == .vector4:
            dataType = .short4
        case 5123 where type == .scalar:
            dataType = .uShort
        case 5123 where type == .vector2:
            dataType = .uShort2
        case 5123 where type == .vector3:
            dataType = .uShort3
        case 5123 where type == .vector4:
            dataType = .uShort4
        case 5125 where type == .scalar:
            dataType = .uInt
        case 5125 where type == .vector2:
            dataType = .uInt2
        case 5125 where type == .vector3:
            dataType = .uInt3
        case 5125 where type == .vector4:
            dataType = .uInt4
        case 5126 where type == .scalar:
            dataType = .float
        case 5126 where type == .vector2:
            dataType = .float2
        case 5126 where type == .vector3:
            dataType = .float3
        case 5126 where type == .vector4:
            dataType = .float4
        default: break
        }
        return dataType
    }

    public func GLTFStrideOf(vertexFormat: MDLVertexFormat) -> Int {
        switch  vertexFormat {
        case .float2:
            return MemoryLayout<Float>.stride * 2
        case .float3:
            return MemoryLayout<Float>.stride * 3
        case .float4:
            return MemoryLayout<Float>.stride * 4
        case .uShort4:
            return MemoryLayout<ushort>.stride * 4
        default:
            fatalError("MDLVertexFormat: \(vertexFormat.rawValue) not supported")
        }
    }

    func createPipelineState(submesh: GLTFSubmesh) -> MTLRenderPipelineState {
        let (vertexDescriptor, functionConstants) = createVertexDescriptor(for: submesh)
        let pipelineState: MTLRenderPipelineState
        do {
            let library = Renderer.device.makeDefaultLibrary()
            let vertexFunction = try library?.makeFunction(name: "character_vertex_main", constantValues: functionConstants)
            let fragmentFunction = try library?.makeFunction(name: "character_fragment_main", constantValues: functionConstants)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            descriptor.vertexFunction = vertexFunction
            descriptor.fragmentFunction = fragmentFunction
            descriptor.vertexDescriptor = vertexDescriptor
            descriptor.depthAttachmentPixelFormat = .depth32Float
            descriptor.sampleCount = Renderer.sampleCount
            try pipelineState = Renderer.device.makeRenderPipelineState(descriptor: descriptor)
        } catch let error {
            fatalError(error.localizedDescription)
        }
        return pipelineState
    }

    func mdlVertexFormat(baseType: GLTFDataType, dimension: GLTFDataDimension) -> MTLVertexFormat {
        switch baseType {
        case .dataTypeChar, .dataTypeUChar:
            switch dimension {
            case .vector2: return .char2
            case .vector3: return .char3
            case .vector4: return .char4
            default: return .invalid
            }
        case .dataTypeShort, .dataTypeUShort:
            switch dimension {
            case .vector2: return .ushort2
            case .vector3: return .ushort3
            case .vector4: return .ushort4
            default: return .invalid
            }
        case .dataTypeInt, .dataTypeUInt:
            switch dimension {
            case .scalar: return .int
            case .vector2: return .int2
            case .vector3: return .int3
            case .vector4: return .int4
            default: return .invalid
            }
        case .dataTypeFloat:
            switch dimension {
            case .scalar: return .float
            case .vector2: return .float2
            case .vector3: return .float3
            case .vector4:
                return .float4
            default: return .invalid
            }
        default: return .invalid
        }
    }
}

enum GLTFAttribute: String {
    case position = "POSITION",
    normal = "NORMAL",
    texCoord_zero = "TEXCOORD_0",
    texCoord_one = "TEXCOORD_1",
    texCoord_two = "TEXCOORD_2",
    texCoord_three = "TEXCOORD_3",
    joints = "JOINTS_0",
    weights = "WEIGHTS_0",
    tangent = "TANGENT",
    bitangent = "BITANGENT",
    color = "COLOR_0"

    func bufferIndex() -> Int {
        switch self {
        case .position:
            return 0
        case .normal:
            return 1
        case .texCoord_zero:
            return 2
        case .texCoord_one:
            return 2
        case .texCoord_two:
            return 2
        case .texCoord_three:
            return 2
        case .joints:
            return 3
        case .weights:
            return 4
        case .tangent:
            return 5
        case .bitangent:
            return 6
        case .color:
            return 7
        }
    }
}
