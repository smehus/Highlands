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
    float4 position [[ attribute(Position) ]];
    float3 normal [[ attribute(Normal) ]];
    float2 uv [[ attribute(UV) ]];
};

struct VertexOut {
    float4 position [[ position ]];
    float3 worldPosition;
    float3 worldNormal;
    float2 uv;
};

vertex VertexOut vertex_nature(const VertexIn vertexIn [[ stage_in ]],
                               constant Uniforms &uniforms [[ buffer(BufferIndexUniforms) ]],
                               constant MorphInstance *instances [[ buffer(BufferIndexInstances) ]],
                               uint instanceID [[ instance_id ]]  ) {
    MorphInstance instance = instances[instanceID];

    VertexOut out;
    float4 position = vertexIn.position;
    float3 normal = vertexIn.normal;

    out.position = uniforms.projectionMatrix * uniforms.viewMatrix
    * uniforms.modelMatrix * instance.modelMatrix * position;
    out.worldPosition = (uniforms.modelMatrix * position * instance.modelMatrix).xyz;
    out.worldNormal = uniforms.normalMatrix * instance.normalMatrix * normal;
    out.uv = vertexIn.uv;
    return out;
}

constant float3 sunlight = float3(2, 4, -4);

fragment float4 fragment_nature(VertexOut in [[ stage_in ]],
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

