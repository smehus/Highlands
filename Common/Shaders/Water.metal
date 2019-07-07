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
                               texture2d<float> reflectionTexture [[ texture(0) ]],
                               texture2d<float> refractionTexture [[ texture(1) ]],
                               texture2d<float> normalTexture [[ texture(2) ]],
                               constant float &timer [[ buffer(3) ]]) {

    constexpr sampler s(filter::linear, address::repeat);
    float width = float(reflectionTexture.get_width() * 2.0);
    float height = float(reflectionTexture.get_height() * 2.0);
    float x = vertex_in.position.x / width;
    float y = vertex_in.position.y / height;
    float2 reflectionCoords = float2(x, 1 - y);
    float2 refractionCoords = float2(x, y);


    // Ripples
    float2 uv = vertex_in.uv * 0.2;
    float waveStrength = 0.05;
    float2 rippleX = float2(uv.x + timer, uv.y);
    float2 rippleY = float2(-uv.x, uv.y) + timer * 0.5;
    float2 ripple = ((normalTexture.sample(s, rippleX).rg * 2.0 - 1.0) +
                     (normalTexture.sample(s, rippleY).rg * 2.0 - 1.0)) * waveStrength;

    reflectionCoords += ripple;
    reflectionCoords = clamp(reflectionCoords, 0.001, 0.999);
    refractionCoords += ripple;
    refractionCoords = clamp(refractionCoords, 0.001, 0.999);

    float4 color = refractionTexture.sample(s, refractionCoords);
    float4 normalColor = normalTexture.sample(s, ripple);
    if (normalColor.r > 0.6) {
        color = float4(1, 1, 1, 1);
    } else {
        color = mix(color, float4(0.1, 0.5, 0.6, 1.0), 0.8);
    }

    return color;
}


