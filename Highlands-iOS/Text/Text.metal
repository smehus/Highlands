//
//  Text.metal
//  
//
//  Created by Scott Mehus on 4/13/20.
//

#include <metal_stdlib>
using namespace metal;
#import "Common.h"

struct VertexIn {
    float4 position [[ attribute(Position) ]]
    float2 uv [[ attribute(UV) ]];
}

struct VertexOut {
    float4 position [[ position ]]
}

vertex VertexOut vertex_text(const VertexIn vertex_in [[ stage_in ]], constant Uniforms &uniforms [[ buffer(BufferIndexUniforms) ]])
{
    return {
        .position = vertex_in.position
    }
}

fragment float4 fragment_text(VertexOut vertex_in [[ stage_in ]]) {
    return float4(1, 1, 1, 1);
}
