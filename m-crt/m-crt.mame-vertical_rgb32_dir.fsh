#version 120

#pragma optimize (on)
#pragma debug (off)

uniform sampler2D mpass_texture;      // = Texture
uniform sampler2D color_texture;
uniform vec2 color_texture_sz;        // = InputSize
uniform vec2 color_texture_pow2_sz;   // = TextureSize
uniform vec2 screen_texture_sz;       
uniform vec2 screen_texture_pow2_sz;  // = OutputSize

uniform float OVERSCAN_X = 1.01;
uniform float OVERSCAN_Y = 1.01;
uniform float CURVATURE_X = .021;
uniform float CURVATURE_Y = .021;
uniform float BLUR_STRENGTH = 1;
uniform float MONOCHROME_DISPLAY = 0;
uniform float MONOCHROME_TYPE = 1;
uniform float MONOCHROME_COLORS = 256;
uniform float CORNER_SIZE = .01;
uniform float SCANLINES_STRENGTH = .03;
uniform float LIGHT_STRENGTH = 8;
uniform float GAMMA = 1;
uniform float CONTRAST = 1;
uniform float SATURATION = 1;
uniform float BRIGHTNESS = 1;

vec3 postEffects(in vec3 rgb)
{
	rgb = pow(rgb, vec3(GAMMA));
	rgb = mix(vec3(.5), mix(vec3(dot(vec3(.2125, .7154, .0721), rgb * BRIGHTNESS)), rgb * BRIGHTNESS, SATURATION), CONTRAST);
	return rgb;
}

// Sigma 1. Size 3
vec3 gaussian(in vec2 uv)
{
	vec2 textureSize = screen_texture_pow2_sz;
	float b = BLUR_STRENGTH / (textureSize.x / textureSize.y);

	vec3 col = texture2D(mpass_texture, vec2(uv.x - b / textureSize.x, uv.y - b / textureSize.y)).rgb * 0.077847;
	col += texture2D(mpass_texture, vec2(uv.x - b / textureSize.x, uv.y)).rgb * 0.123317;
	col += texture2D(mpass_texture, vec2(uv.x - b / textureSize.x, uv.y + b / textureSize.y)).rgb * 0.077847;

	col += texture2D(mpass_texture, vec2(uv.x, uv.y - b / textureSize.y)).rgb * 0.123317;
	col += texture2D(mpass_texture, vec2(uv.x, uv.y)).rgb * 0.195346;
	col += texture2D(mpass_texture, vec2(uv.x, uv.y + b / textureSize.y)).rgb * 0.123317;

	col += texture2D(mpass_texture, vec2(uv.x + b / textureSize.x, uv.y - b / textureSize.y)).rgb * 0.077847;
	col += texture2D(mpass_texture, vec2(uv.x + b / textureSize.x, uv.y)).rgb * 0.123317;
	col += texture2D(mpass_texture, vec2(uv.x + b / textureSize.x, uv.y + b / textureSize.y)).rgb * 0.077847;

	return col;
}

// Corner roundness
float corners(vec2 coord)
{
	coord *= color_texture_pow2_sz.xy / color_texture_sz.xy;
	coord = (coord - vec2(0.5)) * 1.0 + vec2(0.5);
	coord = min(coord, vec2(1.0) - coord) * vec2(1.0, color_texture_sz.y / color_texture_sz.x);
	vec2 cdist = vec2(CORNER_SIZE);
	coord = (cdist - min(coord, cdist));
	float dist = sqrt(dot(coord, coord));
	return clamp((cdist.x - dist) * 1000.0, 0.0, 1.0);
}

void main()
{
	vec2 st = gl_TexCoord[0].xy;

	// Overscan
	st = st * 2.0 - 1.0;
	st *= vec2(OVERSCAN_X, OVERSCAN_Y);
	st = st * 0.5 + 0.5;

	vec2 uv = st;

	// Curvature
	if (CURVATURE_X > 0 && CURVATURE_Y > 0)
	{
		vec2 crtDistortion = vec2(CURVATURE_X, CURVATURE_Y) * 15;
		vec2 curvedCoords = st * 2.0 - 1.0;
		float curvedCoordsDistance = sqrt(curvedCoords.x * curvedCoords.x + curvedCoords.y * curvedCoords.y);
		curvedCoords = curvedCoords / curvedCoordsDistance;
		curvedCoords = curvedCoords * (1.0 - pow(vec2(1.0 - (curvedCoordsDistance / 1.4142135623730950488016887242097)), (1.0 / (1.0 + crtDistortion * 0.2))));
		curvedCoords = curvedCoords / (1.0 - pow(vec2(0.29289321881345247559915563789515), (1.0 / (vec2(1.0) + crtDistortion * 0.2))));
		uv = curvedCoords * 0.5 + 0.5;
	}

 	vec3 color = texture2D(mpass_texture, uv).rgb;

	// Color blur
	if (BLUR_STRENGTH > 0)
		color = gaussian(uv);

	// Monochrome display
	if (MONOCHROME_DISPLAY == 1)
	{
		vec3 ink;
		if (MONOCHROME_TYPE == 1)
		{
			ink = vec3(0.5, 0.5, 0.5); // gray
		}
		else if (MONOCHROME_TYPE == 2)
		{
			ink = vec3(0., 0.4, 0.); // green
		}
		else if (MONOCHROME_TYPE == 3)
		{
			ink = vec3(0.5, 0.3, 0.0); // amber
		}
		color = vec3(floor(MONOCHROME_COLORS * length(color)) / MONOCHROME_COLORS * ink);
	}

	// Corners
	if (CORNER_SIZE > 0)
		color *= corners(uv);

	// Light
	color *= 1 - min(1, length((uv - .5) * .5 * (uv - .5) * .5) * LIGHT_STRENGTH);

	// Scanlines
	vec2 OutputSize = screen_texture_sz;
	float showScanlines = 1;
	if (OutputSize.x < 240)
		showScanlines = 0;
	float s = 1. - smoothstep(320., 1440., OutputSize.x) + 1.;
	float j = cos(uv.x * OutputSize.x * s) * SCANLINES_STRENGTH;
	color = abs(showScanlines - 1.) * color + showScanlines * (color - color * j);
	color *= 1. - (.01 + ceil(mod((st.y + .5) * OutputSize.y, 3.)) * (.995 - 1.01)) * showScanlines;

	// Color correction
	color = postEffects(color);

	gl_FragColor = vec4(color, 1.0);
}

