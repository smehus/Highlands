#include <metal_stdlib>
using namespace metal;
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

vertex VertexOut character_vertex_main(const VertexIn vertexIn [[stage_in]],
                             constant float4x4 *jointMatrices [[buffer(21),
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

