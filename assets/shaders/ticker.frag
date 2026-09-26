#version 440
// The bar ticker (components/Ticker.qml): one copy of the line, rendered once
// into `source`, scrolled by `offset` pixels and repeated every `period`
// pixels, and faded out over `fade` pixels at each end. Scrolling changes one
// uniform -- no text is laid out or redrawn, and no offscreen pass is made.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float offset;     // pixels scrolled, whole
    float period;     // the line's width in pixels (the source's width)
    float viewWidth;  // the ticker's width in pixels
    float fade;       // the fade at each end, in pixels
};
layout(binding = 1) uniform sampler2D source;
void main() {
    float x = qt_TexCoord0.x * viewWidth;
    float u = mod(x + offset, period) / period;
    vec4 c = texture(source, vec2(u, qt_TexCoord0.y));
    float a = clamp(x / max(fade, 1.0), 0.0, 1.0) * clamp((viewWidth - x) / max(fade, 1.0), 0.0, 1.0);
    fragColor = c * (a * qt_Opacity);
}
