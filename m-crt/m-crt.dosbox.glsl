#version 130

#pragma parameter OVERSCAN_X "X-Axis Overscan Amount" 1.02 0.95 1.05 0.01
#pragma parameter OVERSCAN_Y "Y-Axis Overscan Amount" 1.02 0.95 1.05 0.01
#pragma parameter CURVATURE_X "X-Axis Curvature Amount" 0.02 0.0 0.125 0.01
#pragma parameter CURVATURE_Y "X-Axis Curvature Amount" 0.02 0.0 0.125 0.01
#pragma parameter BLUR_STRENGTH "Blur Strength" 0.5 0.0 8.0 0.05
#pragma parameter MONOCHROME_DISPLAY "Monochrome Display" 1.0 0.0 1.0 1.0
#pragma parameter MONOCHROME_TYPE "Monochrome Phosphorus Type" 1.0 1.0 3.0 1.0
#pragma parameter MONOCHROME_COLORS "Monochrome Colors" 256.0 2.0 256.0 1.0
#pragma parameter CORNER_SIZE "Corner Size" 0.01 0.0 0.1 0.01
#pragma parameter SCANLINES_STRENGTH "Scanlines Strength" 0.05 0.0 0.25 0.01
#pragma parameter LIGHT_STRENGTH "Vignetting Strength" 9.0 0.0 20.0 1.0
#pragma parameter GAMMA "Gamma" 0.8 0.4 1.2 0.1
#pragma parameter CONTRAST "Contrast" 1.0 0.4 1.2 0.1
#pragma parameter SATURATION "Saturation" 1.0 0.8 1.2 0.1
#pragma parameter BRIGHTNESS "Brightness" 1.0 0.8 1.6 0.1

#ifdef PARAMETER_UNIFORM
uniform float OVERSCAN_X;
uniform float OVERSCAN_Y;
uniform float CURVATURE_X;
uniform float CURVATURE_Y;
uniform float BLUR_STRENGTH;
uniform float MONOCHROME_DISPLAY;
uniform float MONOCHROME_TYPE;
uniform float MONOCHROME_COLORS;
uniform float CORNER_SIZE;
uniform float SCANLINES_STRENGTH;
uniform float LIGHT_STRENGTH;
uniform float GAMMA;
uniform float CONTRAST;
uniform float SATURATION;
uniform float BRIGHTNESS;
#else
#define OVERSCAN_X 1.02
#define OVERSCAN_Y 1.02
#define CURVATURE_X .02
#define CURVATURE_Y .02
#define BLUR_STRENGTH .4
#define MONOCHROME_DISPLAY 0.
#define MONOCHROME_TYPE 2.
#define MONOCHROME_COLORS 256
#define CORNER_SIZE .01
#define SCANLINES_STRENGTH .02
#define LIGHT_STRENGTH 8.0
#define GAMMA .8
#define CONTRAST 1.
#define SATURATION 1.
#define BRIGHTNESS 1.0
#endif

#if defined(VERTEX)

#if __VERSION__ >= 130
#define COMPAT_VARYING out
#define COMPAT_ATTRIBUTE in
#define COMPAT_TEXTURE texture
#else
#define COMPAT_VARYING varying
#define COMPAT_ATTRIBUTE attribute
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

COMPAT_ATTRIBUTE vec4 a_position;
COMPAT_VARYING vec2 v_texCoord;

uniform vec2 rubyOutputSize;
uniform vec2 rubyTextureSize;
uniform vec2 rubyInputSize;

void main()
{
	gl_Position = a_position;
	v_texCoord = vec2(a_position.x + 1.0, 1.0 - a_position.y) / 2.0 * rubyInputSize / rubyTextureSize;
}

#elif defined(FRAGMENT)

#if __VERSION__ >= 130
#define COMPAT_VARYING in
#define COMPAT_TEXTURE texture
out vec4 FragColor;
#else
#define COMPAT_VARYING varying
#define FragColor gl_FragColor
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
#define COMPAT_PRECISION highp
#else
#define COMPAT_PRECISION
#endif

uniform vec2 rubyOutputSize;
uniform vec2 rubyTextureSize;
uniform vec2 rubyInputSize;
uniform sampler2D rubyTexture;

#if defined(OPENGLNB)
#define NN_TEXTURE COMPAT_TEXTURE
#define BL_TEXTURE blTexture
vec4 blCOMPAT_TEXTURE(in sampler2D sampler, in vec2 uv)
{
	vec2 texCoord = uv * rubyTextureSize - vec2(0.5);
	vec2 s0t0 = floor(texCoord) + vec2(0.5);
	vec2 s0t1 = s0t0 + vec2(0.0, 1.0);
	vec2 s1t0 = s0t0 + vec2(1.0, 0.0);
	vec2 s1t1 = s0t0 + vec2(1.0);

	vec2 invTexSize = 1.0 / rubyTextureSize;
	vec4 c_s0t0 = COMPAT_TEXTURE(sampler, s0t0 * invTexSize);
	vec4 c_s0t1 = COMPAT_TEXTURE(sampler, s0t1 * invTexSize);
	vec4 c_s1t0 = COMPAT_TEXTURE(sampler, s1t0 * invTexSize);
	vec4 c_s1t1 = COMPAT_TEXTURE(sampler, s1t1 * invTexSize);

	vec2 weight = fract(texCoord);

	vec4 c0 = c_s0t0 + (c_s1t0 - c_s0t0) * weight.x;
	vec4 c1 = c_s0t1 + (c_s1t1 - c_s0t1) * weight.x;

	return (c0 + (c1 - c0) * weight.y);
}
#else
#define BL_TEXTURE COMPAT_TEXTURE
#define NN_TEXTURE nnTexture
vec4 nnCOMPAT_TEXTURE(in sampler2D sampler, in vec2 uv)
{
	vec2 texCoord = floor(uv * rubyTextureSize) + vec2(0.5);
	vec2 invTexSize = 1.0 / rubyTextureSize;
	return COMPAT_TEXTURE(sampler, texCoord * invTexSize);
}
#endif

COMPAT_VARYING vec2 v_texCoord;

vec3 postEffects(in vec3 rgb)
{
	rgb = pow(rgb, vec3(GAMMA));
	rgb = mix(vec3(.5), mix(vec3(dot(vec3(.2125, .7154, .0721), rgb * BRIGHTNESS)), rgb * BRIGHTNESS, SATURATION), CONTRAST);
	return rgb;
}

// Sigma 1. Size 3
vec3 gaussian(in vec2 uv)
{
	float b = BLUR_STRENGTH / (rubyTextureSize.x / rubyTextureSize.y);

	vec3 col = COMPAT_TEXTURE(rubyTexture, vec2(uv.x - b / rubyTextureSize.x, uv.y - b / rubyTextureSize.y)).rgb * 0.077847;
	col += COMPAT_TEXTURE(rubyTexture, vec2(uv.x - b / rubyTextureSize.x, uv.y)).rgb * 0.123317;
	col += COMPAT_TEXTURE(rubyTexture, vec2(uv.x - b / rubyTextureSize.x, uv.y + b / rubyTextureSize.y)).rgb * 0.077847;

	col += COMPAT_TEXTURE(rubyTexture, vec2(uv.x, uv.y - b / rubyTextureSize.y)).rgb * 0.123317;
	col += COMPAT_TEXTURE(rubyTexture, vec2(uv.x, uv.y)).rgb * 0.195346;
	col += COMPAT_TEXTURE(rubyTexture, vec2(uv.x, uv.y + b / rubyTextureSize.y)).rgb * 0.123317;

	col += COMPAT_TEXTURE(rubyTexture, vec2(uv.x + b / rubyTextureSize.x, uv.y - b / rubyTextureSize.y)).rgb * 0.077847;
	col += COMPAT_TEXTURE(rubyTexture, vec2(uv.x + b / rubyTextureSize.x, uv.y)).rgb * 0.123317;
	col += COMPAT_TEXTURE(rubyTexture, vec2(uv.x + b / rubyTextureSize.x, uv.y + b / rubyTextureSize.y)).rgb * 0.077847;

	return col;
}

// Corner roundness
float corners(vec2 coord)
{
	coord *= rubyTextureSize / rubyInputSize;
	coord = (coord - vec2(0.5)) * 1.0 + vec2(0.5);
	coord = min(coord, vec2(1.0) - coord) * vec2(1.0, rubyInputSize.y / rubyInputSize.x);
	vec2 cdist = vec2(CORNER_SIZE);
	coord = (cdist - min(coord, cdist));
	float dist = sqrt(dot(coord, coord));
	return clamp((cdist.x - dist) * 1000.0, 0.0, 1.0);
}

void main()
{

	vec2 st = v_texCoord.xy * (rubyTextureSize.xy / rubyInputSize.xy);

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

	float d = length((uv - .5) * .5 * (uv - .5) * .5);
	uv *= rubyInputSize.xy / rubyTextureSize.xy;
	vec3 color = COMPAT_TEXTURE(rubyTexture, uv).rgb;

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
			ink = vec3(0., 0.5, 0.); // green
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

	// Scanlines
	vec2 outputSize = rubyTextureSize * 2.5;
	float showScanlines = 1;
	if (rubyTextureSize.y < 360)
		showScanlines = 0;
	float s = 1. - smoothstep(320., 1440., outputSize.y) + 1;
	float j = cos(uv.y * outputSize.y * s) * SCANLINES_STRENGTH;
	color = abs(showScanlines - 1.) * color + showScanlines * (color - color * j);
	color *= 1. - (.01 + ceil(mod((uv.x + .5) * outputSize.x, 3.)) * (.995 - 1.01)) * showScanlines;

	// Light
	color *= 1 - min(1, d * LIGHT_STRENGTH);

	// Color correction
	color = postEffects(color);

	FragColor = vec4(color, 1.0);
}

#endif