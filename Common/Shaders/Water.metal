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
    float4 worldPosition;
    float2 uv;
    float3 worldNormal;
};

vertex VertexOut vertex_water(const VertexIn vertex_in [[ stage_in ]],
                              constant Uniforms &uniforms [[ buffer(BufferIndexUniforms)]]) {
    VertexOut vertex_out;
    float4x4 mvp = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix;
    vertex_out.position = mvp * vertex_in.position;
    vertex_out.uv = vertex_in.uv;
    vertex_out.worldPosition = uniforms.modelMatrix * vertex_in.position;
    vertex_out.worldNormal = uniforms.normalMatrix * vertex_in.normal;

    return vertex_out;
}

float3 waterDiffuseLighting(VertexOut in,
                                float3 baseColor,
                                float3 normalValue,
                                constant Material &material,
                                constant FragmentUniforms &fragmentUniforms,
                                constant Light *lights)
{
    float3 diffuseColor = 0;
    float3 ambientColor = 0;
    float3 specularColor = 0;
    float materialShininess = material.shininess;
    float3 materialSpecularColor = material.specularColor;

    float3 normalDirection;
    normalDirection = normalValue.xyz;
    normalDirection = normalize(normalDirection);

    for (uint i = 0; i < fragmentUniforms.lightCount; i++) {
        Light light = lights[i];

        if (light.type == Sunlight) {
            float3 lightDirection = normalize(light.position);

            // Dot finds angle between sun direction & normal direction
            // Dot returns between -1 and 1
            // Saturate clamps between 0 and 1
            float diffuseIntensity = saturate(dot(lightDirection, normalDirection));

            if (diffuseIntensity > 0) {
                // reflection
                float3 reflection = reflect(lightDirection, normalDirection);
                // vector between camera & fragment
                float3 cameraPosition = normalize(in.worldPosition.xyz - fragmentUniforms.cameraPosition);
                float specularIntensity = pow(saturate(dot(reflection, cameraPosition)), materialShininess);
                specularColor = light.specularColor * materialSpecularColor * specularIntensity;
            }

            float3 combinedColor = light.color * baseColor * diffuseIntensity * light.intensity;
            diffuseColor += combinedColor;

            // Use intensity of light to create general light
            // Removed this to only use intensity on light applied with sunlight - not like pointlight or anything
//            diffuseColor *= light.intensity;

        } else if (light.type == Pointlight) {
            // *** Light Bulb ***\\

            // distance between light and fragment
            float d = distance(light.position, in.worldPosition.xyz);

            // Vector direction between light & fragment
            float3 lightDirection = normalize(light.position - in.worldPosition.xyz);

            // Standard formula for curved light drop off (attenuation)
            float attenuation = 1.0 / (light.attenuation.x + light.attenuation.y * d + light.attenuation.z * d * d);

            // Angle between light direction & normal
            float dotProd = dot(lightDirection, normalDirection);
            float diffuseIntensity = saturate(dotProd);

            // Color with out light drop off
            float3 color = light.color * baseColor * diffuseIntensity;

            // Light drop off
            color *= attenuation;

            diffuseColor += color;
        } else if (light.type == Ambientlight) {
            ambientColor += light.color * light.intensity;
        }
    }

    return diffuseColor + ambientColor + specularColor;

}

float4 sepiaShaderWater(float4 color) {

    float y = dot(float3(0.299, 0.587, 0.114), color.rgb);
    float4 sepia = float4(0.191, -0.054, -0.221, 0.0);
    float4 output = sepia + y;
    output.z = color.z;

    output = mix(output, color, 0.4);
    return output;
}

fragment float4 fragment_water(VertexOut vertex_in [[ stage_in ]],
                               texture2d<float> reflectionTexture [[ texture(0) ]],
                               texture2d<float> refractionTexture [[ texture(1) ]],
                               texture2d<float> normalTexture [[ texture(2) ]],
                               constant float &timer [[ buffer(3) ]],
                               constant Light *lights [[ buffer(BufferIndexLights)]],
                               constant FragmentUniforms &fragmentUniforms [[ buffer(BufferIndexFragmentUniforms) ]],
                               constant Material &material [[ buffer(BufferIndexMaterials) ]]) {

    constexpr sampler s(filter::linear, address::repeat);
    float width = float(reflectionTexture.get_width() * 2.0);
    float height = float(reflectionTexture.get_height() * 2.0);
    float x = vertex_in.position.x / width;
    float y = vertex_in.position.y / height;
    float2 reflectionCoords = float2(x, 1 - y);
    float2 refractionCoords = float2(x, y);


    // Ripples
    float2 uv = vertex_in.uv * 0.15;
    float waveStrength = 0.05;

    float2 rippleX = float2(uv.x + timer, uv.y);
    float2 rippleY = float2(-uv.x, uv.y) + timer * 0.5;
    float2 ripple = ((normalTexture.sample(s, rippleX).rg * 2.0 - 1.0) +
                     (normalTexture.sample(s, rippleY).rg * 2.0 - 1.0)) * waveStrength;

    reflectionCoords += ripple;
    reflectionCoords = clamp(reflectionCoords, 0.001, 0.999);
    refractionCoords += ripple;
    refractionCoords = clamp(refractionCoords, 0.001, 0.999);

    float4 baseColor = refractionTexture.sample(s, refractionCoords);
    float4 normalValue = normalTexture.sample(s, ripple);
    if (normalValue.r > 0.6) {
        baseColor = float4(1, 1, 1, 1);
    } else {
        baseColor = mix(baseColor, float4(0.1, 0.5, 0.6, 1.0), 0.8);
    }

    // Check out ray sample project challenge for lighting against the normalTexture rather than the geometry
    float3 color = waterDiffuseLighting(vertex_in, baseColor.xyz, vertex_in.worldNormal, material, fragmentUniforms, lights);

//    return sepiaShaderWater(float4(color, 1));
    return float4(color, 1);
}


