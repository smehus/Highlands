#include <metal_stdlib>
using namespace metal;
#import "Common.h"

#import "Common.h"

constant bool hasSkeleton [[function_constant(5)]];


struct VertexIn {
  float4 position [[attribute(Position)]];
  float3 normal [[attribute(Normal)]];
  float2 uv [[attribute(UV)]];
  float3 tangent [[attribute(Tangent)]];
  float3 bitangent [[attribute(Bitangent)]];
  ushort4 joints [[attribute(Joints)]];
  float4 weights [[attribute(Weights)]];
};

struct VertexOut {
  float4 position [[position]];
  float3 worldPosition;
  float3 worldNormal;
  float3 worldTangent;
  float3 worldBitangent;
  float2 uv;
};

struct CharacterGbufferOut {
  float4 albedo [[color(0)]];
  float4 normal [[color(1)]];
  float4 position [[color(2)]];
};

vertex VertexOut character_vertex_main(const VertexIn vertexIn [[stage_in]],
                             constant float4x4 *jointMatrices [[buffer(22),
                                                                function_constant(hasSkeleton)]],
                             constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]])
{
  float4 position = vertexIn.position;
  float4 normal = float4(vertexIn.normal, 0);

  if (hasSkeleton) {
    float4 weights = vertexIn.weights;
    ushort4 joints = vertexIn.joints;
    position =
    weights.x * (jointMatrices[joints.x] * position) +
    weights.y * (jointMatrices[joints.y] * position) +
    weights.z * (jointMatrices[joints.z] * position) +
    weights.w * (jointMatrices[joints.w] * position);
    normal =
    weights.x * (jointMatrices[joints.x] * normal) +
    weights.y * (jointMatrices[joints.y] * normal) +
    weights.z * (jointMatrices[joints.z] * normal) +
    weights.w * (jointMatrices[joints.w] * normal);
  }

  VertexOut out {
    .position = uniforms.projectionMatrix * uniforms.viewMatrix
    * uniforms.modelMatrix * position,
    .worldPosition = (uniforms.modelMatrix * position).xyz,
    .worldNormal = uniforms.normalMatrix * normal.xyz,
    .worldTangent = 0,
    .worldBitangent = 0,
    .uv = vertexIn.uv
  };
  return out;
}

float4 characterFog(float4 position, float4 color) {
    float distance = position.z / position.w;
    float density = 0.2;
    float fog = 1.0 - clamp(exp(-density * distance), 0.0, 1.0);
    float4 fogColor = float4(1.0);
    color = mix(color, fogColor, fog);
    return color;
}

float4 sepiaShaderCharacter(float4 color) {

    float y = dot(float3(0.299, 0.587, 0.114), color.rgb);
    float4 sepia = float4(0.191, -0.054, -0.221, 0.0);
    float4 output = sepia + y;
    output.z = color.z;

    output = mix(output, color, 0.4);
    return output;
}

fragment CharacterGbufferOut character_fragment_main(VertexOut in [[ stage_in ]],
                                        sampler textureSampler [[ sampler(0) ]],
                                        constant FragmentUniforms &fragmentUniforms [[ buffer(BufferIndexFragmentUniforms) ]],
                                        constant Light *lights [[ buffer(BufferIndexLights) ]],
                                        texture2d<float> baseColorTexture [[ texture(BaseColorTexture) ]],
                                        // currently using omnidirectional shadow map : texturecube
//                                        texture2d<float> shadowTexture [[ texture(ShadowColorTexture) ]],
                                        constant Material &material [[ buffer(BufferIndexMaterials) ]]) {



    float3 baseColor;
    constexpr sampler s(filter::linear);
    float4 textureColor = baseColorTexture.sample(s, in.uv);
    baseColor = textureColor.rgb;
    float3 color = baseColor;

    /*
     This is for non omnidiretional shadow maps
     simply grabbing the fragment coordinates out of shadow map and
     crosschecking with shadow in position.
    constexpr sampler shadowSample(coord::normalized, filter::linear, address::clamp_to_edge, compare_func:: less);

     float2 xy = in.shadowPosition.xy;
     xy = xy * 0.5 + 0.5;
     xy.y = 1 - xy.y;

    float shadow_sample = shadowTexture.sample(shadowSample, xy);
    float current_sample = in.shadowPosition.z / in.shadowPosition.w;

    if (current_sample > shadow_sample ) {
//        color *= 0.5;
    }

     */

    CharacterGbufferOut out;
    out.albedo = float4(color, 0);
    out.normal = float4(normalize(in.worldNormal), 1.0);
    out.position = float4(in.worldPosition, 1.0);
    
//    return sepiaShaderCharacter(float4(color, 1));
    return out;

//
//    float4 color;
//
//    float3 normalDirection = normalize(in.worldNormal);
//    float3 lightPosition = float3(1, 2, -2);
//    float3 lightDirection = normalize(lightPosition);
//    float nDotl = max(0.001, saturate(dot(normalDirection, lightDirection)));
//    float3 diffuseColor = baseColor + pow(baseColor * nDotl,  3);
//    color = float4(diffuseColor, 1);
//    return color;

}

