//
//  MorphShader.metal
//  Highlands
//
//  Created by Scott Mehus on 1/11/19.
//  Copyright © 2019 Scott Mehus. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#import "Common.h"

struct VertexIn {
    packed_float3 position;
    packed_float3 normal;
    float2 uv;
};

struct VertexOut {
    float4 position [[ position ]];
    float3 worldPosition;
    float3 worldNormal;
    float2 uv;
};

vertex VertexOut vertex_morph(constant VertexIn *in [[ buffer(0) ]],
                               uint vertexID [[ vertex_id]],
                               constant Uniforms &uniforms [[ buffer(BufferIndexUniforms) ]],
                               constant MorphInstance *instances [[ buffer(BufferIndexInstances) ]],
                               uint instanceID [[ instance_id ]]  ) {

    VertexIn vertexIn = in[vertexID];
    MorphInstance instance = instances[instanceID];

    VertexOut out;
    float4 position = float4(vertexIn.position, 1);
    float3 normal = vertexIn.normal;

    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * instance.modelMatrix * position;
    out.worldPosition = (uniforms.modelMatrix * position * instance.modelMatrix).xyz;
    out.worldNormal = uniforms.normalMatrix * instance.normalMatrix * normal;
    out.uv = vertexIn.uv;
    return out;
}

constant float3 sunlight = float3(2, 4, -4);

fragment float4 fragment_morph(VertexOut in [[ stage_in ]],
                                texture2d<float> baseColorTexture [[ texture(0) ]],
                                constant FragmentUniforms &fragmentUniforms [[buffer(BufferIndexFragmentUniforms)]]){

    constexpr sampler s(filter::linear);
    float4 baseColor = baseColorTexture.sample(s, in.uv);
    float3 normal = normalize(in.worldNormal);

    float3 lightDirection = normalize(sunlight);
    float diffuseIntensity = saturate(dot(lightDirection, normal));
    float4 color = mix(baseColor*0.5, baseColor*1.5, diffuseIntensity);
    return color;
}

