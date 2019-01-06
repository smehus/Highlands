#include <metal_stdlib>
using namespace metal;
#import "Common.h"

struct VertexIn {
    float4 position [[ attribute(Position) ]];
    float3 normal [[ attribute(Normal) ]];
    float2 uv [[ attribute(UV) ]];
    float3 tangent [[ attribute(Tangent) ]];
    float3 bitangent [[ attribute(Bitangent) ]];
//    float4 color [[ attribute(Color) ]];
    ushort4 joints [[ attribute(Joints) ]];
    float4 weights [[ attribute(Weights) ]];
};

struct VertexOut {
    float4 position [[ position ]];
    float3 worldNormal;
//    float2 uv;
};

vertex VertexOut character_vertex_main(const VertexIn vertexIn [[ stage_in ]],
                                       constant float4x4 *jointMatrices [[ buffer(21) ]],
                                       constant Uniforms &uniforms [[ buffer(BufferIndexUniforms) ]])
{
    VertexOut out;
    float4x4 modelMatrix = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix;

    // skinning code
    float4 weights = vertexIn.weights;
    ushort4 joints = vertexIn.joints;
    float4x4 skinMatrix =
    weights.x * jointMatrices[joints.x] +
    weights.y * jointMatrices[joints.y] +
    weights.z * jointMatrices[joints.z] +
    weights.w * jointMatrices[joints.w];

    out.position = modelMatrix * skinMatrix * vertexIn.position;
    out.worldNormal = uniforms.normalMatrix *
    (skinMatrix * float4(vertexIn.normal, 1)).xyz;
//    out.uv = vertexIn.uv;

    return out;
}

fragment float4 character_fragment_main(VertexOut in [[ stage_in ]],
                                        sampler textureSampler [[ sampler(0) ]],
                                        texture2d<float> baseColorTexture [[ texture(BaseColorTexture) ]],
                                        constant Material &material [[ buffer(BufferIndexMaterials) ]]) {


    float4 color;
    constexpr sampler s(filter::linear);
//    float4 baseColor = baseColorTexture.sample(s, in.uv);
    float4 baseColor = float4(material.baseColor, 1);
    
    if (baseColor.a < 0.1) {
        discard_fragment();
    }

    if (baseColor.r == 0 && baseColor.g == 0 && baseColor.b == 0) {
        discard_fragment();
    }


    

//    float3 normalDirection = normalize(in.worldNormal);
//    float3 lightPosition = float3(1, 2, -2);
//    float3 lightDirection = normalize(lightPosition);
//    float nDotl = max(0.001, saturate(dot(normalDirection, lightDirection)));
//    float3 diffuseColor = baseColor + pow(baseColor * nDotl,  3);

    return baseColor;
}

