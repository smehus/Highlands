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
    float4 worldPosition;
    float3 worldNormal;
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

kernel void calculate_height(constant float3 &in_position [[ buffer(0) ]],
                             device float *heightBuffer [[ buffer(1) ]],
                             constant TerrainParams &terrain [[ buffer(2) ]],
                             constant Uniforms &uniforms [[ buffer(3) ]],
                             constant float3 *control_points [[ buffer(4) ]],
                             constant Patch &patch [[ buffer(5) ]],
                             constant int &buffer_id [[ buffer(6) ]],
                             texture2d<float> heightMap [[ texture(0) ]])
{

    float4 position  = float4(in_position, 1.0);
    float u = (position.x - patch.topLeft.x) / (patch.topRight.x - patch.topLeft.x);
    float v = (position.z - patch.bottomLeft.z) / (patch.topLeft.z - patch.bottomLeft.z);

    float2 top = mix(patch.topLeft.xz,
                     patch.topRight.xz, u);
    float2 bottom = mix(patch.bottomLeft.xz,
                        patch.bottomRight.xz, u);

    float2 interpolated = mix(bottom, top, v);

    float4 interpolatedPosition = float4(interpolated.x, 0.0, interpolated.y, 1.0);
    float2 xy = (interpolatedPosition.xz + terrain.size / 2.0) / terrain.size;

    constexpr sampler sample(filter::linear, address::repeat);
    float4 color = heightMap.sample(sample, xy) + float4(0.3);
    float height = (color.r * 2 - 1) * terrain.height;
    heightBuffer[buffer_id] = height;
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


// This is pulled directly from apples example: DynamicTerrainWithArgumentBuffers
kernel void TerrainKnl_ComputeNormalsFromHeightmap(texture2d<float> height [[texture(0)]],
                                                   texture2d<float, access::write> normal [[texture(1)]],
                                                   constant TerrainParams &terrain [[ buffer(3) ]],
                                                   uint2 tid [[thread_position_in_grid]])
{
    constexpr sampler sam(min_filter::nearest, mag_filter::nearest, mip_filter::none,
                          address::clamp_to_edge, coord::pixel);

//    float xz_scale = TERRAIN_SCALE / height.get_width();
    float xz_scale = terrain.size.x + terrain.size.y;
    float y_scale = terrain.height;

    if (tid.x < height.get_width() && tid.y < height.get_height()) {
        float h_up     = height.sample(sam, (float2)(tid + uint2(0, 1))).r;
        float h_down   = height.sample(sam, (float2)(tid - uint2(0, 1))).r;
        float h_right  = height.sample(sam, (float2)(tid + uint2(1, 0))).r;
        float h_left   = height.sample(sam, (float2)(tid - uint2(1, 0))).r;
        float h_center = height.sample(sam, (float2)(tid + uint2(0, 0))).r;

        float3 v_up    = float3( 0,        (h_up    - h_center) * y_scale,  xz_scale);
        float3 v_down  = float3( 0,        (h_down  - h_center) * y_scale, -xz_scale);
        float3 v_right = float3( xz_scale, (h_right - h_center) * y_scale,  0);
        float3 v_left  = float3(-xz_scale, (h_left  - h_center) * y_scale,  0);

        float3 n0 = cross(v_up, v_right);
        float3 n1 = cross(v_left, v_up);
        float3 n2 = cross(v_down, v_left);
        float3 n3 = cross(v_right, v_down);

        float3 n = normalize(n0 + n1 + n2 + n3) * 0.5f + 0.5f;

        normal.write(float4(n.xzy, 1), tid);
    }
}


// this can set the height of the new vertices and alter the terrain
[[ patch(quad, 4) ]]
vertex TerrainVertexOut
vertex_terrain(patch_control_point<ControlPoint> control_points [[ stage_in ]],
               constant Uniforms &uniforms [[buffer(1)]],
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

    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * position;
    out.worldPosition = uniforms.modelMatrix * position;
//    out.worldNormal = uniforms.normalMatrix;
    out.uv = xy;
    out.height = height;
    return out;
}

float3 terrainDiffuseLighting(TerrainVertexOut in,
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

    float3 normalDirection = normalValue;
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

fragment float4 fragment_terrain(TerrainVertexOut in [[ stage_in ]],
                                 constant FragmentUniforms &fragmentUniforms [[ buffer(BufferIndexFragmentUniforms) ]],
                                 texture2d<float> cliffTexture [[ texture(TerrainTextureBase) ]],
                                 texture2d<float> snowTexture  [[ texture(TerrainTextureMiddle) ]],
                                 texture2d<float> grassTexture [[ texture(TerrainTextureTop) ]],
                                 texture2d<float> normalMap [[ texture(TerrainNormalMapTexture) ]])
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

    constexpr sampler sam(min_filter::linear, mag_filter::linear, mip_filter::nearest);

    float3 normal = normalize(normalMap.sample(sam, in.uv).xzy * 2.0f - 1.0f);

    return color;
//    return terrainDiffuseLighting(in, color, <#float3 normalValue#>, <#const constant Material &material#>, <#const constant FragmentUniforms &fragmentUniforms#>, <#const constant Light *lights#>)
}

