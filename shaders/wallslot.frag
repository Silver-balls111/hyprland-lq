#version 440
// wallswitch slot fragment shader — masks the slot to a parallelogram
// (shear about the vertical middle) with a 1px smoothstep on the slanted
// edges, then draws image + dim + accent border. This is the anti-aliasing:
// transformed-quad edges are rasterized hard (no window MSAA in Quickshell
// 0.3.1), so the slant must live in the shader, not in clip/transform.
layout(location = 0) in vec2 vPos;
layout(location = 0) out vec4 fragColor;
layout(binding = 1) uniform sampler2D uSrc;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float uBorder;
    float uBorderA;
    vec4 uBorderColor;
    float uDim;
    float uImgAspect;
    float uShear;
    vec2 uSize;
};
void main() {
    float aa = 1.0;
    // Matches the old Matrix4x4 (m12 = -k): left edge at kH/2 - k*y, i.e.
    // the TOP edge is displaced to the right = right-leaning. The mask
    // extends pad = kH/2 beyond the slot rect on both sides — the
    // ShaderEffect item must be widened by the same amount or the
    // overflowing half gets clipped to the rect (that WAS the bug).
    float pad = uShear * uSize.y * 0.5;
    float dL = vPos.x - pad + uShear * (vPos.y - uSize.y * 0.5);
    float dR = uSize.x - dL;
    float d = min(dL, dR);
    float inside = smoothstep(0.0, aa, d);
    if (inside <= 0.004) discard;
    // un-shear x and center-crop the image over the box
    vec2 q = vec2(dL / uSize.x, vPos.y / uSize.y);
    float boxA = uSize.x / uSize.y;
    if (boxA > uImgAspect) {
        q.y = (q.y - 0.5) * (uImgAspect / boxA) + 0.5;
    } else {
        q.x = (q.x - 0.5) * (boxA / uImgAspect) + 0.5;
    }
    vec3 rgb = texture(uSrc, q).rgb;
    rgb *= (1.0 - uDim);
    float dy = min(vPos.y, uSize.y - vPos.y);
    float bm = 1.0 - smoothstep(uBorder, uBorder + aa, min(d, dy));
    rgb = mix(rgb, uBorderColor.rgb, bm * uBorderA);
    // premultiplied alpha
    fragColor = vec4(rgb * inside, inside);
}
