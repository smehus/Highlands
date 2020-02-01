//
//  Skybox.metal
//  Highlands
//
//  Created by Scott Mehus on 1/10/19.
//  Copyright © 2019 Scott Mehus. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#import "Common.h"

struct VertexIn {
    float4 position [[ attribute(0) ]];
};

struct VertexOut {
    float4 position [[ position ]];
    float4 worldPosition;
    float3 textureCoordinates;
};

struct SkyGbufferOut {
  float4 albedo [[color(0)]];
  float4 normal [[color(1)]];
  float4 position [[color(2)]];
};

vertex VertexOut vertexSkybox(const VertexIn in [[ stage_in ]], constant Uniforms &uniforms [[ buffer(1) ]]) {

    VertexOut out;
    out.position = (uniforms.projectionMatrix * uniforms.viewMatrix * in.position).xyww;
    out.worldPosition = (uniforms.viewMatrix * in.position).xyww;
    out.textureCoordinates = in.position.xyz;
    return out;
}

fragment SkyGbufferOut fragmentSkybox(VertexOut in [[ stage_in ]], texturecube<half> cubeTexture [[ texture (BufferIndexSkybox) ]]) {
    constexpr sampler default_sampler(filter::linear);
    half4 color = cubeTexture.sample(default_sampler, in.textureCoordinates);

    SkyGbufferOut out;
    out.albedo = float4(color);
    out.albedo = 0;
//    out.normal = float4(0, 0, 0, 1);
    out.position = in.worldPosition;

    return out;
}
