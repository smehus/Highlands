//
//  ObjectiveBeacon.metal
//  Highlands
//
//  Created by Scott Mehus on 6/7/20.
//  Copyright © 2020 Scott Mehus. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#import "Common.h"

struct VertexIn {
    float4 position [[ attribute(Position) ]];
};

struct VertexOut {
    float4 position [[ position ]];
};

vertex VertexOut objective_vertex(const VertexIn in [[ stage_in ]],
                                  constant Uniforms &uniforms [[ buffer(BufferIndexUniforms) ]])
{
    return {
        .position = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * in.position
    };
}

fragment float4 objective_fragment(VertexOut in [[ stage_in ]])
{
    return float4(1, 0, 0, 1);
}
