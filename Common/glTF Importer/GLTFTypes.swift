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

public struct AnimationClip {
    public var name = "untitled"
    var nodeAnimations = [Int: Animation]()
    public var duration: Float = 0
    public var speed: Float = 1
}

public struct Attributes {
    var name = " "
    public var index: Int = 0
    public var bufferIndex: Int = 0
    public var offset: Int = 0
}

public class Skin {
    public var skinIndex: Int = 0 // the index in the original json array
    public var inverseBindMatricesAccessor: GLTFAccessor!
    public var jointNodeIndices = [Int]()
    public var skeletonRootNodeIndex: Int = 0

    // generated
    public var jointNodes = [CharacterNode]()
    public var skeletonRootNode: CharacterNode!
    public var jointMatrixPalette = [simd_float4x4]()
}


// needs to be a class because
// of updating bufferIndex after the fact
public class GLTFBufferView {
    public var bufferViewIndex: Int = 0 // the index in the original json array
    public var byteLength: Int = 0
    public var byteStride: Int = 0
    public var byteOffset: Int = 0
    public var target: Int = 0
    public var buffer: MTLBuffer!
    public var bufferIndex: Int = 0
    public init() {}
}

public struct GLTFValueRange {
    public var minValues = [Float]()
    public var maxValues = [Float]()
    public init() {}
}

public struct GLTFAccessor {
    public var accessorIndex: Int = 0  // the index in the original json array
    public var componentType: Int = 0
    public var type: String = "invalid"  // this is "SCALAR", "VEC3" etc
    public var offset: Int = 0
    public var count: Int = 0
    public var bufferView: GLTFBufferView!
    public var valueRange = GLTFValueRange()
    public init() {}
}

public class GLTFSubmesh: GLTFObject {
    public var accessorsForAttribute = [String: GLTFAccessor]()
    public var indexAccessor: GLTFAccessor!
    public var material: MDLMaterial?
    public var primitiveType: MDLGeometryType = .triangles

    // generated
    public var pipelineState: MTLRenderPipelineState?
    public var indexType: MTLIndexType {
        let vertexFormat = GLTFGetVertexFormat(componentType: indexAccessor.componentType,
                                               type: "SCALAR")
        if vertexFormat == .uInt {
            return MTLIndexType.uint32
        }
        return MTLIndexType.uint16
    }
    // for rendering
    var attributes = [Attributes]()
    var indexCount: Int = 0
    var indexBuffer: MTLBuffer?
    var indexBufferOffset: Int = 0
}

// needs to be a class
public class GLTFMesh: GLTFObject {
    public var gltfSubmeshes = [GLTFSubmesh]()
    var submeshes = [Character.CharacterSubmesh]()
}

public class GLTFScene: GLTFObject {
    public var meshNodes = [CharacterNode]()
    public var nodes = [CharacterNode]()
}


public class GLTFObject {
    public var name: String!
    public var extensions: Any?
    public var extras: Any?
    public init() {}
}

public struct GLTFChannel {
    public var targetNode: CharacterNode?
    public var targetPath: String?
    public var sampler: GLTFSampler?
}

public struct GLTFSampler {
    public var input: GLTFAccessor?
    public var inputAccessorIndex: Int = 0
    public var interpolation: String?
    public var output: GLTFAccessor?
    public var outputAccessorIndex: Int = 0
}

public class GLTFAnimation: GLTFObject {
    public var channels = [GLTFChannel]()
    public var samplers = [GLTFSampler]()
}

public func GLTFGetVertexFormat(componentType: Int, type: String ) -> MDLVertexFormat {
    var dataType = MDLVertexFormat.invalid
    switch componentType {
    case 5120 where type == "SCALAR":
        dataType = .char
    case 5120 where type == "VEC2":
        dataType = .char2
    case 5120 where type == "VEC3":
        dataType = .char3
    case 5120 where type == "VEC4":
        dataType = .char4
    case 5121 where type == "SCALAR":
        dataType = .uChar
    case 5121 where type == "VEC2":
        dataType = .uChar2
    case 5121 where type == "VEC3":
        dataType = .uChar3
    case 5121 where type == "VEC4":
        dataType = .uChar4
    case 5122 where type == "SCALAR":
        dataType = .short
    case 5122 where type == "VEC2":
        dataType = .short2
    case 5122 where type == "VEC3":
        dataType = .short3
    case 5122 where type == "VEC4":
        dataType = .short4
    case 5123 where type == "SCALAR":
        dataType = .uShort
    case 5123 where type == "VEC2":
        dataType = .uShort2
    case 5123 where type == "VEC3":
        dataType = .uShort3
    case 5123 where type == "VEC4":
        dataType = .uShort4
    case 5125 where type == "SCALAR":
        dataType = .uInt
    case 5125 where type == "VEC2":
        dataType = .uInt2
    case 5125 where type == "VEC3":
        dataType = .uInt3
    case 5125 where type == "VEC4":
        dataType = .uInt4
    case 5126 where type == "SCALAR":
        dataType = .float
    case 5126 where type == "VEC2":
        dataType = .float2
    case 5126 where type == "VEC3":
        dataType = .float3
    case 5126 where type == "VEC4":
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


// https://github.com/KhronosGroup/glTF/tree/master/specification/2.0
// attribute semantic properties
// POSITION: float3, NORMAL: float3, TANGENT: float4, TEXCOORD_0: float2, TEXCOORD_1: float2,
// COLOR_0: float3/float4, JOINTS_0: float4, WEIGHTS_0: float4

// generic MDL vertex descriptor to ensure correct attribute indexing
func GLTFMakeVertexDescriptor() -> MDLVertexDescriptor {
    let descriptor = MDLVertexDescriptor()
    (descriptor.attributes[0] as! MDLVertexAttribute).name = MDLVertexAttributePosition
    (descriptor.attributes[1] as! MDLVertexAttribute).name = MDLVertexAttributeNormal
    (descriptor.attributes[2] as! MDLVertexAttribute).name = MDLVertexAttributeTextureCoordinate
    (descriptor.attributes[3] as! MDLVertexAttribute).name = MDLVertexAttributeTangent
    (descriptor.attributes[4] as! MDLVertexAttribute).name = MDLVertexAttributeBitangent
    (descriptor.attributes[5] as! MDLVertexAttribute).name = MDLVertexAttributeColor
    (descriptor.attributes[6] as! MDLVertexAttribute).name = MDLVertexAttributeJointIndices
    (descriptor.attributes[7] as! MDLVertexAttribute).name = MDLVertexAttributeJointWeights
    return descriptor
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

