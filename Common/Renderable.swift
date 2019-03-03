//
//  Renderable.swift
//  Highlands
//
//  Created by Scott Mehus on 12/21/18.
//  Copyright © 2018 Scott Mehus. All rights reserved.
//

import MetalKit

protocol Renderable {
    var name: String { get }
    var shadowInstanceCount: Int { get set }
    func render(renderEncoder: MTLRenderCommandEncoder, uniforms vertex: Uniforms)
    func renderShadow(renderEncoder: MTLRenderCommandEncoder, uniforms: Uniforms)
}
