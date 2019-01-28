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
vertex float4 vertex_depth(const VertexIn vertexIn [[ stage_in ]],
                           constant Instances *instances [[ buffer(BufferIndexInstances), function_constant(isInstanced) ]],
                           uint instanceID [[ instance_id, function_constant(isInstanced) ]],
                           constant float4x4 *jointMatrices [[ buffer(21), function_constant(isSkinnedModel) ]],
                           constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]]) {

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

        return position;
    } else {
        matrix_float4x4 mvp = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix;
        float4 position = mvp * vertexIn.position;

        return position;
    }
}


