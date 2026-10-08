#include <flutter/runtime_effect.glsl>
uniform vec2 u_size;
uniform vec3 u_coral;
uniform vec3 u_blue;
uniform vec4 u_blob0;
uniform vec4 u_blob1;
uniform vec4 u_blob2;
uniform vec4 u_blob3;
uniform vec4 u_blob4;
uniform vec4 u_blob5;
uniform vec4 u_blob6;
uniform vec4 u_blob7;
uniform vec4 u_blob8;
uniform vec4 u_blob9;
uniform vec4 u_blob10;
uniform vec4 u_blob11;

out vec4 fragColor;
void addBlob(vec2 p, vec4 blob, inout float coral, inout float blue) {
  vec2 delta = p - blob.xy;
  delta.y *= 0.88;
  float distanceSquared = dot(delta, delta);
  float radiusSquared = blob.z * blob.z;
  // Compact, smooth support prevents distant blobs from tugging the whole panel
  // when they respawn, and avoids an abrupt threshold at the edge of influence.
  float influence = 1.0 - smoothstep(
      4.0 * radiusSquared + 0.000001,
      9.0 * radiusSquared + 0.000002, distanceSquared);
  float field = radiusSquared / max(distanceSquared, 0.0001) * influence;
  coral += field * (1.0 - blob.w);
  blue += field * blob.w;
}
void main() {
  vec2 p = FlutterFragCoord().xy / min(u_size.x, u_size.y);
  float coral = 0.0;
  float blue = 0.0;
  addBlob(p, u_blob0, coral, blue);
  addBlob(p, u_blob1, coral, blue);
  addBlob(p, u_blob2, coral, blue);
  addBlob(p, u_blob3, coral, blue);
  addBlob(p, u_blob4, coral, blue);
  addBlob(p, u_blob5, coral, blue);
  addBlob(p, u_blob6, coral, blue);
  addBlob(p, u_blob7, coral, blue);
  addBlob(p, u_blob8, coral, blue);
  addBlob(p, u_blob9, coral, blue);
  addBlob(p, u_blob10, coral, blue);
  addBlob(p, u_blob11, coral, blue);

  float field = coral + blue;
  float body = smoothstep(0.92, 1.12, field);
  float glow = smoothstep(0.12, 1.0, field) * 0.12;
  vec3 color = mix(u_coral, u_blue, blue / max(field, 0.0001));
  float light = 0.76 + 0.24 * smoothstep(1.0, 3.8, field);
  float alpha = body * 0.88 + glow * (1.0 - body);
  fragColor = vec4(color * light * alpha, alpha);
}
