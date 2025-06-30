package main

import lr "libretro"
import sdl "vendor:sdl3"

EmulatorState :: struct {
    core: lr.LibretroCore,
    av_info: lr.SystemAvInfo,
    performance_level: uint,
    options: map[cstring]CoreOption,
    options_updated: bool,
    hardware_render_callback: ^lr.RetroHwRenderCallback,
    fast_forward: bool,
    keyboard_callback: lr.KeyboardCallbackFunc,
    actual_width: u32,
    actual_height: u32,
    pixel_format: lr.RetroPixelFormat,
}
