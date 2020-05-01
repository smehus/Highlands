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
import CoreGraphics

class Text: Node {

    static let fontNameString = "Arial"
    static let fontSize: CGFloat = 144

    private static let atlasSize: CGFloat = 4096
    private let atlasTexture: MTLTexture
    private let pipelineState: MTLRenderPipelineState
    private let quadsMeshes: [MTKMesh]
    private let glyphs: [GlyphDescriptor]
    private var indexGlyphs: [(CGGlyph, CGRect)] = []
    private let quadSize: Float = 10000
    private var stringValue = "Highlands"

    override init() {
        (atlasTexture, glyphs) = Text.createAtlas()
        quadsMeshes = Text.createQuadMeshes()
        pipelineState = Text.createPipelineState(quadsMeshes.first!.vertexDescriptor)



        UIGraphicsBeginImageContext(CGSize(width: 1, height: 1))
        let context = UIGraphicsGetCurrentContext()

//        print(Text.fontNameString)
        let font = UIFont(name: Text.fontNameString, size: Text.fontSize)!
        let richText = NSAttributedString(string: stringValue, attributes: [.font: font])
//        let line: CTLine = CTLineCreateWithAttributedString(richText)
//        let run: CTRun = (CTLineGetGlyphRuns(line) as! Array<CTRun>).first!
//        let buffer = UnsafeMutablePointer<CGGlyph>.allocate(capacity: stringValue.count)
//        CTRunGetGlyphs(run, CFRange(location: 0, length: stringValue.count), buffer)
//
//        for glyph in UnsafeMutableBufferPointer(start: buffer, count: stringValue.count) {
//            indexGlyphs.append(glyph)
//        }


        // create stuff
        let frameSetter = CTFramesetterCreateWithAttributedString(richText)
        let setterSize = CTFramesetterSuggestFrameSizeWithConstraints(frameSetter, CFRangeMake(0, 0), nil, Renderer.drawableSize, nil)
//        print("*** setter size \(setterSize)")
        let rect = CGRect(origin: CGPoint(x: 0, y: 0), size: setterSize)
        let rectPath = CGPath(rect: rect, transform: nil)
        let frame = CTFramesetterCreateFrame(frameSetter, CFRangeMake(0, 0), rectPath, nil)

        let framePath = CTFrameGetPath(frame)
        let frameBoundingRect = framePath.boundingBoxOfPath
        let line: CTLine = (CTFrameGetLines(frame) as! Array<CTLine>).first!

        let lineOriginBuffer = UnsafeMutablePointer<CGPoint>.allocate(capacity: 1)
        CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), lineOriginBuffer)

        let run: CTRun = (CTLineGetGlyphRuns(line) as! Array<CTRun>).first!
        let glyphBuffer = UnsafeMutablePointer<CGGlyph>.allocate(capacity: stringValue.count)
        CTRunGetGlyphs(run, CFRangeMake(0, 0), glyphBuffer)

        let glyphCount = CTRunGetGlyphCount(run)
        let glyphPositionBuffer = UnsafeMutablePointer<CGPoint>.allocate(capacity: glyphCount)
        CTRunGetPositions(run, CFRangeMake(0, 0), glyphPositionBuffer)

        let glyphs = UnsafeMutableBufferPointer(start: glyphBuffer, count: glyphCount)
        let positions = UnsafeMutableBufferPointer(start: glyphPositionBuffer, count: glyphCount)

        for (index, (glyph, glyphOrigin)) in zip(glyphs, positions).enumerated()  {

            let glyphRect = CTRunGetImageBounds(run, context, CFRangeMake(index, 1))
            let boundsTransX = frameBoundingRect.origin.x + lineOriginBuffer.pointee.x
            print(lineOriginBuffer.pointee)
            let boundsTransY = frameBoundingRect.height + frameBoundingRect.origin.y - lineOriginBuffer.pointee.y + glyphOrigin.y
            let pathTransform = CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: boundsTransX, ty: boundsTransY)
            let finalRect = glyphRect.applying(pathTransform)
//            print("glyph \(glyph) pos: \(finalRect)")
            indexGlyphs.append((glyph, finalRect))
        }


//        for buf in UnsafeMutableBufferPointer(start: lineOriginBuffer, count: lines.count) {
//            print("*** BUF \(buf)")
//        }

//        for (line, lineOrigin) in zip(lines,  UnsafeMutableBufferPointer(start: lineOriginBuffer, count: lines.count)) {
//            let runs = CTLineGetGlyphRuns(line)
//        }



        super.init()
    }

    private static func createQuadMeshes() -> [MTKMesh] {
        let allocator = MTKMeshBufferAllocator(device: Renderer.device)
        let mdlMesh = MDLMesh(planeWithExtent: [1, 1, 1], segments: [1, 1], geometryType: .triangles, allocator: allocator)
        let mesh = try! MTKMesh(mesh: mdlMesh, device: Renderer.device)
        return [mesh]
    }

    static func createPipelineState(_ vertexDescriptor: MDLVertexDescriptor) -> MTLRenderPipelineState {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = Renderer.library!.makeFunction(name: "vertex_text")
        descriptor.fragmentFunction = Renderer.library!.makeFunction(name: "fragment_text")
        descriptor.colorAttachments[0].pixelFormat = Renderer.colorPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha

        descriptor.depthAttachmentPixelFormat = .depth32Float_stencil8
        descriptor.stencilAttachmentPixelFormat = .depth32Float_stencil8

//        descriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(vertexDescriptor)
        let state = try! Renderer.device.makeRenderPipelineState(descriptor: descriptor)

        return state
    }

    // I forget if this works?
    private static func create() -> MTLTexture {
        let font = UIFont(name: fontNameString, size: fontSize)!
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

    private static func createAtlas() -> (MTLTexture, [GlyphDescriptor]) {

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

        let font = UIFont(name: fontNameString, size: fontSize)!
        let ctFont = CTFontCreateWithName(font.fontName as CFString, fontSize, nil)

        let fontGlyphCount: CFIndex = CTFontGetGlyphCount(ctFont)

        let glyphMargin = CGFloat(ceilf(Float(NSString(string: "A").size(withAttributes: [.font: font]).width)))

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

            guard let path: CGPath = CTFontCreatePathForGlyph(ctFont, glyph, &glyphTransform) else {
                mutableGlyphs.append(.empty)
                return
            }

            context.addPath(path)
            context.fillPath()

            var glyphPathBoundingRect = path.boundingBoxOfPath

            // The null rect (i.e., the bounding rect of an empty path) is problematic
                // because it has its origin at (+inf, +inf); we fix that up here
            if glyphPathBoundingRect.equalTo(.null)
                {
                    glyphPathBoundingRect = .zero;
                }


            // I think this creates coords between 0 & 1 for the texture
            let texCoordLeft = glyphPathBoundingRect.origin.x / atlasSize;
            let texCoordRight = (glyphPathBoundingRect.origin.x + glyphPathBoundingRect.size.width) / atlasSize;
            let texCoordTop = (glyphPathBoundingRect.origin.y) / atlasSize;
            let texCoordBottom = (glyphPathBoundingRect.origin.y + glyphPathBoundingRect.size.height) / atlasSize;

            // add glyphDescriptors
            // Not sure if needed if not doing signed-distance field

            let validGlyph: GlyphDescriptor = .valid(ValidGlyphDescriptor(glyphIndex: glyph,
                                                                          topLeftTexCoord: CGPoint(x: texCoordLeft,
                                                                                                   y: texCoordTop),
                                                                          bottomRightTexCoord: CGPoint(x: texCoordRight,
                                                                                                       y: texCoordBottom), yOrigin: origin.y))

            mutableGlyphs.append(validGlyph)

            origin.x += boundingRect.width + glyphMargin;
        }

        // Other stuff here:

        let contextImage = context.makeImage()!
        let fontImage = UIImage(cgImage: contextImage)
        let imageData = fontImage.pngData()!

        let textureLoaderOptions: [MTKTextureLoader.Option: Any] = [.origin: MTKTextureLoader.Origin.topLeft, .SRGB: false, .generateMipmaps: NSNumber(booleanLiteral: false)]

        let textureLoader = MTKTextureLoader(device: Renderer.device)

        do {
            return (try textureLoader.newTexture(data: imageData, options: textureLoaderOptions), mutableGlyphs)
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
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setFragmentTexture(atlasTexture, index: 0)

        var xOrigin: Float = -(Float(Renderer.mtkView.drawableSize.width) / 4)
        for indexGlyph in indexGlyphs {

            let idx = Int(indexGlyph.0)
            guard glyphs.indices.contains(idx) else { continue }

            let descriptor = glyphs[idx]
            guard case let .valid(glyph) = descriptor else { continue }

            print("*** DRAW INDEX \(indexGlyph)")
            print("*** DRAW GLYPH \(glyph)")
            let glyphWidth = glyph.bottomRightTexCoord.x - glyph.topLeftTexCoord.x
            // Coordinates are flipped?
            let glyphHeight = glyph.bottomRightTexCoord.y - glyph.topLeftTexCoord.y
            let adjustedSize = (Float(glyphWidth) * quadSize)
            let maxX = xOrigin + adjustedSize
            let maxY = Float(glyphHeight) * quadSize

            let vertices: [TextVertex]

            let vec = indexGlyph.1

            // Why are the glyphs offset by 3??
//            if indexGlyph == 3 {
//                vertices = [
//                    // Top Right
//                    TextVertex(position: SIMD2<Float>(maxX, maxY), textureCoordinate: [0.0, 0.0]),
//                    // Top Left
//                    TextVertex(position: SIMD2<Float>(xOrigin, maxY), textureCoordinate: [0.0, 0.0]),
//                    // Bottom Left
//                    TextVertex(position: SIMD2<Float>(xOrigin,  0), textureCoordinate: [0.0, 0.0]),
//
//                    // Top Right
//                    TextVertex(position: SIMD2<Float>(maxX, maxY), textureCoordinate: [0.0, 0.0]),
//                    // Bottom Left
//                    TextVertex(position: SIMD2<Float>(xOrigin,  0), textureCoordinate: [0.0, 0.0]),
//                    // Bottom Right
//                    TextVertex(position: SIMD2<Float>(maxX,  0), textureCoordinate: [0.0, 0.0])
//                ]
//            } else {
                vertices = [
                    // Top Right
                    TextVertex(position: SIMD2<Float>(vec.maxX.float, vec.maxY.float), textureCoordinate: [glyph.bottomRightTexCoord.x.float, glyph.topLeftTexCoord.y.float]),
                    // Top Left
                    TextVertex(position: SIMD2<Float>(vec.minX.float, vec.maxY.float), textureCoordinate: [glyph.topLeftTexCoord.x.float, glyph.topLeftTexCoord.y.float]),
                    // Bottom Left
                    TextVertex(position: SIMD2<Float>(vec.minX.float,  vec.minY.float), textureCoordinate: [glyph.topLeftTexCoord.x.float, glyph.bottomRightTexCoord.y.float]),

                    // Top Right
                    TextVertex(position: SIMD2<Float>(vec.maxX.float, vec.maxY.float), textureCoordinate: [glyph.bottomRightTexCoord.x.float, glyph.topLeftTexCoord.y.float]),
                    // Bottom Left
                    TextVertex(position: SIMD2<Float>(vec.minX.float,  vec.minY.float), textureCoordinate: [glyph.topLeftTexCoord.x.float, glyph.bottomRightTexCoord.y.float]),
                    // Bottom Right
                    TextVertex(position: SIMD2<Float>(vec.maxX.float,  vec.minY.float), textureCoordinate: [glyph.bottomRightTexCoord.x.float, glyph.bottomRightTexCoord.y.float])
                ]
//            }


            renderEncoder.setVertexBytes(vertices, length: MemoryLayout<TextVertex>.stride * vertices.count, index: 17)
            var viewPort = vector_uint2(x: UInt32(2436.0), y: UInt32(1125.0))
            renderEncoder.setVertexBytes(&viewPort, length: MemoryLayout<vector_uint2>.size, index: 18)

            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
            xOrigin += adjustedSize
        }



        // Used for whole atlas rendering
//        let vertices: [TextVertex] = [
//            // Top Right
//            TextVertex(position: SIMD2<Float>( quadSize, -quadSize), textureCoordinate: [1, 1]),
//            // Top Left
//            TextVertex(position: SIMD2<Float>(-quadSize, -quadSize), textureCoordinate: [0, 1]),
//            // Bottom Left
//            TextVertex(position: SIMD2<Float>(-quadSize,  quadSize), textureCoordinate: [0, 0]),
//
//            // Top Right
//            TextVertex(position: SIMD2<Float>( quadSize, -quadSize), textureCoordinate: [1, 1]),
//            // Bottom Left
//            TextVertex(position: SIMD2<Float>(-quadSize,  quadSize), textureCoordinate: [0, 0]),
//            // Bottom Right
//            TextVertex(position: SIMD2<Float>( quadSize,  quadSize), textureCoordinate: [1, 0])
//        ]


        renderEncoder.popDebugGroup()
    }
}

struct ValidGlyphDescriptor {
    let glyphIndex: CGGlyph
    let topLeftTexCoord: CGPoint
    let bottomRightTexCoord: CGPoint
    let yOrigin: CGFloat
}

enum GlyphDescriptor {
    case empty
    case valid(ValidGlyphDescriptor)
}

extension CGFloat {
    var float: Float {
        return Float(self)
    }
}

