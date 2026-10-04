#version 440
// wallswitch slot vertex shader — passes local pixel coords to the fragment
// stage. Uniform block must mirror Wallswitch.qml's ShaderEffect properties:
// qt_Matrix + qt_Opacity first, then the custom uniforms in alphabetical
// order (Qt 6 ShaderEffect packing rule).
layout(location = 0) in vec4 qt_Vertex;
// present in Qt's quad mesh even though unused here — must be declared
layout(location = 1) in vec2 qt_TexCoord0;
layout(location = 0) out vec2 vPos;
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
    vPos = qt_Vertex.xy;
    gl_Position = qt_Matrix * qt_Vertex;
}
