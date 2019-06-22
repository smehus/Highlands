//
//  Copyright (c) 2018 Warren Moore. All rights reserved.
//
//  Permission to use, copy, modify, and distribute this software for any
//  purpose with or without fee is hereby granted, provided that the above
//  copyright notice and this permission notice appear in all copies.
//
//  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
//  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
//  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
//  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
//  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
//  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
//  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
//

#include "TargetConditionals.h"

#if TARGET_OS_OSX
@import Cocoa;
#elif TARGET_OS_IOS
@import UIKit;
#endif

//! Project version number for GLTF.
FOUNDATION_EXPORT double GLTFVersionNumber;

//! Project version string for GLTF.
FOUNDATION_EXPORT const unsigned char GLTFVersionString[];

#import "GLTFAccessor.h"
#import "GLTFAnimation.h"
#import "GLTFAsset.h"
#import "GLTFBinaryChunk.h"
#import "GLTFBuffer.h"
#import "GLTFBufferAllocator.h"
#import "GLTFBufferView.h"
#import "GLTFCamera.h"
#import "GLTFDefaultBufferAllocator.h"
#import "GLTFEnums.h"
#import "GLTFExtensionNames.h"
#import "GLTFImage.h"
#import "GLTFKHRLight.h"
#import "GLTFMaterial.h"
#import "GLTFMesh.h"
#import "GLTFNode.h"
#import "GLTFObject.h"
#import "GLTFScene.h"
#import "GLTFSkin.h"
#import "GLTFTexture.h"
#import "GLTFTextureSampler.h"
#import "GLTFVertexDescriptor.h"
#import "GLTFUtilities.h"
