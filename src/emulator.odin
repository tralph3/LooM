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

emulator_reset_game :: proc () {
    video_run_inside_emu_context(GLOBAL_STATE.emulator_state.core.api.reset)
    audio_clear_buffer()
}

emulator_save_state :: proc () {
    video_enable_emu_gl_context()
    defer video_disable_emu_gl_context()

    size := GLOBAL_STATE.emulator_state.core.api.serialize_size()
    buffer := make([]byte, size)
    defer delete(buffer)

    if !GLOBAL_STATE.emulator_state.core.api.serialize(raw_data(buffer), len(buffer)) {
        log.error("Failed saving save state")
        return
    }


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
    video_enable_emu_gl_context()
    defer video_disable_emu_gl_context()

    buffer, _ := os2.read_entire_file_from_path("./savestate", allocator=context.allocator)
    defer delete(buffer)

    if !GLOBAL_STATE.emulator_state.core.api.unserialize(raw_data(buffer), len(buffer)) {
        log.error("Failed loading save state")
        return
    }
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
