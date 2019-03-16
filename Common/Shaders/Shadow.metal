//
//  Shadow.metal
//  Highlands
//
//  Created by Scott Mehus on 1/26/19.
//  Copyright © 2019 Scott Mehus. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#import "../Shaders/Common.h"

constant bool isSkinnedModel [[ function_constant(0) ]];
constant bool isInstanced [[ function_constant(1) ]];

struct VertexIn {
    float4 position [[ attribute(0) ]];
    ushort4 joints [[ attribute(Joints) ]];
    float4 weights [[ attribute(Weights) ]];
};

struct DepthOut {
    float4 position [[ position ]];
    uint   face [[render_target_array_index]];
    float4  worldPos;
};

// gotta deal with instancing herer
vertex DepthOut vertex_depth(const VertexIn vertexIn [[ stage_in ]],
                             constant Instances *instances [[ buffer(BufferIndexInstances), function_constant(isInstanced) ]],
                             uint instanceID [[ instance_id ]],
                             constant float4x4 *jointMatrices [[ buffer(21), function_constant(isSkinnedModel) ]],
                             constant Light &light [[ buffer(BufferIndexLights) ]],
                             constant CubeMap *cubeMaps [[ buffer(BufferIndexCubeFaces) ]],
                             constant InstanceParams *instanceParams [[ buffer(BufferIndexInstanceParams) ]],
                             constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]]) {

    DepthOut out;
    if (isSkinnedModel) {
        // skinning code
        float4 weights = vertexIn.weights;
        ushort4 joints = vertexIn.joints;
        float4x4 skinMatrix =
        weights.x * jointMatrices[joints.x] +
        weights.y * jointMatrices[joints.y] +
        weights.z * jointMatrices[joints.z] +
        weights.w * jointMatrices[joints.w];

        matrix_float4x4 mvp = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * skinMatrix;
        float4 position = mvp * vertexIn.position;

        out.position = position;
        out.face = 0;

        return out;
    } else {

        matrix_float4x4 mvp = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix;
        float4 position = mvp * vertexIn.position;
        float4 worldPosition = uniforms.modelMatrix * vertexIn.position;

        float3 directionFromLightToFragment = normalize(light.position - worldPosition.xyz);

        if (light.type == Spotlight) {
            float3 tConeDirection = light.coneDirection;
            float3 coneDirection = normalize(-tConeDirection);
            float spotResult = dot(directionFromLightToFragment, coneDirection);
            float coneAngle = cos(light.coneAngle);


            if (spotResult < coneAngle) {
                position = position.xyww;
            }
        } else if (light.type == Pointlight) {

            out.face = instanceParams[instanceID].viewportIndex;
            CubeMap map = cubeMaps[out.face];

            out.position =  map.faceViewMatrix * worldPosition;
            out.worldPos = worldPosition;

            return out;

        }

        return out;
    }
}

vertex DepthOut vertex_omni_depth(const VertexIn vertexIn [[ stage_in ]],
                             uint instanceID [[ instance_id ]],
                             constant Light &light [[ buffer(BufferIndexLights) ]],
                             constant CubeMap *cubeMaps [[ buffer(BufferIndexCubeFaces) ]],
                             constant InstanceParams *instanceParams [[ buffer(BufferIndexInstanceParams) ]],
                             constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]]) {

    float4 position = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * vertexIn.position;
    float4 worldPosition = uniforms.modelMatrix * vertexIn.position;

    DepthOut out;
    out.face = instanceParams[instanceID].viewportIndex;
    CubeMap map = cubeMaps[out.face];

    out.position =  map.faceViewMatrix * worldPosition;
    out.worldPos = worldPosition;

    return out;

}

fragment float4 fragment_depth(DepthOut in [[ stage_in ]],
                               constant float &Far [[ buffer(10) ]],
                               constant float &Near [[ buffer(11) ]],
                               constant Light &light [[ buffer(BufferIndexLights) ]]) {


//    if (in.face == 1) {
//        return float4(1, 0, 0, 1);
//    } else if (in.face == 4) {
//        return float4(0, 0, 1, 1);
//    }

//    // Vector direction between light & fragment
    float lightDirection = distance(in.worldPos.xyz, light.position);
    lightDirection /= Far;

//    if (in.face == 1 || in.face == 0) {
//        return float4(lightDirection, 0, 0, lightDirection);
//    } else if (in.face == 4 || in.face == 5) {
//        return float4(0, 0, lightDirection, lightDirection);
//    } else {
//        return float4(0, lightDirection, 0, lightDirection);
//    }

    return float4(lightDirection);
}
