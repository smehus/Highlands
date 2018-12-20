
#include <metal_stdlib>
using namespace metal;

#import "Common.h"

struct VertexIn {
    float4 position [[ attribute(Position) ]];
    float3 normal [[ attribute(Normal) ]];
    float2 uv [[ attribute(UV) ]];
    float3 tangent [[ attribute(Tangent) ]];
    float3 bitangent [[ attribute(Bitangent) ]];
    float4 color [[ attribute(Color) ]];
    ushort4 joints [[ attribute(Joints) ]];
    float4 weights [[ attribute(Weights) ]];
};

struct VertexOut {
    float4 position [[ position ]];
    float3 worldNormal;
};

vertex VertexOut character_vertex_main(const VertexIn vertexIn [[ stage_in ]],
                                       constant Uniforms &uniforms [[ buffer(BufferIndexUniforms) ]],
                                       constant float4x4 *jointMatrices [[ buffer(21) ]]) {

    VertexOut out;
    float4x4 modelMatrix = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix;

    float4 weights = vertexIn.weights;
    ushort4 joints = vertexIn.joints;
    float4x4 skinMatrix = weights.x * jointMatrices[joints.x] +
    weights.y * jointMatrices[joints.y] +
    weights.z * jointMatrices[joints.z] +
    weights.w * jointMatrices[joints.w];

    out.position = modelMatrix * skinMatrix *vertexIn.position;
    out.worldNormal = uniforms.normalMatrix * (skinMatrix * float4(vertexIn.normal, 1)).xyz;

    return out;
}

fragment float4 character_fragment_main(VertexOut in [[ stage_in ]],
                                        constant Material &material [[ buffer(BufferIndexMaterials) ]]) {
    float4 color;
    float3 normalDirection = normalize(in.worldNormal);
    float3 lightPosition = float3(1, 2, -2);
    float3 lightDirection = normalize(lightPosition);
    float nDotl = max(0.001, saturate(dot(normalDirection, lightDirection)));
    float3 diffuseColor = material.baseColor + pow(material.baseColor * nDotl,  3);
    color = float4(diffuseColor, 1);
    return color;
}
