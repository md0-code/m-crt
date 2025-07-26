string name : NAME = "M-CRT";
string combineTechique : COMBINETECHNIQUE = "MCRT";

#define CURVATURE_X .021
#define CURVATURE_Y .021
#define BLUR_STRENGTH .4
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

float4x4 world : WORLD;
float4x4 view : VIEW;
float4x4 projection : PROJECTION;
float4x4 worldView : WORLDVIEW;
float4x4 viewProjection : VIEWPROJECTION;
float4x4 worldViewProjection : WORLDVIEWPROJECTION;

texture sourceTexture : SOURCETEXTURE;
texture workingTexture : WORKINGTEXTURE;
float2 sourceDims : SOURCEDIMS;
float2 inputDims : INPUTDIMS;
sampler sL = sampler_state
{
	Texture = (sourceTexture);
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
	AddressU = Clamp;
	AddressV = Clamp;
	SRGBTEXTURE = FALSE;
};

struct VS_OUTPUT
{
	float4 position : POSITION;
	float2 texCoord : TEXCOORD0;
	float2 absPos : TEXCOORD1;
};

VS_OUTPUT VS_MCRT(float3 position: POSITION, float2 texCoord: TEXCOORD0)
{
	VS_OUTPUT outVar = (VS_OUTPUT)0;
	outVar.position = mul(float4(position, 1), worldViewProjection);
	outVar.absPos = float2((position.x + 0.5) * world._11, (position.y - 0.5) * (-world._22));
	outVar.texCoord = texCoord;
	return outVar;
}

// Curvature (HLSL only)
float2 radialDistortion(float2 coord, float2 pos)
{
	float2 crtDistortion = float2(CURVATURE_X, CURVATURE_Y) * 6;
	pos /= float2(world._11, world._22);
	float2 cc = pos - 0.5;
	float dist = dot(cc, cc) * crtDistortion;
	return coord * (pos + cc * (1.0 + dist) * dist) / pos;
}

// Color effects
float3 postEffects(in float3 rgb)
{
	rgb = pow(rgb, GAMMA);
	rgb = lerp(float3(.5, .5, .5), lerp(dot(float3(.2125, .7154, .0721), rgb * BRIGHTNESS), rgb * BRIGHTNESS, SATURATION), CONTRAST);
	return rgb;
}

// Sigma 1. Size 3
float3 gaussian(in float2 uv)
{
	float b = BLUR_STRENGTH / (sourceDims.x / sourceDims.y);

	float3 col = tex2D(sL, float2(uv.x - b / sourceDims.x, uv.y - b / sourceDims.y)).rgb * 0.077847;
	col += tex2D(sL, float2(uv.x - b / sourceDims.x, uv.y)).rgb * 0.123317;
	col += tex2D(sL, float2(uv.x - b / sourceDims.x, uv.y + b / sourceDims.y)).rgb * 0.077847;

	col += tex2D(sL, float2(uv.x, uv.y - b / sourceDims.y)).rgb * 0.123317;
	col += tex2D(sL, float2(uv.x, uv.y)).rgb * 0.195346;
	col += tex2D(sL, float2(uv.x, uv.y + b / sourceDims.y)).rgb * 0.123317;

	col += tex2D(sL, float2(uv.x + b / sourceDims.x, uv.y - b / sourceDims.y)).rgb * 0.077847;
	col += tex2D(sL, float2(uv.x + b / sourceDims.x, uv.y)).rgb * 0.123317;
	col += tex2D(sL, float2(uv.x + b / sourceDims.x, uv.y + b / sourceDims.y)).rgb * 0.077847;

	return col;
}

// Corner roundness
float corners(float2 coord)
{
	coord *= sourceDims / inputDims;
	coord = (coord - 0.5) + 0.5;
	coord = min(coord, 1.0 - coord);
	float2 cdist = float2(CORNER_SIZE, CORNER_SIZE);
	coord = (cdist - min(coord, cdist));
	float dist = sqrt(dot(coord, coord));
	return clamp((cdist.x - dist) * 1000.0, 0.0, 1.0);
}

// GLSL hack
float mod(float x, float y)
{
	return x - y * floor(x / y);
}

float4 PS_MCRT(in VS_OUTPUT input) : COLOR
{
	float2 st = input.texCoord;
	float2 pos = input.absPos;

	float2 uv = st;

	// Curvature
	if (CURVATURE_X > 0 && CURVATURE_Y > 0)
	{
		uv = radialDistortion(st, pos);
	}

	float d = length((uv - .5) * .5 * (uv - .5) * .5);
	float3 color = tex2D(sL, uv).rgb;

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
	float2 outputDims = sourceDims * 10;
	float showScanlines = 1;
	if (sourceDims.y < 360)
		showScanlines = 0;
	float s = 1. - smoothstep(320., 1440., outputDims.y) + 1.;
	float j = cos(uv.y * outputDims.y * s) * SCANLINES_STRENGTH;
	color = abs(showScanlines - 1.) * color + showScanlines * (color - color * j);
	color *= 1. - (.01 + ceil(fmod((uv.x + .5) * outputDims.x, 3.)) * (.995 - 1.01)) * showScanlines;

	// Color correction
	color = postEffects(color);

	return float4(color, 1.0);
}

technique MCRT
{
	pass MCRT
	{
		VertexShader = compile vs_2_0 VS_MCRT();
		PixelShader = compile ps_3_0 PS_MCRT();
	}
}