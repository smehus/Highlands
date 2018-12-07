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

struct VertexIn {
    float4 position [[ attribute(0) ]];
    float3 normal [[ attribute(1) ]];
};

struct VertexOut {
    float4 position [[ position ]];
    float3 worldPosition;
    float3 worldNormal;
};

vertex VertexOut vertex_main(const VertexIn vertexIn [[ stage_in ]],
                          constant Uniforms & uniforms [[ buffer(1) ]]) {

    VertexOut out;
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * vertexIn.position;
    out.worldPosition = (uniforms.modelMatrix * vertexIn.position).xyz;
    out.worldNormal = uniforms.normalMatrix * vertexIn.normal;
    return out;
}

fragment float4 fragment_main(VertexOut in [[ stage_in ]],
                              constant Light *lights [[ buffer(2) ]],
                              constant FragmentUniforms &fragmentUniforms [[ buffer(3) ]])
{
    float3 baseColor = float3(1, 1, 1);

    float3 diffuseColor = 0;
    float3 ambientColor = 0;
    float3 specularColor = 0;
    float materialShininess = 32;
    float3 materialSpecularColor = float3(1, 1, 1);

    // between 0 and 1
    float3 normalDirection = normalize(in.worldNormal);

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
                float3 cameraPosition = normalize(in.worldPosition - fragmentUniforms.cameraPosition);
                float specularIntensity = pow(saturate(dot(reflection, cameraPosition)), materialShininess);
                specularColor = light.specularColor * materialSpecularColor * specularIntensity;
            }

            diffuseColor += light.color * baseColor * diffuseIntensity;
        } else if (light.type == Ambientlight) {
            ambientColor += light.color * light.intensity;
        } else if (light.type == Pointlight) {
            // *** Light Bulb ***\\

            // distance between light and fragment
            float d = distance(light.position, in.worldPosition);

            // Vector direction between light & fragment
            float3 lightDirection = normalize(light.position - in.worldPosition);

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

            float d = distance(light.position, in.worldPosition);
            // Could be outside of the cone direction - This is really direction to the fragment
            // Could also negate this thing instead of cone direction
            float3 directionFromLightToFragment = normalize(light.position - in.worldPosition);

            // Inverting here to put the cone direction & light -> fragment pointing in opposite directions
            float3 coneDirection = normalize(-light.coneDirection);

            // Find angle (dot product) between direction from light to fragment & the direction of the cone
            float spotResult = dot(directionFromLightToFragment, coneDirection);

            if (spotResult > cos(light.coneAngle)) {
                // Standard formulat for attenuation
                float attenuation = 1.0 / (light.attenuation.x + light.attenuation.y * d + light.attenuation.z * d * d);

                // Adding attenuation for distance from center of the cone
                attenuation *= pow(spotResult, light.coneAttenuation);
                float diffuseIntensity = saturate(dot(directionFromLightToFragment, normalDirection));
                float3 color = light.color * baseColor * diffuseIntensity;
                color *= attenuation;

                diffuseColor += color;
            }
        }
    }

    float3 color = diffuseColor + ambientColor + specularColor;
    return float4(color, 1);
}
