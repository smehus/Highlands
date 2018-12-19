
#include <metal_stdlib>
using namespace metal;

#import "Common.h"

struct VertexIn {
  float4 position [[ attribute(Position) ]];
  float3 normal [[ attribute(Normal) ]];
  float2 uv [[ attribute(UV) ]];
  float3 tangent [[ attribute(Tangent) ]];
  float3 bitangent [[ attribute(Bitangent) ]];
};

struct VertexOut {
  float4 position [[ position ]];
  float3 worldNormal;
};

vertex VertexOut character_vertex_main(const VertexIn vertexIn [[ stage_in ]], constant Uniforms &uniforms [[ buffer(BufferIndexUniforms) ]]) {

  VertexOut out;
  float4x4 modelMatrix = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix;

  // add skinning code here
  
  out.position = modelMatrix * vertexIn.position;
  out.worldNormal = uniforms.normalMatrix * vertexIn.normal;

  return out;
}
