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

class Text {

    func createAtlas() {

        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo.alphaInfoMask.rawValue & CGImageAlphaInfo.none.rawValue
        let context = CGContext(data: nil,
                                width: 4096,
                                height: 4096,
                                bitsPerComponent: 8,
                                bytesPerRow: 4096,
                                space: colorSpace,
                                bitmapInfo: bitmapInfo)!


        // Turn off antialiasing so we only get fully-on or fully-off pixels.
        // This implicitly disables subpixel antialiasing and hinting.
        context.setAllowsAntialiasing(false)

        // Flip context coordinate space so y increases downward
        context.translateBy(x: 0, y: 4096)
        context.scaleBy(x: 1, y: -1)

        // Fill background color
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 4096, height: 4096))

        let font = UIFont(name: "HoeflerText-Regular", size: 114)!
        let ctFont = CTFontCreateWithName(font.fontName as CFString, 114, nil)

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
            if origin.x + boundingRect.maxX + glyphMargin > 4096 {
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

            print("*** GLIYSDFJ \(glyph)")

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

            let texCoordLeft = glyphPathBoundingRect.origin.x / 4096;
            let texCoordRight = (glyphPathBoundingRect.origin.x + glyphPathBoundingRect.size.width) / 4096;
            let texCoordTop = (glyphPathBoundingRect.origin.y) / 4096;
            let texCoordBottom = (glyphPathBoundingRect.origin.y + glyphPathBoundingRect.size.height) / 4096;

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
        let _ = fontImage.pngData()
    }
}

struct GlyphDescriptor {
    let glyphIndex: CGGlyph
    let topLeftTexCoord: CGPoint
    let bottomRightTexCoord: CGPoint
}

