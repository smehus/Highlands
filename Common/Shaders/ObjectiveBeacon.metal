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

fragment float4 objective_fragment(VertexOut in [[ stage_in ]],
                                   texture2d<float> maskTexture [[ texture(0) ]])
{
    // sample mask and check if beacon is inside mask
    // Then change color based on that

    float width = float(maskTexture.get_width() * 2.0);
    float height = float(maskTexture.get_height() * 2.0);
    float tx = in.position.x / width;
    float ty = in.position.y / height;

    constexpr sampler maskSampler(coord::normalized,
                                  filter::linear,
                                  address::clamp_to_edge,
                                  compare_func:: less
                                  );

    float4 sample = maskTexture.sample(maskSampler, float2(tx, ty));
    if (sample.r < 0.2) {
        return float4(0, 1, 0, 1);
    }

    return float4(1, 0, 0, 1);
}
