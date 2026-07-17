shader_type canvas_item;

// A full-screen transition overlay. `progress` (0=clear, 1=fully black) is driven by
// the AnimationPlayer; `style` picks the shape (randomized per transition in code).
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform int style : hint_range(0, 6) = 0;

void fragment() {
	vec2 uv = UV;
	float a = 0.0;
	if (style == 0) {
		a = progress;                          // 0 crossfade
	} else if (style == 1) {
		a = step(uv.x, progress);              // 1 wipe left -> right
	} else if (style == 2) {
		a = step(1.0 - uv.x, progress);        // 2 wipe right -> left
	} else if (style == 3) {
		a = step(uv.y, progress);              // 3 wipe top -> bottom
	} else if (style == 4) {
		a = step(1.0 - uv.y, progress);        // 4 wipe bottom -> top
	} else if (style == 5) {
		float d = distance(uv, vec2(0.5)) / 0.70711;
		a = step(d, progress);                 // 5 iris in (grows from centre)
	} else {
		float d = distance(uv, vec2(0.5)) / 0.70711;
		a = step(1.0 - d, progress);           // 6 iris out (closes to centre)
	}
	COLOR = vec4(0.0, 0.0, 0.0, a);
}
