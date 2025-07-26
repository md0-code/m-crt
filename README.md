# M-CRT Shader Collection

A CRT shader adapted for various emulators software. It simulates the look of a classic CRT display from the DOS era according to the author's personal preferences. Allows controlling the curvature, scanlines, vignetting, blur, and monochrome effects.

## Directory Structure

- **m-crt.dosbox.fx**: DOSBox FX shader
- **m-crt.dosbox.glsl**: DOSBox GLSL shader
- **m-crt.mame-horizontal_rgb32_dir.fsh**: MAME horizontal fragment shader
- **m-crt.mame-horizontal.vsh**: MAME horizontal vertex shader
- **m-crt.mame-vertical_rgb32_dir.fsh**: MAME vertical fragment shader
- **m-crt.mame-vertical.vsh**: MAME vertical vertex shader
- **m-crt.reshade.fx**: ReShade FX shader
- **m-crt.retroarch.glslp**: RetroArch GLSLP preset
- **m-crt.retroarch.slangp**: RetroArch Slang preset
- **m-crt.scummvm.glslp**: ScummVM GLSLP preset
- **m-crt.spectral.fx**: Spectral Spectrum emulator FX shader
- **m-crt.terminal.hlsl**: Windows Terminal HLSL shader

## Usage

Copy the relevant shader files to your emulator shader directory. Refer to your emulator's documentation for instructions on loading custom shaders.

## Features

- Adjustable curvature, overscan, blur, scanlines, and vignetting
- Monochrome display simulation (gray, green, amber)
- Color correction (gamma, contrast, saturation, brightness)
- Corner roundness effect

## License

See [LICENSE](./LICENSE) for details.

## Credits

Code portions were borrowed from [frutbunn](https://www.shadertoy.com/user/frutbunn) and other open source shader projects.

---
