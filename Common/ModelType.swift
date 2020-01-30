//
//  ModelType.swift
//  Highlands
//
//  Created by Scott Mehus on 1/28/20.
//  Copyright © 2020 Scott Mehus. All rights reserved.
//

import Foundation
import MetalKit

enum ModelType {
    case base(name: String, lighting: Bool)
    case instanced(name: String, instanceCount: Int)
    case ground(name: String)
    case morph(textures: [String], morphTargets: [String], instanceCount: Int)
    case water
    case character

    var name: String {
        switch self {
        case .base(let name, _): return name
        case .ground(let name): return name
        case .morph(_, let targets, _): return targets.first!
        case .instanced(let name, _): return name
        case .water: return "Water"
        case .character: return "Character"
        }
    }

    var vertexFunctionName: String {
        switch self {
        case .base, .instanced, .ground:
            return "vertex_main"
        case .morph:
            return "vertex_morph"
        case .water: return "vertex_water"
        case .character: return "template_vertex_main"
        }
    }

    var fragmentFunctionName: String {
        switch self {
        case .base, .instanced, .ground:
            return "fragment_main"
        case .morph:
            return "fragment_main"
        case .water: return "fragment_water"
        case .character: return "fragment_mainPBR"
        }
    }

    var isInstanced: Bool {
        switch self {
        case .morph, .instanced: return true
        default: return false
        }
    }

    var isTextureArray: Bool {
        switch self {
        case .morph: return true
        default: return false
        }
    }

    var instanceCount: Int {
        switch self {
        case .morph(_, _, let count):
            return count
        case .instanced(_, let instanceCount):
            return instanceCount
        default:
            return 1
        }
    }

    var isGround: Bool {
        switch self {
        case .ground: return true
        default: return false
        }
    }

    var blending: Bool {
        return false
    }

    var lighting: Bool {
        switch self {
        case .base(_, let lighting): return lighting
        default: return true
        }
    }

    var textureOrigin: MTKTextureLoader.Origin {
        return .bottomLeft
    }

    var vertexDescriptor: MDLVertexDescriptor {
        switch self {
        case .character:
            return Character.vertexDescriptor
        default:
            return Prop.defaultVertexDescriptor
        }
    }

    func fragmentFunctionConstants(textures: Submesh.Textures) -> MTLFunctionConstantValues {
        switch self {
        case .character:
            return ModelType.characterFragmentFunctionConstants(textures: textures)
        default:
            return ModelType.defaultFragmentFunctionConstants(textures: textures, type: self)
        }
    }

    func vertexFunctionConstants(textures: Submesh.Textures) -> MTLFunctionConstantValues {
        switch self {
        case .character:
            return ModelType.characterVertexFunctionConstants(hasSkeleton: true)
        default:
            return ModelType.defaultFragmentFunctionConstants(textures: textures, type: self)
        }
    }
}

// Character
extension ModelType {
    static func characterFragmentFunctionConstants(textures: Submesh.Textures) -> MTLFunctionConstantValues {
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

    static func characterVertexFunctionConstants(hasSkeleton: Bool) -> MTLFunctionConstantValues {
      let functionConstants = MTLFunctionConstantValues()
      var addSkeleton = hasSkeleton
      functionConstants.setConstantValue(&addSkeleton, type: .bool, index: 5)
      return functionConstants
    }

}


// Props
extension ModelType {
    static func defaultFragmentFunctionConstants(textures: Submesh.Textures, type: ModelType) -> MTLFunctionConstantValues {
        let functionConstants = MTLFunctionConstantValues()

        var isLighting = type.lighting
        var isBlending = type.blending
        var property = (textures.baseColor != nil && !type.isTextureArray)

        functionConstants.setConstantValue(&property, type: .bool, index: 0)

        property = textures.normal != nil
        functionConstants.setConstantValue(&property, type: .bool, index: 1)

        property = textures.roughness != nil
        functionConstants.setConstantValue(&property, type: .bool, index: 2)

        property = false
        functionConstants.setConstantValue(&property, type: .bool, index: 3)
        functionConstants.setConstantValue(&property, type: .bool, index: 4)


        // Lighting
        functionConstants.setConstantValue(&isLighting, type: .bool, index: 6)

        // ShouldBlend
        functionConstants.setConstantValue(&isBlending, type: .bool, index: 7)

        var isTexArray = type.isTextureArray
        functionConstants.setConstantValue(&isTexArray, type: .bool, index: 8)

        return functionConstants
    }
}
