// Liquid glass lens for BackdropFilter (ImageFilter.shader, Impeller only).
//
// Refraction ported from SukiSU-Ultra's ui/component/liquid/Lens.kt, which is
// adapted from Kyant0/AndroidLiquidGlass (Apache License 2.0):
// https://github.com/Kyant0/AndroidLiquidGlass
//
// All coordinates are physical pixels of the render pass the backdrop filter
// runs in (the screen, for a widget that is not inside a save layer).

#include <flutter/runtime_effect.glsl>

precision highp float;

// set by the engine: size of the input texture
uniform vec2 uSize;
// glass bounds: left, top, width, height
uniform vec4 uRect;
// corner radii: top left, top right, bottom right, bottom left
uniform vec4 uRadii;
// how far from the edge the refraction reaches
uniform float uRefractionHeight;
// how far the content is pulled at the very edge
uniform float uRefractionAmount;
// 1.0 bends towards the center as well, like a thick lens
uniform float uDepthEffect;
// 0.0 disables the rgb dispersion
uniform float uChromaticAberration;
// 1.0 keeps the colors, > 1.0 makes them more vivid
uniform float uSaturation;

// set by the engine: the backdrop
uniform sampler2D uTexture;

out vec4 fragColor;

float radiusAt(vec2 coord, vec4 radii) {
  if (coord.x >= 0.0) {
    return coord.y <= 0.0 ? radii.y : radii.z;
  }
  return coord.y <= 0.0 ? radii.x : radii.w;
}

// signed distance to a rounded rect centered at the origin, < 0 inside
float sdRoundedRect(vec2 coord, vec2 halfSize, float radius) {
  vec2 cornerCoord = abs(coord) - (halfSize - vec2(radius));
  float outside = length(max(cornerCoord, 0.0)) - radius;
  float inside = min(max(cornerCoord.x, cornerCoord.y), 0.0);
  return outside + inside;
}

// direction in which the distance grows, i.e. the outward edge normal
vec2 gradSdRoundedRect(vec2 coord, vec2 halfSize, float radius) {
  vec2 cornerCoord = abs(coord) - (halfSize - vec2(radius));
  if (cornerCoord.x >= 0.0 || cornerCoord.y >= 0.0) {
    return sign(coord) * normalize(max(cornerCoord, 0.0));
  }
  float gradX = step(cornerCoord.y, cornerCoord.x);
  return sign(coord) * vec2(gradX, 1.0 - gradX);
}

// profile of a circular bevel: 0 in the flat middle, 1 at the very edge
float circleMap(float x) {
  return 1.0 - sqrt(1.0 - x * x);
}

vec4 sampleBackdrop(vec2 coord) {
  // The backdrop of a backdrop filter is upright on OpenGLES too: flipping
  // it, as for image samplers, mirrors the top of the screen into the glass.
  vec2 uv = coord / uSize;
  return texture(uTexture, uv);
}

vec4 vibrancy(vec4 color) {
  // premultiplied alpha: keep the channels within 0..alpha
  float luminance = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
  color.rgb = clamp(mix(vec3(luminance), color.rgb, uSaturation), 0.0, color.a);
  return color;
}

void main() {
  vec2 coord = FlutterFragCoord().xy;

  vec2 halfSize = uRect.zw * 0.5;
  vec2 centeredCoord = coord - uRect.xy - halfSize;
  float radius = radiusAt(centeredCoord, uRadii);

  float sd = sdRoundedRect(centeredCoord, halfSize, radius);
  if (uRefractionHeight <= 0.0 || -sd >= uRefractionHeight) {
    fragColor = vibrancy(sampleBackdrop(coord));
    return;
  }
  sd = min(sd, 0.0);

  // negative: sample from further inside, so the edge magnifies like a lens
  float d = circleMap(1.0 - -sd / uRefractionHeight) * -uRefractionAmount;
  float gradRadius = min(radius * 1.5, min(halfSize.x, halfSize.y));
  vec2 grad = normalize(
    gradSdRoundedRect(centeredCoord, halfSize, gradRadius) +
    uDepthEffect * normalize(centeredCoord)
  );
  vec2 refractedCoord = coord + d * grad;

  if (uChromaticAberration <= 0.0) {
    fragColor = vibrancy(sampleBackdrop(refractedCoord));
    return;
  }

  // split red and blue apart along the refraction direction
  float dispersion = uChromaticAberration *
    ((centeredCoord.x * centeredCoord.y) / (halfSize.x * halfSize.y));
  vec2 dispersedCoord = d * grad * dispersion;
  vec4 red = sampleBackdrop(refractedCoord + dispersedCoord);
  vec4 green = sampleBackdrop(refractedCoord);
  vec4 blue = sampleBackdrop(refractedCoord - dispersedCoord);
  fragColor = vibrancy(
    vec4(red.r, green.g, blue.b, (red.a + green.a + blue.a) / 3.0)
  );
}
