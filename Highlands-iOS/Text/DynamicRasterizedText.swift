//
//  DynamicRasterizedText.swift
//  Highlands-iOS
//
//  Created by Scott Mehus on 4/29/20.
//  Copyright © 2020 Scott Mehus. All rights reserved.
//

import MetalKit

class DynamicRasterizedText: Node {

    private let stringValue: String
    init(string: String) {
        stringValue = string

        let font = UIFont(name: Text.fontNameString, size: Text.fontSize)
        let attributedString = NSAttributedString(string: string, attributes: [.font: font])

        super.init()
    }


    
}

extension DynamicRasterizedText: Renderable {

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }

    func createTexturesBuffer() { }

    func render(renderEncoder: MTLRenderCommandEncoder, uniforms vertex: Uniforms) {

    }
}
