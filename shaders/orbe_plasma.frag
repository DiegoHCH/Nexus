// El orbe de plasma, el mismo del mockup del escenario
// (`nexus-orbe-plasma.html`), pasado al dialecto de `FragmentProgram`.
//
// Remolino de fbm con torsión de dominio, hebras con cresta, un núcleo que
// quema en blanco y un fundido al borde de la ventana para que nunca se vea el
// cuadrado. La salida va premultiplicada, como la espera Flutter.
//
// 🔴 **El orden de los uniforms es el contrato con Dart**: se fijan por índice
// en `NexusOrbPlasmaPainter`, y un `vec3` ocupa tres. Cambiar uno de sitio aquí
// sin cambiarlo allí no da error: da otro orbe.
#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2  uRes;       // 0, 1
uniform float uTime;      // 2
uniform float uAngle;     // 3
uniform vec3  uColor;     // 4, 5, 6
uniform float uLight;     // 7
uniform float uIntensity; // 8
uniform float uWarp;      // 9
uniform float uScale;     // 10
uniform float uSharp;     // 11
uniform float uCore;      // 12
uniform float uRadius;    // 13
uniform float uLevel;     // 14
uniform float uPulse;     // 15
uniform float uSeg;       // 16
uniform float uOnda;      // 17

out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
             mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
  float v = 0.0, a = 0.5;
  mat2 m = mat2(1.6, 1.2, -1.2, 1.6);
  for (int i = 0; i < 5; i++) {
    v += a * noise(p);
    p = m * p;
    a *= 0.5;
  }
  return v;
}

void main() {
  vec2 uv = (FlutterFragCoord().xy - 0.5 * uRes) / min(uRes.x, uRes.y);
  // Flutter cuenta la y hacia abajo y WebGL hacia arriba: se invierte para que
  // la onda de pensando recorra el orbe en el mismo sentido que el mockup.
  uv.y = -uv.y;
  float r = length(uv);
  float t = uTime;

  // Remolino: gira más cerca del centro. El ángulo lo acumula Dart para que
  // acelerar al cambiar de estado no dé un salto.
  float ang = uAngle + 0.35 / (r * 5.0 + 0.5);
  float c = cos(ang), s = sin(ang);
  vec2 p = mat2(c, -s, s, c) * uv * uScale;

  vec2 q = vec2(fbm(p + vec2(0.0, t * 0.35)), fbm(p + vec2(5.2, 1.3) - t * 0.30));
  vec2 w = vec2(fbm(p + uWarp * q + vec2(1.7, 9.2) + t * 0.15),
                fbm(p + uWarp * q + vec2(8.3, 2.8) - t * 0.12));
  float n  = fbm(p + uWarp * w);
  float n2 = fbm(p * 2.3 + uWarp * w * 1.3 - t * 0.2);
  float hebra  = pow(clamp(1.0 - abs(n  * 2.0 - 1.0), 0.0, 1.0), uSharp);
  float hebra2 = pow(clamp(1.0 - abs(n2 * 2.0 - 1.0), 0.0, 1.0), uSharp * 1.6);

  float radio = min(uRadius * (1.0 + 0.35 * uLevel), 0.33);
  float borde = radio * (0.78 + 0.5 * fbm(uv * 4.0 + t * 0.25));
  // Pensando: la onda lenta de polo a polo.
  borde *= 1.0 + uOnda * 0.06 * sin(uv.y / max(radio, 0.01) * 2.4 - uSeg * 1.6);
  float mascara = smoothstep(borde, borde * 0.12, r);

  float hebras = (hebra * 0.95 + hebra2 * 0.6) * mascara;
  float nucleo = exp(-r * r / (0.0032 * uCore * (1.0 + 1.5 * uLevel)));
  float interior = exp(-r * r / (0.028 * uCore)) * 0.55;
  float halo = exp(-r / (radio * 0.5)) * 0.22;

  vec3 luz = uColor * (hebras * 1.7 + interior + halo * (1.0 + 0.4 * uPulse)) * uIntensity
           + vec3(0.85, 0.95, 1.0) * hebras * hebras * 0.7 * uIntensity
           + vec3(1.0) * nucleo * (0.55 + 0.8 * uIntensity);
  luz = 1.0 - exp(-luz * 1.35);
  // El fundido de la ventana: sin esto se ve el cuadrado al subir la intensidad.
  luz *= 1.0 - smoothstep(0.36, 0.5, r);

  float a;
  vec3 rgb;
  if (uLight < 0.5) {
    a = clamp(max(luz.r, max(luz.g, luz.b)), 0.0, 1.0);
    rgb = luz;
  } else {
    // En claro la luz no suma: es tinta sobre el papel.
    a = clamp(dot(luz, vec3(0.3, 0.5, 0.2)) * 1.25, 0.0, 1.0);
    rgb = uColor * 0.42 * a;
  }
  fragColor = vec4(rgb, a);
}
