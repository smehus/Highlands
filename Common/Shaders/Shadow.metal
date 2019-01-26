//
//  Shadow.metal
//  Highlands
//
//  Created by Scott Mehus on 1/26/19.
//  Copyright © 2019 Scott Mehus. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#import "../Shaders/Common.h"

struct VertexIn {
    float4 position [[ attribute(0) ]];
};
vertex float4 vertex_depth(const VertexIn vertexIn [[ stage_in ]], constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]]) {

    matrix_float4x4 mvp = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix;
    float4 position = mvp * vertexIn.position;
    
    return position;
}
