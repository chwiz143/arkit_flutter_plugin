//
//  Shader.metal
//  arcore_flutter_plugin
//
//  Created by 上江洲　智久 on 2020/03/24.
//

#include <metal_stdlib>
using namespace metal;

#include <SceneKit/scn_metal>

float3 desaturate(float3 color, float amount) {
    float3 gray = float3(dot(float3(0.2126, 0.7152, 0.0722), color));
    return float3(mix(color, gray, amount));
}

kernel void ChromaKeyFilter(texture2d<float, access::read> inTexture [[ texture(0) ]],
                            texture2d<float, access::write> outTexture [[ texture(1) ]],
                            const device float *colorRed [[ buffer(0) ]],
                            const device float *colorGreen [[ buffer(1) ]],
                            const device float *colorBlue [[ buffer(2) ]],
                            const device float *threshold [[ buffer(3) ]],
                            const device float *slope [[ buffer(4) ]],
                            const device float *mode [[ buffer(5) ]],
                            uint2 gid [[ thread_position_in_grid ]])
{
    int width = inTexture.get_width();
    int height = inTexture.get_height();
    float2 size = float2(width, height);
    float2 uv = float2(gid) / size;

    const float4 color = inTexture.read(gid);
    float4 outColor;
    const float3 keyColor = float3(*colorRed, *colorGreen, *colorBlue);

    if (*mode == 1) {
        float distance = abs(length(abs(keyColor - color.rgb)));
        float edge0 = *threshold * (1.0 - *slope);
        float alpha = smoothstep(edge0, *threshold, distance);
        color.rgb = desaturate(color.rgb, 1.0 - (alpha * alpha * alpha));

        outColor = alpha * float4(color.rgb, 1.0);
    } else if (*mode == 2) {
        float3 mask_color = inTexture.read(uint2(gid.x, height * (uv.y + 0.25) )).rgb;
        float distance = abs(length(abs(keyColor - mask_color.rgb)));
        float edge0 = *threshold * (1.0 - *slope);
        float alpha = smoothstep(edge0, *threshold, distance) * step(uv.y, 0.75) * step(0.25, uv.y);

        float3 temp_color = inTexture.read(uint2(gid.x, height * (uv.y - 0.25) )).rgb;
        color.rgb = desaturate(temp_color.rgb, 1.0 - (alpha * alpha * alpha));
        outColor = alpha * float4(color.rgb, 1.0);
    } else {
        outColor = float4(color.rgb, 1.0);
    }
    outTexture.write(outColor, gid);
}
