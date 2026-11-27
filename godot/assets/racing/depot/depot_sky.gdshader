shader_type sky;

uniform sampler2D panorama : filter_linear, repeat_enable;
uniform float azimuth_offset = 0.7114;
uniform float exposure = 0.78;

void sky() {
	vec2 uv = vec2(fract(atan(EYEDIR.x, EYEDIR.z) / TAU + azimuth_offset),
		acos(clamp(EYEDIR.y, -1.0, 1.0)) / PI);
	// The directional light supplies the solar disk's direct energy.
	// Limit its radiance in the low-resolution specular convolution.
	vec3 radiance = texture(panorama, uv).rgb * exposure;
	COLOR = AT_CUBEMAP_PASS ? min(radiance, vec3(9.0)) : radiance;
}
