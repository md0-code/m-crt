Texture2D shaderTexture;
SamplerState samplerState;

cbuffer PixelShaderSettings {
	float  Time;
	float  Scale;
	float2 Resolution;
	float4 Background;
};

#define OVERSCAN_X 1.02
#define OVERSCAN_Y 1.02
#define CURVATURE_X .021
#define CURVATURE_Y .021
#define BLUR_STRENGTH .8
#define MONOCHROME_DISPLAY 0.
#define MONOCHROME_TYPE 1.
#define MONOCHROME_COLORS 256
#define CORNER_SIZE .01
#define SCANLINES_STRENGTH 0.05
#define LIGHT_STRENGTH 8.0
#define GAMMA .8
#define CONTRAST 1.
#define SATURATION 1.
#define BRIGHTNESS 1.


float3 postEffects(in float3 rgb)
{
	rgb = pow(rgb, GAMMA);
	rgb = lerp(float3(.5, .5, .5), lerp(dot(float3(.2125, .7154, .0721), rgb * BRIGHTNESS), rgb * BRIGHTNESS, SATURATION), CONTRAST);
	return rgb;
}

// Sigma 1. Size 3
float3 gaussian(in float2 uv)
{
	float b = BLUR_STRENGTH / (Resolution.x / Resolution.y);

	float3 col = shaderTexture.Sample(samplerState, float2(uv.x - b / Resolution.x, uv.y - b / Resolution.y)).rgb * 0.077847;
	col += shaderTexture.Sample(samplerState, float2(uv.x - b / Resolution.x, uv.y)).rgb * 0.123317;
	col += shaderTexture.Sample(samplerState, float2(uv.x - b / Resolution.x, uv.y + b / Resolution.y)).rgb * 0.077847;

	col += shaderTexture.Sample(samplerState, float2(uv.x, uv.y - b / Resolution.y)).rgb * 0.123317;
	col += shaderTexture.Sample(samplerState, float2(uv.x, uv.y)).rgb * 0.195346;
	col += shaderTexture.Sample(samplerState, float2(uv.x, uv.y + b / Resolution.y)).rgb * 0.123317;

	col += shaderTexture.Sample(samplerState, float2(uv.x + b / Resolution.x, uv.y - b / Resolution.y)).rgb * 0.077847;
	col += shaderTexture.Sample(samplerState, float2(uv.x + b / Resolution.x, uv.y)).rgb * 0.123317;
	col += shaderTexture.Sample(samplerState, float2(uv.x + b / Resolution.x, uv.y + b / Resolution.y)).rgb * 0.077847;

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

float4 main(float4 pos : SV_POSITION, float2 st : TEXCOORD) : SV_TARGET
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
	float3 color = shaderTexture.Sample(samplerState, uv).rgb;
	

	// Color blur
	if (BLUR_STRENGTH > 0)
		color = gaussian(uv);

	// Monochrome display
	if (MONOCHROME_DISPLAY == 1)
	{
		float3 ink;
		if (MONOCHROME_TYPE == 1)
		{
			ink = float3(0.5, 0.5, 0.5); // gray
		}
		else if (MONOCHROME_TYPE == 2)
		{
			ink = float3(0., 0.4, 0.); // green
		}
		else if (MONOCHROME_TYPE == 3)
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
	if (Resolution.y < 360)
		showScanlines = 0;
	float s = 1. - smoothstep(320., 1440., Resolution.y) + 1.;
	float j = cos(uv.y * Resolution.y * s) * SCANLINES_STRENGTH;
	color = abs(showScanlines - 1.) * color + showScanlines * (color - color * j);
	color *= 1. - (.01 + ceil(mod((uv.x + .5) * Resolution.x, 3.)) * (.995 - 1.01)) * showScanlines;

	// Color correction
	color = postEffects(color);

	return float4(color, 1.0);
}
