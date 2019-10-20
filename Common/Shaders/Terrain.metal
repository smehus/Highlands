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
    float height;
    float2 uv;
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

kernel void calculate_heigeht(constant float3 &in_position [[ buffer(0) ]],
                              device float &heightBuffer [[ buffer(1) ]],
                              constant TerrainParams &terrain [[ buffer(2) ]],
                              constant Uniforms &uniforms [[ buffer(3) ]],
                              texture2d<float> heightMap [[ texture(0) ]])
{

    float4 position  = float4(in_position, 1.0);

    float2 xy = (position.xz + terrain.size / 2.0) / terrain.size;

    constexpr sampler s(filter::linear, address::repeat);
    float4 color = heightMap.sample(s, xy) + float4(0.3);

    float height = (color.r * 2 - 1) * terrain.height;
    heightBuffer = height;
}

// This is just creating new vertices
kernel void tessellation_main(constant float* edge_factors      [[ buffer(0) ]],
                              constant float* inside_factors   [[ buffer(1) ]],
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



// this can set the height of the new vertices and alter the terrain
[[ patch(quad, 4) ]]
vertex TerrainVertexOut
vertex_terrain(patch_control_point<ControlPoint>
               control_points [[ stage_in ]],
               constant float4x4 &mvp [[buffer(1)]],
               uint patchID [[ patch_id ]],
               texture2d<float> heightMap [[ texture(0) ]],
               constant TerrainParams &terrain [[ buffer(6) ]],
               float2 patch_coord [[ position_in_patch ]])
{
    float u = patch_coord.x;
    float v = patch_coord.y;

    float2 top = mix(control_points[0].position.xz,
                     control_points[1].position.xz, u);
    float2 bottom = mix(control_points[3].position.xz,
                        control_points[2].position.xz, u);

    TerrainVertexOut out;
    float2 interpolated = mix(top, bottom, v);
    float4 position = float4(interpolated.x, 0.0, interpolated.y, 1.0);

    float2 xy = (position.xz + terrain.size / 2.0) / terrain.size;
    constexpr sampler sample;
    float4 color = heightMap.sample(sample, xy) + float4(0.3);

    out.color = float4(color.r);

    float height = (color.r * 2 - 1) * terrain.height;
    position.y = height;

    out.position = mvp * position;
    out.uv = xy;
    out.height = height;
    return out;
}

fragment float4 fragment_terrain(TerrainVertexOut in [[ stage_in ]],
                                 constant FragmentUniforms &fragmentUniforms [[ buffer(BufferIndexFragmentUniforms) ]],
                                 texture2d<float> cliffTexture [[ texture(TerrainTextureBase) ]],
                                 texture2d<float> snowTexture  [[ texture(TerrainTextureMiddle) ]],
                                 texture2d<float> grassTexture [[ texture(TerrainTextureTop) ]])
{
    //    return in.color;

    constexpr sampler sample(filter::linear, address::repeat);
    float tiling = 16.0;
    float4 color;
    if (in.height < -0.5) {
        color = grassTexture.sample(sample, in.uv * tiling);
    } else if (in.height < 5.0) {
        color = cliffTexture.sample(sample, in.uv * tiling);
    } else {
        color = snowTexture.sample(sample, in.uv * tiling);
    }
    return color;
}

