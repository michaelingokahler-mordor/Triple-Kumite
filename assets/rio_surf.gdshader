shader_type canvas_item;
render_mode unshaded;

void fragment() {
	// Follow the near edge of the painted foam, fading out towards the headland.
	float shore_y = 0.750 + 0.071 * sin((UV.x - 0.068) * 2.25)
			- 0.014 * smoothstep(0.79, 1.0, UV.x);
	float shore = (1.0 - smoothstep(0.010, 0.036, abs(UV.y - shore_y)))
			* smoothstep(0.062, 0.185, UV.x);
	vec4 color = texture(TEXTURE, UV);
	if (shore > 0.0) {
		// Sections of the breaker reach the sand at slightly different times.
		float phase = fract(TIME / 6.0 - 0.43 * UV.x + 0.065 * sin(15.0 * UV.x));
		float surge = smoothstep(0.0, 0.38, phase) * (1.0 - smoothstep(0.38, 1.0, phase));
		float travel = (surge - 0.25) * (10.0 + 3.0 * sin(11.0 * UV.x)) * shore;
		// Interpolate along the direction of travel to keep the pixel edge steady at low speeds.
		float row = (UV.y / TEXTURE_PIXEL_SIZE.y) - 0.5 - travel;
		vec2 sample_uv = vec2(UV.x, (floor(row) + 0.5) * TEXTURE_PIXEL_SIZE.y);
		color = mix(texture(TEXTURE, sample_uv),
				texture(TEXTURE, sample_uv + vec2(0.0, TEXTURE_PIXEL_SIZE.y)), fract(row));
		float foam = smoothstep(0.83, 0.96, min(color.r, min(color.g, color.b)));
		vec3 shallows = texture(TEXTURE, vec2(UV.x, shore_y - 0.022)).rgb;
		color.rgb = mix(color.rgb, shallows, 0.32 * (1.0 - surge) * foam * shore);
	}
	COLOR = color;
}
