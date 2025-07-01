package main

import lr "libretro"
import sdl "vendor:sdl3"
import cb "circular_buffer"
import "core:os/os2"
import "core:log"

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

    support_no_game: bool,

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

emulator_reset_game :: proc () {
    run_inside_emulator_context(GLOBAL_STATE.emulator_state.core.api.reset)
    audio_clear_buffer()
}

emulator_save_state :: proc () {
    size := GLOBAL_STATE.emulator_state.core.api.serialize_size()
    buffer := make([]byte, size)
    defer delete(buffer)

    sdl.GL_MakeCurrent(GLOBAL_STATE.video_state.window, GLOBAL_STATE.video_state.emu_context)
    if !GLOBAL_STATE.emulator_state.core.api.serialize(raw_data(buffer), len(buffer)) {
        log.error("Failed saving save state")
        return
    }
    sdl.GL_MakeCurrent(GLOBAL_STATE.video_state.window, GLOBAL_STATE.video_state.main_context)

    f, err := os2.open("./savestate", { .Write, .Create })
    if err != nil {
        log.errorf("Failed opening savestate: {}", err)
    }
    defer os2.close(f)

    _, err2 := os2.write(f, buffer)
    if err != nil {
        log.errorf("Failed writing savestate: {}", err2)
    }
}

emulator_load_state :: proc () {
    buffer, _ := os2.read_entire_file_from_path("./savestate", allocator=context.allocator)
    defer delete(buffer)

    sdl.GL_MakeCurrent(GLOBAL_STATE.video_state.window, GLOBAL_STATE.video_state.emu_context)
    if !GLOBAL_STATE.emulator_state.core.api.unserialize(raw_data(buffer), len(buffer)) {
        log.error("Failed loading save state")
        return
    }
    sdl.GL_MakeCurrent(GLOBAL_STATE.video_state.window, GLOBAL_STATE.video_state.main_context)
}

emulator_update_plugged_controllers :: proc () {
    if !GLOBAL_STATE.emulator_state.loaded { return }

    for player, i in GLOBAL_STATE.input_state.players {
        if player.gamepad == nil {
            GLOBAL_STATE.emulator_state.core.api.set_controller_port_device(i32(i), .None)
        } else {
            GLOBAL_STATE.emulator_state.core.api.set_controller_port_device(i32(i), .Joypad)
        }
    }
}

emulator_get_aspect_ratio :: #force_inline proc "contextless" () -> f32 {
    return f32(GLOBAL_STATE.emulator_state.av_info.geometry.base_width) /
        f32(GLOBAL_STATE.emulator_state.av_info.geometry.base_height)
}
