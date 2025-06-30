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
    lr.load_rom(core, rom_path) or_return

    GLOBAL_STATE.emulator_state.core = core^

    core.api.get_system_av_info(&GLOBAL_STATE.emulator_state.av_info)

    if GLOBAL_STATE.emulator_state.hardware_render_callback != nil {
        video_init_emulator_framebuffer(
            depth=GLOBAL_STATE.emulator_state.hardware_render_callback.depth,
            stencil=GLOBAL_STATE.emulator_state.hardware_render_callback.stencil,
        )
        run_inside_emulator_context(GLOBAL_STATE.emulator_state.hardware_render_callback.context_reset)
    } else {
        video_init_emulator_framebuffer()
    }

    audio_update_sample_rate()
    input_configure_core()

    return true
}

core_load_game_by_path :: proc (core_path: string, rom_path: string) -> (ok: bool) {
    core := core_load(core_path) or_return
    core_load_game_by_core(&core, rom_path) or_return
    return true
}

core_unload_game :: proc () {
    if GLOBAL_STATE.emulator_state.core.loaded {
        if GLOBAL_STATE.emulator_state.hardware_render_callback != nil {
            run_inside_emulator_context(GLOBAL_STATE.emulator_state.hardware_render_callback.context_destroy)
            sdl.GL_DestroyContext(GLOBAL_STATE.video_state.emu_context)
        }
        core_unload(&GLOBAL_STATE.emulator_state.core)
        cb.clear(&GLOBAL_STATE.audio_state.buffer)
        GLOBAL_STATE.emulator_state = {}
    }
}

core_unload :: proc (core: ^lr.LibretroCore) {
    lr.unload_core(core)
    core_options_free()
}

// You only need to free the returned array, the strings themselves
// are views into the core's memory
core_get_valid_extensions :: proc (core: ^lr.LibretroCore, allocator:=context.allocator) -> []string {
    if core == nil || !core.loaded { return {} }
    return strings.split(string(core.system_info.valid_extensions), "|", allocator=allocator)
}

core_hard_reset :: proc () {
    // this should unload the core completely and re-run the same
    // game, useful for applying core options that require full
    // restarts
}

core_reset_game :: proc () {
    if GLOBAL_STATE.emulator_state.hardware_render_callback != nil {
        run_inside_emulator_context(GLOBAL_STATE.emulator_state.core.api.reset)
    } else {
        GLOBAL_STATE.emulator_state.core.api.reset()
    }
    cb.clear(&GLOBAL_STATE.audio_state.buffer)
}

core_save_state :: proc () {
    size := GLOBAL_STATE.emulator_state.core.api.serialize_size()
    buffer := make([]byte, size)
    defer delete(buffer)

    log.infof("Need {} for save", size)

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

core_load_state :: proc () {
    buffer, _ := os2.read_entire_file_from_path("./savestate", allocator=context.allocator)
    defer delete(buffer)

    if !GLOBAL_STATE.emulator_state.core.api.unserialize(raw_data(buffer), len(buffer)) {
        log.error("Failed loading save state")
        return
    }
}
