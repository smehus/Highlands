#include <metal_stdlib>
using namespace metal;
#import "Common.h"

constant bool hasNormalTexture [[ function_constant(1) ]];

struct VertexIn {
    float4 position [[ attribute(Position) ]];
    float3 normal [[ attribute(Normal) ]];
    float2 uv [[ attribute(UV) ]];
//    float4 tangent [[ attribute(Tangent) ]];
//    float3 bitangent [[ attribute(Bitangent) ]];
    float4 color [[ attribute(Color) ]];
//    ushort4 joints [[ attribute(Joints) ]];
//    float4 weights [[ attribute(Weights) ]];
};

struct VertexOut {
    float4 position [[ position ]];
    float4 worldPosition;
    float3 worldNormal;
//    float3 worldTangent;
//    float3 worldBitangent;
    float2 uv;
};

vertex VertexOut character_vertex_main(const VertexIn vertexIn [[ stage_in ]],
                                       constant float4x4 *jointMatrices [[ buffer(21) ]],
                                       constant Uniforms &uniforms [[ buffer(BufferIndexUniforms) ]])
{
    VertexOut out;

    // skinning code
//    float4 weights = vertexIn.weights;
//    ushort4 joints = vertexIn.joints;
//    float4x4 skinMatrix =
//    weights.x * jointMatrices[joints.x] +
//    weights.y * jointMatrices[joints.y] +
//    weights.z * jointMatrices[joints.z] +
//    weights.w * jointMatrices[joints.w];

    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * /*skinMatrix **/ vertexIn.position;
    out.worldPosition = uniforms.modelMatrix /** skinMatrix*/ * vertexIn.position;
    out.worldNormal = uniforms.normalMatrix * (/*skinMatrix **/ float4(vertexIn.normal, 1)).xyz;
    out.uv = vertexIn.uv;


//    out.worldTangent = uniforms.normalMatrix * (skinMatrix * vertexIn.tangent).xyz;
//    float3 bitangent = cross(vertexIn.normal, vertexIn.tangent.xyz) * vertexIn.tangent.w;
//    out.worldBitangent = uniforms.normalMatrix * (skinMatrix * float4(bitangent, 1)).xyz;

    return out;
}


float3 characterDiffuseLighting(VertexOut in,
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

    // between 0 and 1 - This is a TBN Matrix. (search for tbn matrix in pdf)
    // tangents are generated by model IO and are relative to the model - not the normal map
    // Normal value takes the models normals & modifies them with the normal value created from the normal map


    // This is getting around the fact that these ground textures have a normal direction of
    // [0, 0, -1] - so any light facing -z would be black
    // -1z for a normal doesn't seem to make sense? But maybe the planes are getting rotated
    float3 normalDirection;
//    if (hasNormalTexture) {
//        normalDirection = float3x3(in.worldTangent, in.worldBitangent, in.worldNormal) * normalValue;
//    } else {
        // Using the tangents multiplied by the value will reverse the normals if not using a normal map
        // For some GD reason
        normalDirection = normalValue;
//    }

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
                float specularIntensity = pow(saturate(dot(reflection, cameraPosition)), materialShininess);
                specularColor = light.specularColor * materialSpecularColor * specularIntensity;
            }

            diffuseColor += light.color * baseColor * diffuseIntensity;
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


fragment float4 character_fragment_main(VertexOut in [[ stage_in ]],
                                        sampler textureSampler [[ sampler(0) ]],
                                        constant FragmentUniforms &fragmentUniforms [[ buffer(BufferIndexFragmentUniforms) ]],
                                        constant Light *lights [[ buffer(BufferIndexLights) ]],
                                        texture2d<float> baseColorTexture [[ texture(BaseColorTexture) ]],
                                        constant Material &material [[ buffer(BufferIndexMaterials) ]]) {

    constexpr sampler s(filter::linear);
    float3 baseColor = baseColorTexture.sample(s, in.uv).rgb;

    float3 color = characterDiffuseLighting(in, baseColor, normalize(in.worldNormal), material, fragmentUniforms, lights);
    return float4(color, 1);

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

