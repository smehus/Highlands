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

kernel void calculate_height(constant PatchPositions &patchPositions [[ buffer(0) ]],
                             device float &heightBuffer [[ buffer(1) ]],
                             constant TerrainParams &terrain [[ buffer(2) ]],
                             constant Uniforms &uniforms [[ buffer(3) ]],
                             constant float3 *control_points [[ buffer(4) ]],
                             constant Patch &patch [[ buffer(5) ]],
                             texture2d<float> heightMap [[ texture(0) ]])
{

    float4 lowerPosition  = float4(patchPositions.lowerPosition, 1.0);
    float4 upperPosition = float4(patchPositions.upperPosition, 1.0);

    // Percentage betweent two patch points
    float realU = (patchPositions.realPosition.x - lowerPosition.x) / (upperPosition.x - lowerPosition.x);
    float realV = (patchPositions.realPosition.z - lowerPosition.z) / (upperPosition.z - lowerPosition.z);


    //    The tessellator provides a uv coordinate between 0 and 1
    //    for the tessellated patch so that the vertex function can
    //    calculate its correct rendered position.

    // This obviously isn't between 0 & 1
    // Need to find what the percent value of position.x is between patch.topLeft & patch.topRight

    // -35    -2              107

//    -2 - -35 = 33
    // let b = 33 / (107 - -35)
    //


    // The interpolation shit from the book page: 316
    // Maybe i just need to figure out what the patch_coord means, since these are supposed to be patch_coord
    // Or watch that stupid youtube video again...



//    float topCameraDistance = calc_distance(patch.topLeft,
//                                         patch.topRight,
//                                         uniforms.viewMatrix.columns[2].xyz,
//                                         uniforms.modelMatrix);
//
//    float bottomCameraDistance = calc_distance(patch.bottomLeft,
//                                         patch.bottomRight,
//                                         uniforms.viewMatrix.columns[2].xyz,
//                                         uniforms.modelMatrix);

//    float topTesselation = max(4.0, terrain.maxTessellation / topCameraDistance);
//    float bottomTessllation = max(4.0, terrain.maxTessellation / bottomCameraDistance);


    // find the set postion from the vertices between patch control points // maxTesselation?

    // Do this in swift
//    float tessellationSegmentWidth = (patch.topRight.x - patch.topLeft.x) / terrain.maxTessellation;


    // this ends up being between 0 - 1
//    float lowerU = (lowerPosition.x - patch.topLeft.x) / (patch.topRight.x - patch.topLeft.x);
//    float lowerV = (lowerPosition.z - patch.bottomLeft.z) / (patch.topLeft.z - patch.bottomLeft.z);
//    float upperU = (upperPosition.x - patch.topLeft.x) / (patch.topRight.x - patch.topLeft.x);
//    float upperV = (upperPosition.z - patch.bottomLeft.z) / (patch.topLeft.z - patch.bottomLeft.z);

//    u = round(u * terrain.maxTessellation) / terrain.maxTessellation;
//    v = round(v * terrain.maxTessellation) / terrain.maxTessellation;

    // find the control point this position lives in
    // then interpolate like we do in the vertex function
    // 7 horizontal and 7 vertical
    // find control point by dividing by 7
    // I think I already do this in swift?

//    float3 topLeft = patch.topLeft;
//    float3 topRight = patch.topRight;
//    float3 bottomLeft = patch.bottomLeft;
//    float3 bottomRight = patch.bottomRight;

//    float2 top = mix(patch.topLeft.xz,
//                     patch.topRight.xz, lowerU);
//    float2 bottom = mix(patch.bottomLeft.xz,
//                        patch.bottomRight.xz, lowerU);
//
//    float2 interpolated = mix(bottom, top, lowerV);
    // - interpolated doesn't seeem to work
    // I need to check the interpolated position to make sure it makes sense compared to the
    // percentage between x's and y's
//    float4 interpolatedPosition = float4(interpolated.x, 0.0, interpolated.y, 1.0);
    float2 lowerXY = (lowerPosition.xz + terrain.size / 2.0) / terrain.size;
    constexpr sampler sample(filter::linear, address::repeat);
    float4 lowerColor = heightMap.sample(sample, lowerXY) + float4(0.3);
    float lowerHeight = (lowerColor.r * 2 - 1) * terrain.height;



//    float2 uppperTop = mix(patch.topLeft.xz,
//                     patch.topRight.xz, upperU);
//    float2 upperBottom = mix(patch.bottomLeft.xz,
//                        patch.bottomRight.xz, upperU);

//    float2 upperInterpolated = mix(upperBottom, uppperTop, upperV);
//    float4 upperInterpolatedPosition = float4(upperInterpolated.x, 0.0, upperInterpolated.y, 1.0);
    float2 upperXy = (upperPosition.xz + terrain.size / 2.0) / terrain.size;
    constexpr sampler upperSample(filter::linear, address::repeat);
    float4 upperColor = heightMap.sample(upperSample, upperXy) + float4(0.3);
    float upperHeight = (upperColor.r * 2 - 1) * terrain.height;

    float diff = (upperHeight - lowerHeight) / 2;
//    heightBuffer = lowerHeight + diff;

    // mix between two heights
//    heightBuffer = height;


    float diffU = (upperXy.x - lowerXY.x) * realU;
    float diffV = (upperXy.y - lowerXY.y) * realV;

    constexpr sampler s(filter::linear, address::repeat);
    float4 testcolor = heightMap.sample(s, float2(lowerXY.x + diffU, lowerXY.y + diffV)) + float4(0.3);

    float testheight = (testcolor.r * 2 - 1) * terrain.height;
    heightBuffer = testheight;



    g
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
        // This screws up the player height calculation - just use maxTessellation
        float cameraDistance = calc_distance(control_points[pointAIndex + index],
                                             control_points[pointBIndex + index],
                                             camera_position.xyz,
                                             modelMatrix);
        float tessellation = terrain.maxTessellation;//max(4.0, terrain.maxTessellation / cameraDistance);
        factors[pid].edgeTessellationFactor[edgeIndex] = tessellation;
        totalTessellation += tessellation;
    }
    factors[pid].insideTessellationFactor[0] = totalTessellation * 0.25;
    factors[pid].insideTessellationFactor[1] = totalTessellation * 0.25;
}



// this can set the height of the new vertices and alter the terrain
[[ patch(quad, 4) ]]
vertex TerrainVertexOut
vertex_terrain(patch_control_point<ControlPoint> control_points [[ stage_in ]],
               constant float4x4 &mvp [[buffer(1)]],
               uint patchID [[ patch_id ]],
               texture2d<float> heightMap [[ texture(0) ]],
               constant TerrainParams &terrain [[ buffer(6) ]],
               float2 patch_coord [[ position_in_patch ]])
{
//    The tessellator provides a uv coordinate between 0 and 1
//    for the tessellated patch so that the vertex function can
//    calculate its correct rendered position.
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

