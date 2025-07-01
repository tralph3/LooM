package main

import lr "libretro"
import sdl "vendor:sdl3"
import cb "circular_buffer"
import "core:log"
import "core:strings"
import "core:os/os2"

core_load :: proc (core_path: string) -> (core: lr.LibretroCore, ok: bool) {
    callbacks := lr.Callbacks {
        environment = process_env_callback,
        video_refresh = video_refresh_callback,
        input_poll = input_poll_callback,
        input_state = input_state_callback,
        audio_sample = audio_sample_callback,
        audio_sample_batch = audio_sample_batch_callback,
    }
    core = lr.load_core(core_path, &callbacks) or_return

    return core, true
}

core_load_game :: proc {
    core_load_game_by_path,
    core_load_game_by_core,
}

core_load_game_by_core :: proc (core: ^lr.LibretroCore, rom_path: string) -> (ok: bool) {
    lr.load_rom(core, rom_path, GLOBAL_STATE.emulator_state.support_no_game) or_return

    GLOBAL_STATE.emulator_state.core = core^

    GLOBAL_STATE.emulator_state.loaded = true

    core.api.get_system_av_info(&GLOBAL_STATE.emulator_state.av_info)

    if emulator_is_hw_rendered() {
        video_init_emu_framebuffer(
            depth=GLOBAL_STATE.emulator_state.hw_render_cb.depth,
            stencil=GLOBAL_STATE.emulator_state.hw_render_cb.stencil,
        )
        video_run_inside_emu_context(GLOBAL_STATE.emulator_state.hw_render_cb.context_reset)
    } else {
        video_init_emu_framebuffer()
    }

    audio_update_sample_rate()
    emulator_update_plugged_controllers()

    return true
}

core_load_game_by_path :: proc (core_path: string, rom_path: string) -> (ok: bool) {
    core := core_load(core_path) or_return
    core_load_game_by_core(&core, rom_path) or_return
    return true
}

core_unload_game :: proc () {
    if !GLOBAL_STATE.emulator_state.loaded { return }

    if emulator_is_hw_rendered() {
        video_run_inside_emu_context(GLOBAL_STATE.emulator_state.hw_render_cb.context_destroy)
        video_destroy_emu_context()
    }
    core_unload(&GLOBAL_STATE.emulator_state.core)
    audio_clear_buffer()
    GLOBAL_STATE.emulator_state = {}
}

core_unload :: proc (core: ^lr.LibretroCore) {
    lr.unload_core(core)
    core_options_free()
}

// You only need to free the returned array, the strings themselves
// are views into the core's memory
core_get_valid_extensions :: proc (core: ^lr.LibretroCore, allocator:=context.allocator) -> []string {
    if core == nil { return {} }
    return strings.split(string(core.system_info.valid_extensions), "|", allocator=allocator)
}

core_hard_reset :: proc () {
    // this should unload the core completely and re-run the same
    // game, useful for applying core options that require full
    // restarts
}
