shader_type canvas_item;

uniform float aspect = 1.7778;
uniform float dim = 0.0;
uniform float speed = 1.0;

float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }

vec3 ribbon(vec2 uv, float t, float base, float amp, float freq, float phase, float width, vec3 col) {
	float y = base + amp * sin(uv.x * freq + t * 0.18 + phase) + amp * 0.4 * sin(uv.x * freq * 2.3 - t * 0.11 + phase * 1.7);
	float d = abs(uv.y - y);
	return col * (exp(-d * width) * 0.55 + exp(-d * width * 6.0) * 0.5);
}

void fragment() {
	float t = TIME * speed;
	vec2 uv = UV;
	vec2 p = vec2(uv.x * aspect, uv.y);
	vec3 top = vec3(0.07, 0.42, 0.80);
	vec3 mid = vec3(0.30, 0.72, 0.95);
	vec3 hor = vec3(0.80, 0.96, 1.0);
	vec3 col = mix(top, mid, smoothstep(0.0, 0.45, uv.y));
	col = mix(col, hor, smoothstep(0.4, 0.78, uv.y));
	vec2 sun = vec2(0.18 * aspect, 0.12);
	float sd = length(p - sun);
	col += vec3(1.0, 0.98, 0.9) * (0.35 * exp(-sd * 3.5) + 0.25 * exp(-sd * 14.0));
	float ang = atan(p.y - sun.y, p.x - sun.x);
	float rays = pow(max(0.0, sin(ang * 9.0 + t * 0.05)), 8.0) * exp(-sd * 1.6) * 0.18;
	col += vec3(1.0) * rays * step(sun.y, p.y);
	col += ribbon(uv, t, 0.52, 0.07, 3.1, 0.0, 22.0, vec3(0.55, 1.0, 0.95)) * 0.6;
	col += ribbon(uv, t, 0.58, 0.05, 2.2, 2.1, 30.0, vec3(1.0, 1.0, 1.0)) * 0.55;
	col += ribbon(uv, t, 0.47, 0.09, 1.7, 4.0, 16.0, vec3(0.6, 1.0, 0.55)) * 0.35;
	float hill1 = 0.80 + 0.045 * sin(uv.x * 4.2 + 1.3) + 0.02 * sin(uv.x * 9.7);
	float hill2 = 0.86 + 0.03 * sin(uv.x * 3.1 + 4.0) + 0.015 * sin(uv.x * 12.0 + 1.0);
	vec3 g1a = vec3(0.55, 0.88, 0.32);
	vec3 g1b = vec3(0.18, 0.60, 0.20);
	float h1 = smoothstep(hill1 - 0.003, hill1 + 0.003, uv.y);
	vec3 grass1 = mix(g1a, g1b, clamp((uv.y - hill1) / 0.2, 0.0, 1.0));
	grass1 += vec3(0.45, 0.5, 0.3) * exp(-(uv.y - hill1) * 70.0) * h1;
	col = mix(col, grass1, h1);
	float h2 = smoothstep(hill2 - 0.003, hill2 + 0.003, uv.y);
	vec3 grass2 = mix(vec3(0.42, 0.82, 0.25), vec3(0.10, 0.48, 0.15), clamp((uv.y - hill2) / 0.14, 0.0, 1.0));
	grass2 += vec3(0.5, 0.55, 0.3) * exp(-(uv.y - hill2) * 90.0) * h2;
	col = mix(col, grass2, h2);
	for (int i = 0; i < 26; i++) {
		float fi = float(i);
		float r = mix(0.012, 0.055, hash(fi + 3.1));
		float x = hash(fi) * aspect + 0.03 * sin(t * 0.5 + fi);
		float y = 1.1 - fract(hash(fi + 7.7) + t * mix(0.012, 0.03, hash(fi + 1.9)));
		float d = length(p - vec2(x, y * 1.2 - 0.1));
		float ring = smoothstep(r, r - 0.004, d) * (0.08 + 0.5 * smoothstep(r * 0.55, r, d));
		float spec = smoothstep(r * 0.28, 0.0, length(p - vec2(x - r * 0.4, y * 1.2 - 0.1 - r * 0.4)));
		col = mix(col, vec3(1.0), clamp(ring * 0.6 + spec * 0.7, 0.0, 1.0));
	}
	float vig = smoothstep(1.3, 0.35, length((uv - 0.5) * vec2(1.2, 1.0)));
	col *= mix(0.82, 1.0, vig);
	col = mix(col, col * 0.35, dim);
	COLOR = vec4(col, 1.0);
}
