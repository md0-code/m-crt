#version 450

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	float OVERSCAN_X;
	float OVERSCAN_Y;
	float CURVATURE_X;
	float CURVATURE_Y;
	float BLUR_STRENGTH;
	float MONOCHROME_DISPLAY;
	float MONOCHROME_TYPE;
	float MONOCHROME_COLORS;
	float CORNER_SIZE;
	float SCANLINES_STRENGTH;
	float LIGHT_STRENGTH;
	float GAMMA;
	float CONTRAST;
	float SATURATION;
	float BRIGHTNESS;
}
p;

#pragma parameter OVERSCAN_X "X-Axis Overscan Amount" 1.02 0.95 1.05 0.01
#pragma parameter OVERSCAN_Y "Y-Axis Overscan Amount" 1.02 0.95 1.05 0.01
#pragma parameter CURVATURE_X "X-Axis Curvature Amount" 0.021 0.0 0.125 0.01
#pragma parameter CURVATURE_Y "X-Axis Curvature Amount" 0.021 0.0 0.125 0.01
#pragma parameter BLUR_STRENGTH "Blur Strength" 0.8 0.0 8.0 0.05
#pragma parameter MONOCHROME_DISPLAY "Monochrome Display" 0.0 0.0 1.0 1.0
#pragma parameter MONOCHROME_TYPE "Monochrome Phosphorus Type" 1.0 1.0 3.0 1.0
#pragma parameter MONOCHROME_COLORS "Monochrome Colors" 256.0 2.0 256.0 1.0
#pragma parameter CORNER_SIZE "Corner Size" 0.01 0.0 0.1 0.01
#pragma parameter SCANLINES_STRENGTH "Scanlines Strength" 0.05 0.0 0.25 0.01
#pragma parameter LIGHT_STRENGTH "Vignetting Strength" 8.0 0.0 20.0 1.0
#pragma parameter GAMMA "Gamma" 0.8 0.4 1.2 0.1
#pragma parameter CONTRAST "Contrast" 1.0 0.4 1.2 0.1
#pragma parameter SATURATION "Saturation" 1.0 0.8 1.2 0.1
#pragma parameter BRIGHTNESS "Brightness" 1.0 0.8 1.6 0.1

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
}
global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
	gl_Position = global.MVP * Position;
	vTexCoord = TexCoord;
}

#pragma stage fragment

layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

vec3 postEffects(in vec3 rgb)
{
	rgb = pow(rgb, vec3(p.GAMMA));
	rgb = mix(vec3(.5), mix(vec3(dot(vec3(.2125, .7154, .0721), rgb * p.BRIGHTNESS)), rgb * p.BRIGHTNESS, p.SATURATION), p.CONTRAST);
	return rgb;
}

// Sigma 1. Size 3
vec3 gaussian(in vec2 uv)
{
	float b = p.BLUR_STRENGTH / (p.OutputSize.x / p.OutputSize.y);

	vec3 col = texture(Source, vec2(uv.x - b / p.OutputSize.x, uv.y - b / p.OutputSize.y)).rgb * 0.077847;
	col += texture(Source, vec2(uv.x - b / p.OutputSize.x, uv.y)).rgb * 0.123317;
	col += texture(Source, vec2(uv.x - b / p.OutputSize.x, uv.y + b / p.OutputSize.y)).rgb * 0.077847;

	col += texture(Source, vec2(uv.x, uv.y - b / p.OutputSize.y)).rgb * 0.123317;
	col += texture(Source, vec2(uv.x, uv.y)).rgb * 0.195346;
	col += texture(Source, vec2(uv.x, uv.y + b / p.OutputSize.y)).rgb * 0.123317;

	col += texture(Source, vec2(uv.x + b / p.OutputSize.x, uv.y - b / p.OutputSize.y)).rgb * 0.077847;
	col += texture(Source, vec2(uv.x + b / p.OutputSize.x, uv.y)).rgb * 0.123317;
	col += texture(Source, vec2(uv.x + b / p.OutputSize.x, uv.y + b / p.OutputSize.y)).rgb * 0.077847;

	return col;
}

// Corner roundness
float corners(vec2 coord)
{
	coord *= p.SourceSize.xy / p.OriginalSize.xy;
	coord = (coord - vec2(0.5)) * 1.0 + vec2(0.5);
	coord = min(coord, vec2(1.0) - coord) * vec2(1.0, p.OriginalSize.y / p.OriginalSize.x);
	vec2 cdist = vec2(p.CORNER_SIZE);
	coord = (cdist - min(coord, cdist));
	float dist = sqrt(dot(coord, coord));
	return clamp((cdist.x - dist) * 1000.0, 0.0, 1.0);
}

void main()
{
	vec2 st = vTexCoord.xy * (p.SourceSize.xy / p.OriginalSize.xy);

	// Overscan
	st = st * 2.0 - 1.0;
	st *= vec2(p.OVERSCAN_X, p.OVERSCAN_Y);
	st = st * 0.5 + 0.5;

	vec2 uv = st;

	// Curvature
	if (p.CURVATURE_X > 0 && p.CURVATURE_Y > 0)
	{
		vec2 crtDistortion = vec2(p.CURVATURE_X, p.CURVATURE_Y) * 15;
		vec2 curvedCoords = st * 2.0 - 1.0;
		float curvedCoordsDistance = sqrt(curvedCoords.x * curvedCoords.x + curvedCoords.y * curvedCoords.y);
		curvedCoords = curvedCoords / curvedCoordsDistance;
		curvedCoords = curvedCoords * (1.0 - pow(vec2(1.0 - (curvedCoordsDistance / 1.4142135623730950488016887242097)), (1.0 / (1.0 + crtDistortion * 0.2))));
		curvedCoords = curvedCoords / (1.0 - pow(vec2(0.29289321881345247559915563789515), (1.0 / (vec2(1.0) + crtDistortion * 0.2))));
		uv = curvedCoords * 0.5 + 0.5;
	}

	float d = length((uv - .5) * .5 * (uv - .5) * .5);
	uv *= p.OriginalSize.xy / p.SourceSize.xy;
	vec3 color = texture(Source, uv).rgb;

	// Color blur
	if (p.BLUR_STRENGTH > 0)
		color = gaussian(uv);

	// Monochrome display
	if (p.MONOCHROME_DISPLAY == 1)
	{
		vec3 ink;
		if (p.MONOCHROME_TYPE == 1)
		{
			ink = vec3(0.5, 0.5, 0.5); // gray
		}
		else if (p.MONOCHROME_TYPE == 2)
		{
			ink = vec3(0., 0.4, 0.); // green
		}
		else if (p.MONOCHROME_TYPE == 3)
		{
			ink = vec3(0.5, 0.3, 0.0); // amber
		}
		color = vec3(floor(p.MONOCHROME_COLORS * length(color)) / p.MONOCHROME_COLORS * ink);
	}

	// Corners
	if (p.CORNER_SIZE > 0)
		color *= corners(uv);

	// Light
	color *= 1 - min(1, d * p.LIGHT_STRENGTH);

	// Scanlines
	float showScanlines = 1;
	if (p.OutputSize.y < 360)
		showScanlines = 0;
	float s = 1. - smoothstep(320., 1440., p.OutputSize.y) + 1.;
	float j = cos(uv.y * p.OutputSize.y * s) * p.SCANLINES_STRENGTH;
	color = abs(showScanlines - 1.) * color + showScanlines * (color - color * j);
	color *= 1. - (.01 + ceil(mod((st.x + .5) * p.OutputSize.x, 3.)) * (.995 - 1.01)) * showScanlines;

	// Color correction
	color = postEffects(color);

	FragColor = vec4(color, 1.0);
}
