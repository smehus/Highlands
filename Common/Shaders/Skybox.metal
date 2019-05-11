//
//  Skybox.metal
//  Highlands
//
//  Created by Scott Mehus on 1/10/19.
//  Copyright © 2019 Scott Mehus. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#import "../../Common/Utility/BridgingHeader.h"

struct VertexIn {
    float4 position [[ attribute(0) ]];
};

struct VertexOut {
    float4 position [[ position ]];
    float3 textureCoordinates;
};

vertex VertexOut vertexSkybox(const VertexIn in [[ stage_in ]], constant float4x4 &viewProjection [[ buffer(1) ]]) {

    VertexOut out;
    out.position = (viewProjection * in.position).xyww;
    out.textureCoordinates = in.position.xyz;
    return out;
}

fragment half4 fragmentSkybox(VertexOut in [[ stage_in ]], texturecube<half> cubeTexture [[ texture (BufferIndexSkybox) ]]) {
    constexpr sampler default_sampler(filter::linear);
    half4 color = cubeTexture.sample(default_sampler, in.textureCoordinates);
    return color;
}
