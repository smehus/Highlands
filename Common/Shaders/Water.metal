//
//  Water.metal
//  Highlands
//
//  Created by Scott Mehus on 6/23/19.
//  Copyright © 2019 Scott Mehus. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#import "Common.h"

struct VertexIn {
    float4 position [[ attribute(Position) ]];
    float3 normal [[ attribute(Normal) ]];
    float2 uv [[ attribute(UV) ]];
};

struct VertexOut {
    float4 position [[ position ]];
    float2 uv;
};

vertex VertexOut vertex_water(const VertexIn vertex_in [[ stage_in ]],
                              constant Uniforms &uniforms [[ buffer(BufferIndexUniforms)]]) {
    VertexOut vertex_out;
    float4x4 mvp = uniforms.projectionMatrix * uniforms.viewMatrix
    * uniforms.modelMatrix;
    vertex_out.position = mvp * vertex_in.position;
    vertex_out.uv = vertex_in.uv;

    return vertex_out;
}

fragment float4 fragment_water(VertexOut vertex_in [[ stage_in ]]) {
    return float4(0.1, 0.5, 0.6, 1.0);
}


