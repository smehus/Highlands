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
    float4  position [[ attribute(0) ]];
    ushort4 joints [[ attribute(Joints) ]];
    float4  weights [[ attribute(Weights) ]];
};

struct DepthOut {
    float4  position [[ position ]];
    uint    transformID;
    uint    face [[render_target_array_index]];
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
            out.transformID = 0;

            return out;

        }

        return out;
    }
}

vertex DepthOut vertex_omni_depth(const VertexIn vertexIn [[ stage_in ]],
                                  uint instanceID [[ instance_id ]],
                                  constant Instances *instances [[ buffer(BufferIndexInstances) ]],
                                  constant Light &light [[ buffer(BufferIndexLights) ]],
                                  constant CubeMap *cubeMaps [[ buffer(BufferIndexCubeFaces) ]],
                                  constant InstanceParams *instanceParams [[ buffer(BufferIndexInstanceParams) ]],
                                  constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]]) {


    Instances instance = instances[instanceID];
    float4 worldPosition = uniforms.modelMatrix * instance.modelMatrix * vertexIn.position;

    DepthOut out;
    out.face = instance.viewportIndex;
    CubeMap map = cubeMaps[out.face];

    out.position =  map.faceViewMatrix * worldPosition;
    out.worldPos = worldPosition;
    // This instance id is the same value as the current render_target_array_index. Maybe take the instanceID & divide by 6? But somehow
    // get the instance value were looking for. Check the total amount of instances & divide by the amount of faces.
    // The instances probably are fucked because I'm passing along the shadowInstances & theres 6 instances for each actual
    // model instance.. So if value is between 0-5 transform = 1. value = 6-10: transform would equal 2. you get it.
    out.transformID = uint(instanceID / 6);

    return out;

}

fragment float4 fragment_depth(DepthOut in [[ stage_in ]],
                               constant ShadowFragmentUniforms *fragmentUniforms [[ buffer(9) ]],
                               constant float &Far [[ buffer(10) ]],
                               constant float &Near [[ buffer(11) ]],
                               constant Light &light [[ buffer(BufferIndexLights) ]]) {


//    if (in.face == 1) {
//        return float4(1, 0, 0, 1);
//    } else if (in.face == 4) {
//        return float4(0, 0, 1, 1);
//    }


    // idk if this will ever work
//    float3 lightDirection = light.position - in.worldPos.xyz;
//    if (abs(lightDirection.x) < 3 && abs(lightDirection.z) < 3 && lightDirection.y > 0.5) {
//        discard_fragment();img
//    }

//    // Vector direction between light & fragment
    float lightDistance = distance(in.worldPos.xyz, light.position);
//    float3 posone = fragmentUniforms[0].position;
//    float distanceone = abs(distance(posone, light.position));
//
//    float3 postwo = fragmentUniforms[1].position;
//    float distancetwo = abs(distance(postwo, light.position));

//    if (in.transformID == 0) {
//        return float4(0, 0, 0, 1);
//    } else {
//        return float4(1, 1, 1, 1);
//    }

    float3 nodePosition = fragmentUniforms[in.transformID].position;

    float lightDistanceToCenter = abs(distance(nodePosition, light.position));
    if (lightDistanceToCenter < 5.0) { return float4(1, 1, 1, 1); }

    lightDistance /= Far;

//    if (in.face == 1 || in.face == 0) {
//        return float4(lightDirection, 0, 0, lightDirection);
//    } else if (in.face == 4 || in.face == 5) {
//        return float4(0, 0, lightDirection, lightDirection);
//    } else {
//        return float4(0, lightDirection, 0, lightDirection);
//    }

    return float4(lightDistance);
}
