#version 440
// The bar ticker's vertex stage: the standard ShaderEffect one, with the same
// uniform block as ticker.frag (both stages must declare it identically).
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float offset;
    float period;
    float viewWidth;
    float fade;
};
void main() {
    qt_TexCoord0 = qt_MultiTexCoord0;
    gl_Position = qt_Matrix * qt_Vertex;
}
