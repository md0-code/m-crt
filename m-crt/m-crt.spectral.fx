#define OVERSCAN_X 1.02
#define OVERSCAN_Y 1.02
#define CURVATURE_X 0.021
#define CURVATURE_Y 0.021
#define BLUR_STRENGTH 0.1
#define MONOCHROME_DISPLAY 0
#define MONOCHROME_TYPE 1
#define MONOCHROME_COLORS 256
#define CORNER_SIZE 0.01
#define SCANLINES_STRENGTH 0.05
#define LIGHT_STRENGTH 8.0
#define GAMMA 0.8
#define CONTRAST 1
#define SATURATION 1
#define BRIGHTNESS 1

vec3 postEffects(in vec3 rgb)
{
    rgb = pow(rgb, vec3(GAMMA));
    rgb = mix(vec3(0.5), mix(vec3(dot(vec3(0.2125, 0.7154, 0.0721), rgb * BRIGHTNESS)), rgb * BRIGHTNESS, SATURATION), CONTRAST);
    return rgb;
}

// Blur
vec3 gaussian(in vec2 uv, in vec2 outputSize)
{
    float b = BLUR_STRENGTH / (outputSize.x / outputSize.y);
    
    vec3 col = texture(image, vec2(uv.x - b / outputSize.x, uv.y - b / outputSize.y)).rgb * 0.077847;
    col += texture(image, vec2(uv.x - b / outputSize.x, uv.y)).rgb * 0.123317;
    col += texture(image, vec2(uv.x - b / outputSize.x, uv.y + b / outputSize.y)).rgb * 0.077847;
    
    col += texture(image, vec2(uv.x, uv.y - b / outputSize.y)).rgb * 0.123317;
    col += texture(image, vec2(uv.x, uv.y)).rgb * 0.195346;
    col += texture(image, vec2(uv.x, uv.y + b / outputSize.y)).rgb * 0.123317;
    
    col += texture(image, vec2(uv.x + b / outputSize.x, uv.y - b / outputSize.y)).rgb * 0.077847;
    col += texture(image, vec2(uv.x + b / outputSize.x, uv.y)).rgb * 0.123317;
    col += texture(image, vec2(uv.x + b / outputSize.x, uv.y + b / outputSize.y)).rgb * 0.077847;
    
    return col;
}

// Corner roundness
float corners(vec2 coord, vec2 textureSize, vec2 inputSize)
{
    coord *= textureSize / inputSize;
    coord = (coord - vec2(0.5)) * 1.0 + vec2(0.5);
    coord = min(coord, vec2(1.0) - coord) * vec2(1.0, inputSize.y / inputSize.x);
    vec2 cdist = vec2(CORNER_SIZE);
    coord = (cdist - min(coord, cdist));
    float dist = sqrt(dot(coord, coord));
    return clamp((cdist.x - dist) * 1000.0, 0.0, 1.0);
}

void fxShader(out vec4 FragColor, in vec2 uv) {
    vec2 textureSize = vec2(textureSize(image, 0));
    vec2 inputSize = textureSize; // Assuming input size equals texture size
    vec2 outputSize = textureSize; // Assuming output size equals texture size
    
    vec2 st = uv;
    
    // Overscan
    st = st * 2.0 - 1.0;
    st *= vec2(OVERSCAN_X, OVERSCAN_Y);
    st = st * 0.5 + 0.5;
    
    vec2 finalUV = st;
    
    // Curvature
    if (CURVATURE_X > 0.0 && CURVATURE_Y > 0.0)
    {
        vec2 crtDistortion = vec2(CURVATURE_X, CURVATURE_Y) * 15.0;
        vec2 curvedCoords = st * 2.0 - 1.0;
        float curvedCoordsDistance = sqrt(curvedCoords.x * curvedCoords.x + curvedCoords.y * curvedCoords.y);
        curvedCoords = curvedCoords / curvedCoordsDistance;
        curvedCoords = curvedCoords * (1.0 - pow(vec2(1.0 - (curvedCoordsDistance / 1.4142135623730950488016887242097)), (1.0 / (1.0 + crtDistortion * 0.2))));
        curvedCoords = curvedCoords / (1.0 - pow(vec2(0.29289321881345247559915563789515), (1.0 / (vec2(1.0) + crtDistortion * 0.2))));
        finalUV = curvedCoords * 0.5 + 0.5;
    }
    
    float d = length((finalUV - 0.5) * 0.5 * (finalUV - 0.5) * 0.5);
    vec3 color = texture(image, finalUV).rgb;
    
    // Color blur
    if (BLUR_STRENGTH > 0.0)
        color = gaussian(finalUV, outputSize);
    
    // Monochrome display
    if (MONOCHROME_DISPLAY == 1.0)
    {
        vec3 ink;
        if (MONOCHROME_TYPE == 1.0)
        {
            ink = vec3(0.5, 0.5, 0.5); // gray
        }
        else if (MONOCHROME_TYPE == 2.0)
        {
            ink = vec3(0.0, 0.4, 0.0); // green
        }
        else if (MONOCHROME_TYPE == 3.0)
        {
            ink = vec3(0.5, 0.3, 0.0); // amber
        }
        color = vec3(floor(MONOCHROME_COLORS * length(color)) / MONOCHROME_COLORS * ink);
    }
    
    // Corners
    if (CORNER_SIZE > 0.0)
        color *= corners(finalUV, textureSize, inputSize);
    
    // Light (vignetting)
    color *= 1.0 - min(1.0, d * LIGHT_STRENGTH);
    
    // Scanlines
    float scanlineFreq = max(outputSize.y * 3.5, 120.0);
    float j = cos(finalUV.y * scanlineFreq) * SCANLINES_STRENGTH;
    color = color - color * j;
    
    // Color correction
    color = postEffects(color);
    
    FragColor = vec4(color, 1.0);
}