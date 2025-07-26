#include "ReShade.fxh"

uniform float OVERSCAN_X <
	ui_type = "slider";
	ui_min = 0.95;
	ui_max = 1.05;
	ui_step = 0.01;
	ui_label = "X-Axis Overscan Amount";
> = 1.02;
uniform float OVERSCAN_Y <
	ui_type = "slider";
	ui_min = 0.95;
	ui_max = 1.05;
	ui_step = 0.01;
	ui_label = "Y-Axis Overscan Amount";
> = 1.02;
uniform float CURVATURE_X <
	ui_type = "slider";
	ui_min = 0;
	ui_max = 0.125;
	ui_step = 0.01;
	ui_label = "X-Axis Curvature Amount";
> = 0.021;
uniform float CURVATURE_Y <
	ui_type = "slider";
	ui_min = 0;
	ui_max = 0.125;
	ui_step = 0.01;
	ui_label = "Y-Axis Curvature Amount";
> = 0.021;
uniform float BLUR_STRENGTH <
	ui_type = "slider";
	ui_min = 0;
	ui_max = 8;
	ui_step = 0.05;
	ui_label = "Blur Strength";
> = 0.8;
uniform int MONOCHROME_DISPLAY <
	ui_type = "combo";
	ui_items = "No\0Yes\0";
	ui_label = "Monochrome Display";
> = false;
uniform int MONOCHROME_TYPE <
	ui_type = "combo";
	ui_items = "Gray\0Green\0Magenta\0";
	ui_label = "Monochrome Phosphorus Type";
> = 1;
uniform float MONOCHROME_COLORS <
	ui_type = "slider";
	ui_min = 2;
	ui_max = 256;
	ui_step = 1;
	ui_label = "Monochrome Colors";
> = 256;
uniform float CORNER_SIZE <
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = .3;
	ui_step = 0.005;
	ui_label = "Corner Size";
> = 0.015;
uniform float SCANLINES_STRENGTH <
	ui_type = "slider";
	ui_min = 0;
	ui_max = 0.25;
	ui_step = 0.01;
	ui_label = "Scanlines Strength";
> = 0.05;
uniform float LIGHT_STRENGTH <
	ui_type = "slider";
	ui_min = 0;
	ui_max = 20;
	ui_step = 1;
	ui_label = "Vignetting Strength";
> = 8;
uniform float GAMMA <
	ui_type = "slider";
	ui_min = 0.4;
	ui_max = 1.2;
	ui_step = 0.1;
	ui_label = "Gamma";
> = 0.8;
uniform float CONTRAST <
	ui_type = "slider";
	ui_min = 0.4;
	ui_max = 1.2;
	ui_step = 0.1;
	ui_label = "Contrast";
> = 1.0;
uniform float SATURATION <
	ui_type = "slider";
	ui_min = 0.8;
	ui_max = 1.2;
	ui_step = 0.1;
	ui_label = "Contrast";
> = 1;
uniform float BRIGHTNESS <
	ui_type = "slider";
	ui_min = 0.8;
	ui_max = 1.2;
	ui_step = 0.1;
	ui_label = "Brightness";
> = 1;

float3 postEffects(in float3 rgb)
{
	rgb = pow(rgb, GAMMA);
	rgb = lerp(float3(.5, .5, .5), lerp(dot(float3(.2125, .7154, .0721), rgb * BRIGHTNESS), rgb * BRIGHTNESS, SATURATION), CONTRAST);
	return rgb;
}

// Sigma 1. Size 3
float3 gaussian(in float2 uv)
{
	float b = BLUR_STRENGTH / (ReShade::ScreenSize.x / ReShade::ScreenSize.y);

	float3 col = tex2D(ReShade::BackBuffer, float2(uv.x - b / ReShade::ScreenSize.x, uv.y - b / ReShade::ScreenSize.y)).rgb * 0.077847;
	col += tex2D(ReShade::BackBuffer, float2(uv.x - b / ReShade::ScreenSize.x, uv.y)).rgb * 0.123317;
	col += tex2D(ReShade::BackBuffer, float2(uv.x - b / ReShade::ScreenSize.x, uv.y + b / ReShade::ScreenSize.y)).rgb * 0.077847;

	col += tex2D(ReShade::BackBuffer, float2(uv.x, uv.y - b / ReShade::ScreenSize.y)).rgb * 0.123317;
	col += tex2D(ReShade::BackBuffer, float2(uv.x, uv.y)).rgb * 0.195346;
	col += tex2D(ReShade::BackBuffer, float2(uv.x, uv.y + b / ReShade::ScreenSize.y)).rgb * 0.123317;

	col += tex2D(ReShade::BackBuffer, float2(uv.x + b / ReShade::ScreenSize.x, uv.y - b / ReShade::ScreenSize.y)).rgb * 0.077847;
	col += tex2D(ReShade::BackBuffer, float2(uv.x + b / ReShade::ScreenSize.x, uv.y)).rgb * 0.123317;
	col += tex2D(ReShade::BackBuffer, float2(uv.x + b / ReShade::ScreenSize.x, uv.y + b / ReShade::ScreenSize.y)).rgb * 0.077847;

	return col;
}

// Corner roundness
float corners(float2 coord)
{
	coord = (coord - float2(0.5, 0.5)) * float2(1, 1) + float2(0.5, 0.5);
	coord = min(coord, float2(1.0, 1.0) - coord) * float2(1.0, 0.75);
	float2 cdist = float2(CORNER_SIZE, CORNER_SIZE);
	coord = (cdist - min(coord, cdist));
	float dist = sqrt(dot(coord, coord));
	return clamp((cdist.x - dist) * 1000.0, 0.0, 1.0);
}

float mod(float x, float y)
{
	return x - y * floor(x / y);
}

float4 PS_MCRT(float4 pos
			   : SV_Position, float2 st
			   : TEXCOORD0) : SV_Target
{

	// Overscan
	st = st * 2.0 - 1.0;
	st *= float2(OVERSCAN_X, OVERSCAN_Y);
	st = st * 0.5 + 0.5;

	float2 uv = st;

	// Curvature
	if (CURVATURE_X > 0 && CURVATURE_Y > 0)
	{
		float2 crtDistortion = float2(CURVATURE_X, CURVATURE_Y) * 15;
		float2 curvedCoords = uv * 2.0 - 1.0;
		float curvedCoordsDistance = sqrt(curvedCoords.x * curvedCoords.x + curvedCoords.y * curvedCoords.y);
		curvedCoords = curvedCoords / curvedCoordsDistance;
		curvedCoords = curvedCoords * (1.0 - pow(float2(1.0 - (curvedCoordsDistance / 1.4142135623730950488016887242097), 1.0 - (curvedCoordsDistance / 1.4142135623730950488016887242097)), (1.0 / (1.0 + crtDistortion * 0.2))));
		curvedCoords = curvedCoords / (1.0 - pow(float2(0.29289321881345247559915563789515, 0.29289321881345247559915563789515), (1.0 / (float2(1.0, 1.0) + crtDistortion * 0.2))));
		uv = curvedCoords * 0.5 + 0.5;
	}

	float d = length((uv - .5) * .5 * (uv - .5) * .5);
	float3 color = tex2D(ReShade::BackBuffer, uv).rgb;

	// Color blur
	if (BLUR_STRENGTH > 0)
		color = gaussian(uv);

	// Monochrome display
	if (MONOCHROME_DISPLAY == 1)
	{
		float3 ink;
		if (MONOCHROME_TYPE == 0)
		{
			ink = float3(0.5, 0.5, 0.5); // gray
		}
		else if (MONOCHROME_TYPE == 1)
		{
			ink = float3(0., 0.4, 0.); // green
		}
		else if (MONOCHROME_TYPE == 2)
		{
			ink = float3(0.5, 0.3, 0.0); // amber
		}
		color = float3(floor(MONOCHROME_COLORS * length(color)) / MONOCHROME_COLORS * ink);
	}

	// Corners
	if (CORNER_SIZE > 0)
		color *= corners(uv);

	// Light
	color *= 1 - min(1, d * LIGHT_STRENGTH);

	// Scanlines
	float showScanlines = 1;
	if (ReShade::ScreenSize.y < 360)
		showScanlines = 0;
	float s = 1. - smoothstep(320., 1440., ReShade::ScreenSize.y) + 1.;
	float j = cos(uv.y * ReShade::ScreenSize.y * s) * SCANLINES_STRENGTH;
	color = abs(showScanlines - 1.) * color + showScanlines * (color - color * j);
	color *= 1. - (.01 + ceil(mod((uv.x + .5) * ReShade::ScreenSize.x, 3.)) * (.995 - 1.01)) * showScanlines;

	// Color correction
	color = postEffects(color);

	return float4(color, 1.0);
}

technique MCRT
{
	pass MCRT
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_MCRT;
	}
}