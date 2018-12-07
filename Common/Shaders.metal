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
    float3 baseColor = float3(0, 0, 1);

    float3 diffuseColor = 0;
    float3 ambientColor = 0;

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
            diffuseColor += light.color * baseColor * diffuseIntensity;
        } else if (light.type == Ambientlight) {
            ambientColor += light.color * light.intensity;
        }
    }

    float3 color = diffuseColor + ambientColor;
    return float4(color, 1);
}
