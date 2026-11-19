// A blurred backdrop that fades out away from a bar (ImageFilter.shader,
// Impeller only). The blur itself is the inner filter; this shader only
// multiplies the result by a vertical alpha ramp, so the haze eases into the
// page instead of stopping at a line.
//
// All coordinates are physical pixels of the render pass the backdrop filter
// runs in, as in liquid_glass_lens.frag.

#include <flutter/runtime_effect.glsl>

precision highp float;

// set by the engine: size of the input texture
uniform vec2 uSize;
// the band's bounds: left, top, width, height
uniform vec4 uRect;
// how far the blur stays at full strength, from the band's edge
uniform float uHold;
// how far it then fades out
uniform float uFade;
// 1.0: measured from the band's top, 0.0: from its bottom
uniform float uFromTop;

// set by the engine: the backdrop
uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
  vec2 coord = FlutterFragCoord().xy;
  vec4 color = texture(uTexture, coord / uSize);

  float d = uFromTop > 0.5
      ? coord.y - uRect.y
      : (uRect.y + uRect.w) - coord.y;
  float a = 1.0 - clamp((d - uHold) / max(uFade, 1.0), 0.0, 1.0);

  // premultiplied, so scaling every channel fades it out evenly
  fragColor = color * a;
}
