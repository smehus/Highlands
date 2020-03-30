
#ifndef Common_h
#define Common_h

#import <simd/simd.h>

typedef struct {
    vector_float2 size;
    float height;
    uint maxTessellation;
} TerrainParams;

typedef struct {
    vector_float3 topLeft;
    vector_float3 topRight;
    vector_float3 bottomLeft;
    vector_float3 bottomRight;
} Patch;

typedef struct {
    matrix_float4x4 modelMatrix;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 projectionMatrix;
    matrix_float3x3 normalMatrix;
    matrix_float4x4 shadowMatrix;
    matrix_float4x4 maskMatrix;
} Uniforms;

typedef enum {
    unused = 0,
    Sunlight = 1,
    Spotlight = 2,
    Pointlight = 3,
    Ambientlight = 4
} LightType;

typedef struct {
    matrix_float4x4 faceViewMatrix;
    vector_float3 direction;
    vector_float3 up;
} CubeMap;

typedef struct {
    vector_float3 position;  // for a sunlight, this is direction
    vector_float3 color;
    vector_float3 specularColor;
    float intensity;
    vector_float3 attenuation;
    LightType type;
    float coneAngle;
    vector_float3 coneDirection;
    float coneAttenuation;
} Light;

typedef struct {
    uint lightCount;
    vector_float3 cameraPosition;
    matrix_float4x4 lightProjectionMatrix;
    uint tiling;
} FragmentUniforms;

typedef enum {
    BufferIndexVertices = 0,
    BufferIndexUniforms = 11,
    BufferIndexLights = 12,
    BufferIndexFragmentUniforms = 13,
    BufferIndexMaterials = 14,
    BufferIndexInstances = 15,
    BufferIndexSkybox = 20,
    BufferIndexSkyboxDiffuse = 21,
    BufferIndexBRDFLut = 22,
    BufferIndexCubeFaces = 23,
    BufferIndexInstanceParams = 24,
    BufferIndexTextures = 25
} BufferIndices;

typedef enum {
    Position = 0,
    Normal = 1,
    UV = 2,
    Tangent = 3,
    Bitangent = 4,
    Color = 5,
    Joints = 6,
    Weights = 7
} Attributes;

typedef enum {
    BaseColorTexture = 0,
    NormalTexture = 1,
    RoughnessTexture = 2,
    ShadowColorTexture = 3,
    ShadowDepthTexture = 4,
    TerrainTextureBase = 5,
    TerrainTextureMiddle = 6,
    TerrainTextureTop = 7
} Textures;

struct Material {
    vector_float3 baseColor;
    vector_float3 specularColor;
    float roughness;
    float metalness;
    vector_float3 ambientOcclusion;
    float shininess;
};

struct Instances {
    matrix_float4x4 modelMatrix;
    matrix_float3x3 normalMatrix;
    uint textureID;
    uint viewportIndex;
};

typedef struct {
    uint viewportIndex;
} InstanceParams;

#endif /* Common_h */
