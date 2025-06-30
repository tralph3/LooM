package main

import lr "libretro"
import sdl "vendor:sdl3"

EmulatorState :: struct {
    core: lr.LibretroCore,
    av_info: lr.SystemAvInfo,
    performance_level: uint,
    options: map[cstring]CoreOption,
    options_updated: bool,
    hw_render_cb: ^lr.RetroHwRenderCallback,
    fast_forward: bool,
    keyboard_callback: lr.KeyboardCallbackFunc,
    actual_width: u32,
    actual_height: u32,
    pixel_format: lr.RetroPixelFormat,

    loaded: bool,
}


emulator_is_hw_rendered :: proc "contextless" () -> bool {
    return GLOBAL_STATE.emulator_state.hw_render_cb != nil
}

// Asserts that the emulator OpenGL context is being used when this
// function is called. If the emulator doesn't use OpenGL, the it
// asserts the main context is in use.
@(disabled=ODIN_DISABLE_ASSERT)
emulator_assert_emu_context :: proc "contextless" () {
    if emulator_is_hw_rendered() {
        assert_contextless(sdl.GL_GetCurrentContext() == GLOBAL_STATE.video_state.emu_context)
    } else {
        assert_contextless(sdl.GL_GetCurrentContext() == GLOBAL_STATE.video_state.main_context)
    }
}
