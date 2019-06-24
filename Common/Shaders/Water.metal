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

fragment float4 fragment_water(VertexOut vertex_in [[ stage_in ]],
                               texture2d<float> normalTexture [[ texture(2) ]],
                               constant float &timer [[ buffer(3) ]]) {

    constexpr sampler s(filter::linear, address::repeat);
    float2 uv = vertex_in.uv * 2.0;
    float waveStrength = 0.1;
    float2 rippleX = float2(uv.x + timer, uv.y);
    float2 rippleY = float2(-uv.x, uv.y) + timer;
    float2 ripple = ((normalTexture.sample(s, rippleX).rg * 2.0 - 1.0) +
                     (normalTexture.sample(s, rippleY).rg * 2.0 - 1.0)) * waveStrength;
    float2 reflectionCoords = ripple;
    reflectionCoords = clamp(reflectionCoords, 0.001, 0.999);

    float4 color = float4(0.1, 0.5, 0.6, 1.0);

    return color;
}


