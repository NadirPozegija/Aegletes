#include <metal_stdlib>
using namespace metal;

// Compute a 256-bin brightness histogram from an input texture.
// Each thread processes one pixel; we use atomics to accumulate counts.
kernel void lumaHistogramKernel(
    texture2d<float, access::read> inTexture  [[texture(0)]],
    device atomic_uint              *histogram [[buffer(0)]],
    uint2                            gid       [[thread_position_in_grid]]
) {
    uint width  = inTexture.get_width();
    uint height = inTexture.get_height();

    if (gid.x >= width || gid.y >= height) {
        return;
    }

    // Read pixel as linear RGBA in 0..1
    float4 color = inTexture.read(gid);

    // Compute luminance (Rec. 601 luma)
    float luma = dot(color.rgb, float3(0.299, 0.587, 0.114));
    luma = clamp(luma, 0.0f, 1.0f);

    // Map 0..1 to 0..255
    uint index = (uint)round(luma * 255.0f);
    if (index > 255u) {
        index = 255u;
    }

    atomic_fetch_add_explicit(&histogram[index], 1u, memory_order_relaxed);
}
