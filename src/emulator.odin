package main

import lr "libretro"
import sdl "vendor:sdl3"
import cb "circular_buffer"
import "core:os/os2"
import "core:log"

@(private="file")
EMULATOR_STATE := struct {
    core: lr.LibretroCore,
    performance_level: uint,

    options: CoreOptions,

    hw_render_cb: lr.RetroHwRenderCallback,

    keyboard_callback: lr.KeyboardCallbackFunc,

    // max texture size for the framebuffer
    texture_size: [2]i32,
    // size reported in video refresh, is the area of the framebuffer
    // that was actually rendered to
    image_size: [2]u32,
    // size of the final image as displayed on screen, used mostly for
    // calculating aspect ratio, as the size on screen is calculated
    // as part of the GUI layout
    base_size: [2]u32,

    // can be modified for fast forwarding
    target_fps: f64,
    emulator_fps: f64,

    fast_forwarding: bool,

    support_no_game: bool,

    current_game: ^GameEntry,

    loaded: bool,
} {}

emulator_init :: proc (game_entry: ^GameEntry) -> (ok: bool) {
    defer if !ok {
        EMULATOR_STATE = {}
    }

    EMULATOR_STATE.current_game = game_entry

    callbacks := lr.Callbacks {
        environment = process_env_callback,
        video_refresh = video_refresh_callback,
        input_poll = input_poll_callback,
        input_state = input_state_callback,
        audio_sample = audio_sample_callback,
        audio_sample_batch = audio_sample_batch_callback,
    }

    core_path := game_entry.core
    rom_path := game_entry.path

    core := lr.load_core(core_path, &callbacks) or_return
    lr.load_rom(&core, rom_path, EMULATOR_STATE.support_no_game) or_return

    EMULATOR_STATE.core = core
    EMULATOR_STATE.loaded = true

    av_info: lr.SystemAvInfo
    core.api.get_system_av_info(&av_info)

    emulator_update_av_info(&av_info)

    if emulator_is_hw_rendered() {
        video_init_emu_framebuffer(
            depth=EMULATOR_STATE.hw_render_cb.depth,
            stencil=EMULATOR_STATE.hw_render_cb.stencil,
        )
        video_run_inside_emu_context(EMULATOR_STATE.hw_render_cb.context_reset)
    } else {
        video_init_emu_framebuffer()
    }

    audio_update_sample_rate(i32(av_info.timing.sample_rate))
    emulator_update_plugged_controllers()

    return true
}

emulator_close :: proc () {
    if !EMULATOR_STATE.loaded {
        log.warn("Attempted to close a non-initialized emulator")
        return
    }

    if emulator_is_hw_rendered() {
        video_enable_emu_gl_context()

        EMULATOR_STATE.hw_render_cb.context_destroy()
        lr.unload_core(&EMULATOR_STATE.core)

        video_disable_emu_gl_context()
        video_destroy_emu_context()
    } else {
        lr.unload_core(&EMULATOR_STATE.core)
    }

    audio_clear_buffer()

    core_options_free(&EMULATOR_STATE.options)

    EMULATOR_STATE = {}
}

emulator_is_hw_rendered :: proc "contextless" () -> bool {
    return EMULATOR_STATE.hw_render_cb != {}
}

emulator_reset_game :: proc () {
    video_run_inside_emu_context(EMULATOR_STATE.core.api.reset)
    audio_clear_buffer()
}

emulator_hard_reset_game :: proc () {
    entry := EMULATOR_STATE.current_game
    emulator_close()
    emulator_init(entry)
}

emulator_save_state :: proc () {
    video_enable_emu_gl_context()
    defer video_disable_emu_gl_context()

    size := EMULATOR_STATE.core.api.serialize_size()
    buffer := make([]byte, size)
    defer delete(buffer)

    if !EMULATOR_STATE.core.api.serialize(raw_data(buffer), len(buffer)) {
        log.error("Failed saving save state")
        return
    }


    f, err := os2.open("./savestate", { .Write, .Create })
    if err != nil {
        log.errorf("Failed opening savestate: {}", err)
        return
    }
    defer os2.close(f)

    _, err2 := os2.write(f, buffer)
    if err != nil {
        log.errorf("Failed writing savestate: {}", err2)
        return
    }
}

emulator_load_state :: proc () {
    video_enable_emu_gl_context()
    defer video_disable_emu_gl_context()

    buffer, _ := os2.read_entire_file_from_path("./savestate", allocator=context.allocator)
    defer delete(buffer)

    if !EMULATOR_STATE.core.api.unserialize(raw_data(buffer), len(buffer)) {
        log.error("Failed loading save state")
        return
    }
}

emulator_update_plugged_controllers :: proc () {
    if !EMULATOR_STATE.loaded { return }

    for i in 0..<INPUT_MAX_PLAYERS {
        player := input_get_player_input_state(u32(i))

        if player.gamepad == nil {
            EMULATOR_STATE.core.api.set_controller_port_device(i32(i), .None)
        } else {
            EMULATOR_STATE.core.api.set_controller_port_device(i32(i), .Joypad)
        }
    }
}

emulator_get_aspect_ratio :: proc "contextless" () -> f32 {
    return f32(EMULATOR_STATE.base_size.x) / f32(EMULATOR_STATE.base_size.y)
}

emulator_set_image_size :: proc "contextless" (width, height: u32) {
    EMULATOR_STATE.image_size = { width, height }
}

emulator_set_support_no_game :: proc "contextless" (support: bool) {
    EMULATOR_STATE.support_no_game = support
}

emulator_update_av_info :: proc (av_info: ^lr.SystemAvInfo) {
    EMULATOR_STATE.target_fps = av_info.timing.fps
    EMULATOR_STATE.emulator_fps = av_info.timing.fps

    emulator_update_geometry(&av_info.geometry)

    video_init_emu_framebuffer()
    audio_update_sample_rate(i32(av_info.timing.sample_rate))
}

emulator_update_geometry :: proc "contextless" (geometry: ^lr.GameGeometry) {
    EMULATOR_STATE.base_size = { geometry.base_width, geometry.base_height }
    EMULATOR_STATE.texture_size = { i32(geometry.max_width), i32(geometry.max_height) }
}

emulator_get_fps :: proc "contextless" () -> f64 {
    if !EMULATOR_STATE.loaded { return 60.0 }

    return EMULATOR_STATE.target_fps
}

emulator_run_one_frame :: proc "contextless" () {
    video_run_inside_emu_context(EMULATOR_STATE.core.api.run)
}

emulator_get_texture_size :: proc "contextless" () -> [2]i32 {
    return EMULATOR_STATE.texture_size
}

emulator_get_image_size :: proc "contextless" () -> [2]u32 {
    return EMULATOR_STATE.image_size
}

emulator_clear_options :: proc () {
    core_options_free(&EMULATOR_STATE.options)
    EMULATOR_STATE.options = {}
}

emulator_set_options :: proc (options: CoreOptions) {
    EMULATOR_STATE.options = options
}

emulator_set_keyboard_callback :: proc "contextless" (cb: lr.KeyboardCallbackFunc) {
    EMULATOR_STATE.keyboard_callback = cb
}

emulator_get_keyboard_callback :: proc "contextless" () -> lr.KeyboardCallbackFunc {
    return EMULATOR_STATE.keyboard_callback
}

emulator_set_hw_render_callback :: proc "contextless" (hw_render_cb: lr.RetroHwRenderCallback) {
    EMULATOR_STATE.hw_render_cb = hw_render_cb
}

emulator_get_options :: proc "contextless" () -> ^CoreOptions {
    return &EMULATOR_STATE.options
}

emulator_is_fast_forwarding :: proc "contextless" () -> bool {
    return EMULATOR_STATE.fast_forwarding
}

emulator_set_performance_level :: proc "contextless" (level: uint) {
    EMULATOR_STATE.performance_level = level
}

emulator_framebuffer_is_bottom_left_origin :: proc "contextless" () -> bool {
    // if the core is not hardware rendered, then this struct should
    // be zeroed, which makes this value be false
    return EMULATOR_STATE.hw_render_cb.bottom_left_origin
}

emulator_get_current_game_entry :: proc "contextless" () -> ^GameEntry {
    return EMULATOR_STATE.current_game
}
