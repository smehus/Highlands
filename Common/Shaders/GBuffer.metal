//
//  GBuffer.metal
//  Highlands
//
//  Created by Scott Mehus on 1/27/19.
//  Copyright © 2019 Scott Mehus. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#import "../Shaders/Common.h"


constant bool hasColorTexture [[ function_constant(0) ]];
constant bool hasNormalTexture [[ function_constant(1) ]];
constant bool isGroundTexture [[ function_constant(5) ]];
constant bool includeLighting [[ function_constant(6) ]];
constant bool includeBlending [[ function_constant(7) ]];
constant bool hasColorTextureArray [[ function_constant(8) ]];

struct VertexOut {
    float4 position [[ position ]];
    float4 worldPosition;
    float3 worldNormal;
    float2 uv;
    float3 worldTangent;
    float3 worldBitangent;
    uint textureID [[ flat ]];
    float4 shadowPosition;
};

struct GbufferOut {
    float4 albedo [[ color(0) ]];
    float4 normal [[ color(1) ]];
    float4 position [[ color(2) ]];
};

/*
fragment GbufferOut gBufferFragment(VertexOut in [[stage_in]],
                                    depth2d<float> shadow_texture [[texture(0)]],
                                    constant Material &material [[buffer(1)]])
{

    GbufferOut out;
    out.albedo = float4(material.baseColor, 1.0);
    out.albedo.a = 0;
    out.normal = float4(normalize(in.worldNormal), 1.0);
    out.position = float4(in.worldPosition.xyz, 1.0);

    // Shadow Map
    float2 xy = in.shadowPosition.xy;
    xy = xy * 0.5 + 0.5;
    xy.y = 1 - xy.y;
    constexpr sampler s(coord::normalized, filter::linear, address::clamp_to_edge, compare_func:: less);
    float shadow_sample = shadow_texture.sample(s, xy);
    float current_sample = in.shadowPosition.z / in.shadowPosition.w;
    if (current_sample > shadow_sample ) {
        out.albedo.a = 1;
    }

    return out;
}
*/

fragment GbufferOut gBufferFragment(VertexOut in [[ stage_in ]],
                              constant Light *lights [[ buffer(BufferIndexLights) ]],
                              sampler textureSampler [[ sampler(0) ]],
                              constant Material &material [[ buffer(BufferIndexMaterials) ]],
                              constant FragmentUniforms &fragmentUniforms [[ buffer(BufferIndexFragmentUniforms) ]],
                              texture2d<float> baseColorTexture [[ texture(BaseColorTexture), function_constant(hasColorTexture) ]],
                              texture2d_array<float> baseColorTextureArray [[ texture(BaseColorTexture), function_constant(hasColorTextureArray) ]],
                              depth2d<float> shadowTexture [[ texture(ShadowTexture) ]],
                              texture2d<float> normalTexture [[ texture(NormalTexture), function_constant(hasNormalTexture) ]],
                              constant uint &tiling [[ buffer(22) ]])

{
    float4 baseColor;
    // Uses function constants to check if the model
    // has map_kd aka Color texture.
    // Basically checks the submesh was able to load the texture in map_kd
    if (hasColorTextureArray) {
        baseColor = baseColorTextureArray.sample(textureSampler, in.uv, in.textureID);
    } else if (hasColorTexture) {
        baseColor = baseColorTexture.sample(textureSampler, in.uv * tiling);
    } else {
        baseColor = float4(material.baseColor, 1);
    }

    float3 normalValue;
    // Compiler will remove these conditionals using the functionConstants
    if (hasNormalTexture) {
        // Use normal texture map values
        // get more fake shadow detail
        normalValue = normalTexture.sample(textureSampler, in.uv * tiling).rgb;
        // makes value between 0 and 1
        normalValue = normalValue * 2 - 1;
    } else {
        // Just use the faces normal
        normalValue = in.worldNormal;
    }


    normalValue = normalize(normalValue);
//    baseColor = fog(in.position, baseColor);


    GbufferOut out;
    out.albedo = baseColor;
    out.albedo.a = 0;
    out.normal = float4(normalValue, 1.0);
    out.position = float4(in.worldPosition.xyz, 1.0);

    // Shadow Map
    float2 xy = in.shadowPosition.xy;
    xy = xy * 0.5 + 0.5;
    xy.y = 1 - xy.y;
    constexpr sampler s(coord::normalized, filter::linear, address::clamp_to_edge, compare_func:: less);
    float shadow_sample = shadowTexture.sample(s, xy);
    float current_sample = in.shadowPosition.z / in.shadowPosition.w;
    if (current_sample > shadow_sample ) {
        out.albedo.a = 1;
    }

    return out;
}

fragment GbufferOut character_fragment_gbuffer(VertexOut in [[ stage_in ]],
                                        sampler textureSampler [[ sampler(0) ]],
                                        constant FragmentUniforms &fragmentUniforms [[ buffer(BufferIndexFragmentUniforms) ]],
                                        constant Light *lights [[ buffer(BufferIndexLights) ]],
                                        texture2d<float> baseColorTexture [[ texture(BaseColorTexture) ]],
                                        depth2d<float> shadowTexture [[ texture(ShadowTexture) ]],
                                        constant Material &material [[ buffer(BufferIndexMaterials) ]]) {

    constexpr sampler colorSample(filter::linear);
    float4 baseColor = baseColorTexture.sample(colorSample, in.uv);

    if (baseColor.a < 0.1) {
        discard_fragment();
    }

    if (baseColor.r == 0 && baseColor.g == 0 && baseColor.b == 0) {
        discard_fragment();
    }

    GbufferOut out;
    out.albedo = baseColor;
    out.albedo.a = 0;
    out.normal = float4(in.worldNormal, 1.0);
    out.position = float4(in.worldPosition.xyz, 1.0);

    // Shadow Map
    float2 xy = in.shadowPosition.xy;
    xy = xy * 0.5 + 0.5;
    xy.y = 1 - xy.y;
    constexpr sampler s(coord::normalized, filter::linear, address::clamp_to_edge, compare_func:: less);
    float shadow_sample = shadowTexture.sample(s, xy);
    float current_sample = in.shadowPosition.z / in.shadowPosition.w;
    if (current_sample > shadow_sample ) {
        out.albedo.a = 1;
    }

    return out;


}
