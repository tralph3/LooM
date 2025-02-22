package main

import "core:dynlib"
import "core:fmt"
import "core:os"
import "core:strings"

LibretroCore :: struct {
    init: proc "c" (),
    load_game: proc "c" (^GameInfo) -> bool,
    set_environment: proc "c" (proc "c" (RetroEnvironment, rawptr) -> bool),
    set_video_refresh: proc "c" (proc "c" (rawptr, u32, u32, u32)),
    set_input_poll: proc "c" (proc "c" ()),
    set_input_state: proc "c" (proc "c" (u32, u32, u32, u32) -> i16),
    set_audio_sample: proc "c" (proc "c" (i16, i16)),
    set_audio_sample_batch: proc "c" (proc "c" (^i16, i32) -> i32),
    get_system_av_info: proc "c" (^SystemAvInfo),
    run: proc "c" (),

    __handle: dynlib.Library,
}

load_core :: proc (core_path: string) -> (LibretroCore, bool) {
    core := LibretroCore{}
    count, ok := dynlib.initialize_symbols(&core, core_path, "retro_")
    if !ok {
        fmt.eprintln("Failed loading libretro core")
        return core, false
    }

    return core, true
}

initialize_core :: proc (core: ^LibretroCore) {
    core.set_environment(environment_callback)

    core.init()

    core.set_video_refresh(video_refresh_callback)
    core.set_input_poll(input_poll_callback)
    core.set_audio_sample(audio_sample_callback)
    core.set_input_state(input_state_callback)
    core.set_audio_sample_batch(audio_sample_batch_callback)
}

load_rom :: proc (core: ^LibretroCore, rom_path: string) -> bool {
    rom_contents, ok_read_entire_file := os.read_entire_file(rom_path)
    if !ok_read_entire_file {
        fmt.eprint("Failed reading rom")
        return false
    }

    info := GameInfo {
        path = strings.clone_to_cstring(rom_path),
        data = &rom_contents,
        size = len(rom_contents),
        meta = "",
    }

    ok_load_game := core.load_game(&info)
    if !ok_load_game {
        fmt.println("Failed loading rom!!")
        return false
    }

    return true
}
