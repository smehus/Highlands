//
//  MorphShader.metal
//  Highlands
//
//  Created by Scott Mehus on 1/11/19.
//  Copyright © 2019 Scott Mehus. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#import "../../Common/Utility/Common.h"

constant bool hasColorTexture [[ function_constant(0) ]];

struct VertexIn {
    packed_float3 position;
    packed_float3 normal;
    float2 uv;
};

struct VertexOut {
    float4 position [[ position ]];
    float4 worldPosition;
    float3 worldNormal;
    float2 uv;
    uint textureID [[ flat ]];
    float4 shadowPosition;
};

vertex VertexOut vertex_morph(constant VertexIn *in [[ buffer(0) ]],
                               uint vertexID [[ vertex_id]],
                               constant Uniforms &uniforms [[ buffer(BufferIndexUniforms) ]],
                               constant Instances *instances [[ buffer(BufferIndexInstances) ]],
                               uint instanceID [[ instance_id ]]  ) {

//    VertexIn vertexIn = in[vertexID];
//    Instances instance = instances[instanceID];
//
//    VertexOut out;
//    float4 position = float4(vertexIn.position, 1);
//    float3 normal = vertexIn.normal;
//
//    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * instance.modelMatrix * position;

    // Position and instance model matrix were REVERSED!!! thats why it was all fucked up
//    out.worldPosition = uniforms.modelMatrix * position * instance.modelMatrix;
//    out.worldNormal = uniforms.normalMatrix * instance.normalMatrix * normal;
//    out.uv = vertexIn.uv;


    VertexOut out;
    VertexIn vertexIn = in[vertexID];
    Instances instance = instances[instanceID];

    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * instance.modelMatrix * float4(vertexIn.position, 1);
    out.worldPosition = uniforms.modelMatrix * instance.modelMatrix * float4(vertexIn.position, 1);
    out.worldNormal = uniforms.normalMatrix * instance.normalMatrix * float3(vertexIn.normal);
    out.uv = vertexIn.uv;
    out.textureID = instance.textureID;
    out.shadowPosition = uniforms.shadowMatrix * uniforms.modelMatrix * float4(vertexIn.position, 1);

    // Normal matrix is the same as world space aka model matrix
//    out.worldTangent = uniforms.normalMatrix * instance.normalMatrix * vertexIn.tangent;
//    out.worldBitangent = uniforms.normalMatrix * instance.normalMatrix * vertexIn.bitangent;
    return out;
}

constant float3 sunlight = float3(2, 4, -4);

fragment float4 fragment_morph(VertexOut in [[ stage_in ]],
                                texture2d<float> baseColorTexture [[ texture(0) ]],
                                constant Material &material [[ buffer(BufferIndexMaterials) ]],
                                constant FragmentUniforms &fragmentUniforms [[buffer(BufferIndexFragmentUniforms)]]){



    float4 baseColor;
    if (hasColorTexture) {
        constexpr sampler s(filter::linear);
        baseColor = baseColorTexture.sample(s, in.uv);
    } else {
        baseColor = float4(material.baseColor, 1);
    }

    float3 normal = normalize(in.worldNormal);

    float3 lightDirection = normalize(sunlight);
    float diffuseIntensity = saturate(dot(lightDirection, normal));
    float4 color = mix(baseColor*0.5, baseColor*1.5, diffuseIntensity);
    return color;
}

