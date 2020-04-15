//
//  Text.swift
//  Highlands
//
//  Created by Scott Mehus on 4/12/20.
//  Copyright © 2020 Scott Mehus. All rights reserved.
//

import UIKit
import CoreText
import MetalKit

class Text: Node {

    private static let atlasSize: CGFloat = 2048
    private static var fontSize: CGFloat = 57
    private let atlasTexture: MTLTexture
    private let pipelineState: MTLRenderPipelineState
    private let quadsMeshes: [MTKMesh]

    override init() {
        atlasTexture = Text.createAtlas()
        quadsMeshes = Text.createQuadMeshes()
        pipelineState = Text.createPipelineState(quadsMeshes.first!.vertexDescriptor)

        super.init()
    }


    private static func createQuadMeshes() -> [MTKMesh] {
        let allocator = MTKMeshBufferAllocator(device: Renderer.device)
        let mdlMesh = MDLMesh(planeWithExtent: [1, 1, 1], segments: [1, 1], geometryType: .triangles, allocator: allocator)
        let mesh = try! MTKMesh(mesh: mdlMesh, device: Renderer.device)
        return [mesh]
    }

    private static func createPipelineState(_ vertexDescriptor: MDLVertexDescriptor) -> MTLRenderPipelineState {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = Renderer.library!.makeFunction(name: "vertex_text")
        descriptor.fragmentFunction = Renderer.library!.makeFunction(name: "fragment_text")
        descriptor.colorAttachments[0].pixelFormat = Renderer.colorPixelFormat

        descriptor.depthAttachmentPixelFormat = .depth32Float_stencil8
        descriptor.stencilAttachmentPixelFormat = .depth32Float_stencil8
//        descriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(vertexDescriptor)
        let state = try! Renderer.device.makeRenderPipelineState(descriptor: descriptor)

        return state
    }

    private static func create() -> MTLTexture {
        let font = UIFont(name: "HoeflerText-Regular", size: fontSize)!
        let ctFont = CTFontCreateWithName(font.fontName as CFString, fontSize, nil)

        let mabString = NSMutableAttributedString(string: "WTF", attributes: [.font: ctFont])
        let setter = CTFramesetterCreateWithAttributedString(mabString)
        let path = CGMutablePath()
        let setterSize = CTFramesetterSuggestFrameSizeWithConstraints(setter, CFRangeMake(0, 0), nil, Renderer.drawableSize, nil)
        path.addRect(CGRect(origin: CGPoint(x: 0, y: 0), size: setterSize))
        let frame = CTFramesetterCreateFrame(setter, CFRangeMake(0, 0), path, nil)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo.alphaInfoMask.rawValue & CGImageAlphaInfo.none.rawValue
        let rawData = [UInt8](repeating: 0, count: Int(setterSize.width * setterSize.height * 4))

        let context = CGContext(data: nil,
                                width: Int(setterSize.width),
                                height: Int(setterSize.height),
                                bitsPerComponent: 8,
                                bytesPerRow: Int(setterSize.width * 4),
                                space: colorSpace,
                                bitmapInfo: bitmapInfo)!



        CTFrameDraw(frame, context)
        let image = context.makeImage()

        let textureLoaderOptions: [MTKTextureLoader.Option: Any] = [.origin: MTKTextureLoader.Origin.topLeft, .SRGB: false, .generateMipmaps: NSNumber(booleanLiteral: false)]

        let textureLoader = MTKTextureLoader(device: Renderer.device)
        do {
            return try textureLoader.newTexture(cgImage: image!, options: textureLoaderOptions)
        } catch {
            fatalError("*** error creating texture \(error.localizedDescription)")
        }
    }

    private static func createAtlas() -> MTLTexture {

        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo.alphaInfoMask.rawValue & CGImageAlphaInfo.none.rawValue
        let context = CGContext(data: nil,
                                width: Int(atlasSize),
                                height: Int(atlasSize),
                                bitsPerComponent: 8,
                                bytesPerRow: Int(atlasSize),
                                space: colorSpace,
                                bitmapInfo: bitmapInfo)!
        // Turn off antialiasing so we only get fully-on or fully-off pixels.
        // This implicitly disables subpixel antialiasing and hinting.
        context.setAllowsAntialiasing(false)

        // Flip context coordinate space so y increases downward
        context.translateBy(x: 0, y: atlasSize)
        context.scaleBy(x: 1, y: -1)

        // Fill background color
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: atlasSize, height: atlasSize))

        let font = UIFont(name: "HoeflerText-Regular", size: fontSize)!
        let ctFont = CTFontCreateWithName(font.fontName as CFString, fontSize, nil)

        let fontGlyphCount: CFIndex = CTFontGetGlyphCount(ctFont)

        let glyphMargin = CGFloat(ceilf(Float(NSString(string: "!").size(withAttributes: [.font: font]).width)))

        // Set fill color so that glyphs are solid white
        context.setFillColor(UIColor.black.cgColor)

        var mutableGlyphs = [GlyphDescriptor]()

        let fontAscent = CTFontGetAscent(ctFont)
        let fontDescent = CTFontGetDescent(ctFont)

        var origin = CGPoint(x: 0, y: fontAscent)
        var maxYCoordForLine: CGFloat = -1

        (0..<fontGlyphCount).forEach { (index) in
            var glyph: CGGlyph = UInt16(index)

            // using nil instead?
//            var boundingRect: CGRect = .zero
            let boundingRect = CTFontGetBoundingRectsForGlyphs(ctFont,
                                            CTFontOrientation.horizontal,
                                            &glyph,
                                            nil,
                                            1)

            // If at the end of the line
            if origin.x + boundingRect.maxX + glyphMargin > atlasSize {
                origin.x = 0
                origin.y = CGFloat(maxYCoordForLine) + glyphMargin + fontDescent
                maxYCoordForLine = -1
            }

            // Add a new line i think
            if origin.y + boundingRect.maxY > maxYCoordForLine {
                maxYCoordForLine = origin.y + boundingRect.maxY;
            }

            let glyphOriginX: CGFloat = origin.x - boundingRect.origin.x + (glyphMargin * 0.5);
            let glyphOriginY: CGFloat = origin.y + (glyphMargin * 0.5);

            // gotta look up what this is doing...
            var glyphTransform: CGAffineTransform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: glyphOriginX, ty: glyphOriginY)

            guard let path: CGPath = CTFontCreatePathForGlyph(ctFont, glyph, &glyphTransform) else { return }
//            print("*** path \(path)")
            context.addPath(path)
            context.fillPath()

            let glyphPathBoundingRect = path.boundingBoxOfPath

            // ignore for now
//            // The null rect (i.e., the bounding rect of an empty path) is problematic
//                // because it has its origin at (+inf, +inf); we fix that up here
//                if (CGRectEqualToRect(glyphPathBoundingRect, CGRectNull))
//                {
//                    glyphPathBoundingRect = CGRectZero;
//                }


            // I think this creates coords between 0 & 1 for the texture
            let texCoordLeft = glyphPathBoundingRect.origin.x / atlasSize;
            let texCoordRight = (glyphPathBoundingRect.origin.x + glyphPathBoundingRect.size.width) / atlasSize;
            let texCoordTop = (glyphPathBoundingRect.origin.y) / atlasSize;
            let texCoordBottom = (glyphPathBoundingRect.origin.y + glyphPathBoundingRect.size.height) / atlasSize;

            // add glyphDescriptors
            // Not sure if needed if not doing signed-distance field
            mutableGlyphs.append(GlyphDescriptor(glyphIndex: glyph,
                                                 topLeftTexCoord: CGPoint(x: texCoordLeft, y: texCoordTop),
                                                 bottomRightTexCoord: CGPoint(x: texCoordRight, y: texCoordBottom)))

            origin.x += boundingRect.width + glyphMargin;
        }

        // Other stuff here:

        let contextImage = context.makeImage()!
        let fontImage = UIImage(cgImage: contextImage)
        let imageData = fontImage.pngData()!

        let textureLoaderOptions: [MTKTextureLoader.Option: Any] = [.origin: MTKTextureLoader.Origin.topLeft, .SRGB: false, .generateMipmaps: NSNumber(booleanLiteral: false)]

        let textureLoader = MTKTextureLoader(device: Renderer.device)

        do {
            return try textureLoader.newTexture(data: imageData, options: textureLoaderOptions)
        } catch {
            fatalError("*** error creating texture \(error.localizedDescription)")
        }
    }
}

typealias VertexArr = [[[Int]]]
extension Text: Renderable {

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }

    func createTexturesBuffer() { }

    func render(renderEncoder: MTLRenderCommandEncoder, uniforms vertex: Uniforms) {

        renderEncoder.pushDebugGroup("Text")
//        var uniforms = vertex
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setFragmentTexture(atlasTexture, index: 0)


        let vertices: [TextVertex] = [
            TextVertex(position: SIMD2<Float>( 250, -250), textureCoordinate: [1, 1]),
            TextVertex(position: SIMD2<Float>(-250, -250), textureCoordinate: [1, 1]),
            TextVertex(position: SIMD2<Float>(-250,  250), textureCoordinate: [1, 1]),

            TextVertex(position: SIMD2<Float>( 250, -250), textureCoordinate: [1, 1]),
            TextVertex(position: SIMD2<Float>(-250,  250), textureCoordinate: [1, 1]),
            TextVertex(position: SIMD2<Float>( 250,  250), textureCoordinate: [1, 1])
        ]

        renderEncoder.setVertexBytes(vertices, length: MemoryLayout<TextVertex>.stride * vertices.count, index: 17)
        var viewPort = vector_uint2(x: UInt32(2436.0), y: UInt32(1125.0))
        renderEncoder.setVertexBytes(&viewPort, length: MemoryLayout<vector_uint2>.size, index: 18)

        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
        renderEncoder.popDebugGroup()
        // Use quads instead
//        for mesh in quadsMeshes {
//            uniforms.modelMatrix = worldTransform
//            uniforms.normalMatrix = float3x3(normalFrom4x4: modelMatrix)
//            renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: Int(BufferIndexUniforms.rawValue))
//            renderEncoder.setVertexBuffer(mesh.vertexBuffers.first!.buffer, offset: 0, index: 0)
//
//            for submesh in mesh.submeshes {
//                renderEncoder.drawIndexedPrimitives(type: .triangle,
//                                                    indexCount: submesh.indexCount,
//                                                    indexType: submesh.indexType,
//                                                    indexBuffer: submesh.indexBuffer.buffer,
//                                                    indexBufferOffset: submesh.indexBuffer.offset)
//            }
//        }
    }
}

struct GlyphDescriptor {
    let glyphIndex: CGGlyph
    let topLeftTexCoord: CGPoint
    let bottomRightTexCoord: CGPoint
}

