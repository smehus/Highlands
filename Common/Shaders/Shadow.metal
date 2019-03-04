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
};

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


            out.face = 4;

            CubeMap map = cubeMaps[out.face];

            float4 screenPos = map.faceViewMatrix * uniforms.modelMatrix * vertexIn.position;;
            out.position = screenPos;

            return out;

        }

        out.position = position;
        out.face = 0;


        return out;
    }
}
