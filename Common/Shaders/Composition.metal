//
//  Composition.metal
//  Highlands
//
//  Created by Scott Mehus on 1/27/19.
//  Copyright © 2019 Scott Mehus. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#import "../Shaders/Common.h"

struct VertexOut {
    float4 position [[ position ]];
    float2 texCoords;
};

vertex VertexOut compositionVert(constant float2 *quadVertices [[buffer(0)]],
                                 constant float2 *quadTexCoords [[buffer(1)]],
                                 uint id [[vertex_id]])
{
    VertexOut out;
    out.position = float4(quadVertices[id], 0.0, 1.0);
    out.texCoords = quadTexCoords[id];
    return out;
}

float3 compositeLighting(float3 normal,
                       float3 position,
                       constant FragmentUniforms &fragmentUniforms,
                       constant Light *lights,
                       float3 baseColor) {

    float3 diffuseColor = 0;
    float3 normalDirection = normalize(normal);
    for (uint i = 0; i < fragmentUniforms.lightCount; i++) {
        Light light = lights[i];
        if (light.type == Sunlight) {
            float3 lightDirection = normalize(light.position);
            float diffuseIntensity = saturate(dot(lightDirection, normalDirection));
            diffuseColor += light.color * light.intensity * baseColor * diffuseIntensity;
        } else if (light.type == Pointlight) {
            float d = distance(light.position, position);
            float3 lightDirection = normalize(light.position - position);
            float attenuation = 1.0 / (light.attenuation.x + light.attenuation.y * d + light.attenuation.z * d * d);
            float diffuseIntensity = saturate(dot(lightDirection, normalDirection));
            float3 color = light.color * baseColor * diffuseIntensity;
            color *= attenuation;
            diffuseColor += color;
        } else if (light.type == Spotlight) {
            float d = distance(light.position, position);
            float3 lightDirection = normalize(light.position - position);
            float3 coneDirection = normalize(-light.coneDirection);
            float spotResult = (dot(lightDirection, coneDirection));
            if (spotResult > cos(light.coneAngle)) {
                float attenuation = 1.0 / (light.attenuation.x + light.attenuation.y * d + light.attenuation.z * d * d);
                attenuation *= pow(spotResult, light.coneAttenuation);
                float diffuseIntensity = saturate(dot(lightDirection, normalDirection));
                float3 color = light.color * baseColor * diffuseIntensity;
                color *= attenuation;
                diffuseColor += color;
            }
        }
    }
    return diffuseColor;
}

fragment float4 compositionFrag(VertexOut in [[stage_in]],
                                constant FragmentUniforms &fragmentUniforms [[ buffer(BufferIndexFragmentUniforms)]],
                                constant Light *lightsBuffer [[buffer(BufferIndexLights)]],
                                texture2d<float> albedoTexture [[ texture(0) ]],
                                texture2d<float> normalTexture [[ texture(1) ]],
                                texture2d<float> positionTexture [[ texture(2) ]],
                                depth2d<float> shadowTexture [[ texture(4) ]])
{

    constexpr sampler s(min_filter::linear, mag_filter::linear);
    float4 albedo = albedoTexture.sample(s, in.texCoords);
    float3 normal = normalTexture.sample(s, in.texCoords).xyz;
    float3 position = positionTexture.sample(s, in.texCoords).xyz;
    float3 baseColor = albedo.rgb;

    float3 diffuseColor = compositeLighting(normal, position, fragmentUniforms, lightsBuffer, baseColor);

    float shadow = albedo.a;
    if (shadow > 0) {
        diffuseColor *= 0.5;
    }

    return float4(diffuseColor, 1);
}
