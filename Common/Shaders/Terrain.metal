//
//  Terrain.metal
//  Highlands
//
//  Created by Scott Mehus on 8/31/19.
//  Copyright © 2019 Scott Mehus. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#import "Common.h"

struct TerrainVertexOut {
    float4 position [[ position ]];
    float4 color;
};

struct ControlPoint {
    float4 position [[ attribute(0) ]];
};

float calc_distance(float3 pointA, float3 pointB,
                    float3 camera_position, float4x4 modelMatrix) {
    float3 positionA = (modelMatrix * float4(pointA, 1)).xyz;
    float3 positionB = (modelMatrix * float4(pointB, 1)).xyz;
    float3 midpoint = (positionA + positionB) * 0.5;
    float camera_distance = distance(camera_position, midpoint);
    return camera_distance;
}

kernel void tessellation_main(constant float* edge_factors [[ buffer(0) ]],
                              constant float* inside_factors [[ buffer(1) ]],
                              device MTLQuadTessellationFactorsHalf* factors [[ buffer(2) ]],
                              constant float4 &camera_position [[ buffer(3) ]],
                              constant float4x4 &modelMatrix   [[ buffer(4) ]],
                              constant float3* control_points  [[ buffer(5) ]],
                              constant TerrainParams &terrain        [[ buffer(6) ]],
                              uint pid [[ thread_position_in_grid ]])
{
    uint index = pid * 4;
    float totalTessellation = 0;

    for (int i = 0; i < 4; i++) {
        int pointAIndex = i;
        int pointBIndex = i + 1;
        if (pointAIndex == 3) {
            pointBIndex = 0;
        }
        int edgeIndex = pointBIndex;
        float cameraDistance = calc_distance(control_points[pointAIndex + index],
                                             control_points[pointBIndex + index],
                                             camera_position.xyz,
                                             modelMatrix);

        float tessellation = max(4.0, terrain.maxTessellation / cameraDistance);
        factors[pid].edgeTessellationFactor[edgeIndex] = tessellation;
        totalTessellation += tessellation;
    }

    factors[pid].insideTessellationFactor[0] = totalTessellation * 0.25;
    factors[pid].insideTessellationFactor[1] = totalTessellation * 0.25;
}

[[ patch(quad, 4) ]]
vertex TerrainVertexOut vertex_terrain(patch_control_point<ControlPoint> control_points [[ stage_in ]],
                                       constant Uniforms &uniforms [[ buffer(BufferIndexUniforms) ]],
                                       float2 patch_coord [[ position_in_patch ]],
                                       uint patchID [[ patch_id ]])
{
    float u = patch_coord.x;
    float v = patch_coord.y;

    TerrainVertexOut out;
    out.position = float4(u, v, 0, 1);
    out.color = float4(u, v, 0, 1);
    return out;
}

fragment float4 fragment_terrain(TerrainVertexOut in [[ stage_in ]])
{
    return in.color;
}
