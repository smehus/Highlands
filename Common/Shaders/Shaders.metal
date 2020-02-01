//
//  Shaders.metal
//  Highlands
//
//  Created by Scott Mehus on 12/5/18.
//  Copyright © 2018 Scott Mehus. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#import "Common.h"

constant bool hasColorTexture [[ function_constant(0) ]];
constant bool hasNormalTexture [[ function_constant(1) ]];
constant bool includeLighting [[ function_constant(6) ]];
constant bool includeBlending [[ function_constant(7) ]];
constant bool hasColorTextureArray [[ function_constant(8) ]];

struct VertexIn {
    float4 position [[ attribute(Position) ]];
    float3 normal [[ attribute(Normal) ]];
    float2 uv [[ attribute(UV) ]];
    float3 tangent [[ attribute(Tangent) ]];
    float3 bitangent [[ attribute(Bitangent) ]];
};

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

struct PropTextures {
    texture2d<float> baseColorTexture;
    texture2d<float> normalTexture;
//    texture2d_array<float> baseColorTextureArray;
};

vertex VertexOut vertex_main(const VertexIn vertexIn [[ stage_in ]],
                             constant Instances *instances [[ buffer(BufferIndexInstances) ]],
                             uint instanceID [[ instance_id ]],
                             constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]]) {

    VertexOut out;

    Instances instance = instances[instanceID];

    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * instance.modelMatrix * float4(vertexIn.position.xyz, 1);

    out.worldPosition = uniforms.modelMatrix * instance.modelMatrix * vertexIn.position;
    out.worldNormal = uniforms.normalMatrix * instance.normalMatrix * vertexIn.normal;
    out.uv = vertexIn.uv;
    // Normal matrix is the same as world space aka model matrix
    out.worldTangent = uniforms.normalMatrix * instance.normalMatrix * vertexIn.tangent;
    out.worldBitangent = uniforms.normalMatrix * instance.normalMatrix * vertexIn.bitangent;
    out.textureID = instance.textureID;

    // Can i get the shadow matrix from the instances here?
    // use this for non omni directional shadow
    out.shadowPosition = uniforms.shadowMatrix * uniforms.modelMatrix * instance.modelMatrix * vertexIn.position;

    return out;
}

float3 diffuseLighting(VertexOut in,
                       float3 baseColor,
                       float3 normalValue,
                       constant Material &material,
                       constant FragmentUniforms &fragmentUniforms,
                       constant Light *lights)
{
    float materialShininess = material.shininess;
    float3 materialSpecularColor = material.specularColor;
    float3 diffuseColor = 0;
    float3 ambientColor = 0;
    float3 specularColor = 0;

    // between 0 and 1 - This is a TBN Matrix. (search for tbn matrix in pdf)
    // tangents are generated by model IO and are relative to the model - not the normal map
    // Normal value takes the models normals & modifies them with the normal value created from the normal map


    // This is getting around the fact that these ground textures have a normal direction of
    // [0, 0, -1] - so any light facing -z would be black
    // -1z for a normal doesn't seem to make sense? But maybe the planes are getting rotated
    float3 normalDirection;
    if (hasNormalTexture) {
        normalDirection = float3x3(in.worldTangent, in.worldBitangent, in.worldNormal) * normalValue;
    } else {
        // Using the tangents multiplied by the value will reverse the normals if not using a normal map
        // For some GD reason
        normalDirection = normalValue;
    }

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
                // Commented out because I think this is 'light reflection off shininess' thing thats causing the light
                // But I don't get the same affecta s no sunlight...
                float specularIntensity = 0;//pow(saturate(dot(reflection, cameraPosition)), materialShininess);
                specularColor = light.specularColor * materialSpecularColor * specularIntensity;
            }

            float3 combinedColor = light.color * baseColor * diffuseIntensity * light.intensity;
            diffuseColor += combinedColor;

            // Use intensity of light to create general light
            // Removed this to only use intensity on light applied with sunlight - not like pointlight or anything
//            diffuseColor *= light.intensity;
        } else if (light.type == Ambientlight) {
            ambientColor += light.color * light.intensity;
        } else if (light.type == Pointlight) {
            // *** Light Bulb ***\\

            // distance between light and fragment
            float d = distance(light.position, in.worldPosition.xyz);

            // Vector direction between light & fragment
            float3 lightDirection = normalize(light.position - in.worldPosition.xyz);

            // Standard formula for curved light drop off (attenuation)
            float attenuation = 1.0 / (light.attenuation.x + light.attenuation.y * d + light.attenuation.z * d * d);

            // Angle between light direction & normal
            float diffuseIntensity = saturate(dot(lightDirection, normalDirection));

            // Color with out light drop off
            float3 color = light.color * baseColor * diffuseIntensity;

            // Light drop off
            color *= attenuation;

            diffuseColor += color;
        } else if (light.type == Spotlight) {

            //https://forums.raywenderlich.com/t/chapter-5-cone-direction/50705/2
            float d = distance(light.position, in.worldPosition.xyz);
            // Could be outside of the cone direction - This is really direction to the fragment
            // Could also negate this thing instead of cone direction
            float3 directionFromLightToFragment = normalize(light.position - in.worldPosition.xyz);

            // Inverting here to put the cone direction & light -> fragment pointing in opposite directions
            float3 coneDirection = normalize(-light.coneDirection);

            // Find angle (dot product) between direction from light to fragment & the direction of the cone
            float spotResult = dot(directionFromLightToFragment, coneDirection);
            float coneAngle = cos(light.coneAngle);
            if (spotResult > coneAngle) {
                // Standard formulat for attenuation
                float attenuation = 1.0 / (light.attenuation.x + light.attenuation.y * d + light.attenuation.z * d * d);

                // Adding attenuation for distance from center of the cone
                attenuation *= pow(spotResult, light.coneAttenuation);

                // Inverting the normal direction will flip the 'black section of the light '
                // When pointing backwards
                float dotProd = dot(directionFromLightToFragment, normalDirection);
                float diffuseIntensity = saturate(dotProd);
                float3 color = light.color * baseColor * diffuseIntensity;
                color *= attenuation;

                diffuseColor += color;
            }
        }
    }

    return diffuseColor + ambientColor + specularColor;

}

float4 distanceFog(float4 position, float4 color) {
    float distance = position.z / position.w;
    float density = 0.05;
    float fog = 1.0 - clamp(exp(-density * distance), 0.0, 1.0);
    float4 fogColor = float4(1.0);
    color = mix(color, fogColor, fog);
    return color;
}

float4 fogOFWar(float3 position, float4 color) {

    float d = distance(position, float3(0, 0, 0));

    if (d > 1) {
        color = float4(0);
    }

    return color;
}

float4 sepiaShader(float4 color) {

    float y = dot(float3(0.299, 0.587, 0.114), color.rgb);
    float4 sepia = float4(0.191, -0.054, -0.221, 0.0);
    float4 output = sepia + y;
    output.z = color.z;

    output = mix(output, color, 0.4);
    return output;
}

fragment float4 fragment_main(VertexOut in [[ stage_in ]],
                              constant Light *lights [[ buffer(BufferIndexLights) ]],
                              sampler textureSampler [[ sampler(0) ]],
                              constant Material &material [[ buffer(BufferIndexMaterials) ]],
                              constant FragmentUniforms &fragmentUniforms [[ buffer(BufferIndexFragmentUniforms) ]],
                              constant PropTextures &textures [[buffer(BufferIndexTextures)]],
                              texturecube<float> shadowColorTexture [[ texture(ShadowColorTexture) ]],
                              depthcube<float> shadowDepthTexture [[ texture(ShadowDepthTexture) ]],
                              constant float &farZ [[ buffer(24) ]],
                              constant uint &tiling [[ buffer(22) ]])

{
    float4 baseColor;
    // Uses function constants to check if the model
    // has map_kd aka Color texture.
    // Basically checks the submesh was able to load the texture in map_kd
    if (hasColorTextureArray) {
//        baseColor = textures.baseColorTextureArray.sample(textureSampler, in.uv, in.textureID);
    } else if (hasColorTexture) {
        baseColor = textures.baseColorTexture.sample(textureSampler, in.uv * tiling);
    } else {
        baseColor = float4(material.baseColor, 1);
    }

    float3 normalValue;
    // Compiler will remove these conditionals using the functionConstants
    if (hasNormalTexture) {
        // Use normal texture map values
        // get more fake shadow detail
        normalValue = textures.normalTexture.sample(textureSampler, in.uv * tiling).rgb;
        // makes value between 0 and 1
        normalValue = normalValue * 2 - 1;
    } else {
        // Just use the faces normal
        normalValue = in.worldNormal;
    }


    normalValue = normalize(normalValue);

    baseColor = distanceFog(in.position, baseColor);

    float3 color;

    if (includeLighting) {
        color = diffuseLighting(in, baseColor.xyz, normalValue, material, fragmentUniforms, lights);
    } else {
        color = baseColor.xyz;
    }


    if (lights[0].type == Spotlight) {
    
        // SPOTLIGHT SHADOW MAP
        // Commented out cause the texture is now a cube yo
        /*
        float2 xy = in.shadowPosition.xy / in.shadowPosition.w;
        xy = xy * 0.5 + 0.5;
        xy.y = 1 - xy.y;

        constexpr sampler s(coord::normalized, filter::linear, address::clamp_to_edge, compare_func:: less);
        float shadow_sample = shadowTexture.sample(s, xy); // failing cause its a cube yo
        float current_sample = in.shadowPosition.z / in.shadowPosition.w;

        if (current_sample > shadow_sample ) {
            color *= 0.5;
        }
         */

    } else if (lights[0].type == Pointlight) {
        constexpr sampler s(coord::normalized,
                            filter::linear,
                            address::clamp_to_edge,
                            compare_func:: less);

//        The vertex shader and fragment shader are largely similar to the original shadow mapping shaders: the differences being that the fragment shader no longer requires a fragment position in light space (shadow matrixz) as we can now sample the depth values using a direction vector.

        // Can I input the [[render_target_array_index]] here? I don't think so
        // I need to use shadow matrix instead of the world position
        // World position doesn't take into account the projection which we need you dumbass
        // so .w is always 1

        // shadow matrix -> matrix from point of view from light
        // Light space = shadow matrix !!!!

        Light light = lights[0];
//        float3 lightDirection = normalize(light.position - in.position.xyz);
////        lightDirection.y = 1 - lightDirection.y;
//
//        // Point light - not standard UV Coordinates - accessed with 3d vector
//        float shadow_sample = shadowTexture.sample(s, -lightDirection);
//
//        float lightDistance = in.position.z / in.position.w;
//        float attenuation = 1.0 / (light.attenuation.x + light.attenuation.y * d + light.attenuation.z * d * d);
////        float attenSample = shadow_sample /* attenuation*/;
//
//        if (lightDistance > shadow_sample) {
//            color *= 0.5;
//        }




        // Can probably use this once I figure out wtf im doing wrong...
//        T sample_compare(sampler s, float3 coord, float compare_value) const



        float3 fragToLight = in.worldPosition.xyz - light.position;

        float4 closestDepth = shadowColorTexture.sample(s, fragToLight);
        float currentDepth = distance(in.worldPosition.xyz, light.position);

//        closestDepth *= farZ;
        // This is probalby the intended way to handle this
        // This makes sense with the current epsilon value.
        // the other way - epsilon should be like 5.0 instead of 0.1
        currentDepth = currentDepth / farZ;

        float epsilon = 0.1;
        if (closestDepth.w + epsilon < currentDepth) {
            color *= 0.6;
        }

//        return float4(closestDepth, 1);
    }

//    float4 fogOFWar = fogOFWar(in.worldPosition.xyz, float4(color, 1));

    // Adding Sepia TONE - otherwise just return float4(color, 1)

//    discard_fragment();
//    return sepiaShader(float4(color, 1));
    return float4(color, 1);
}
