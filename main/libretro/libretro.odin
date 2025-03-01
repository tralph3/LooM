package libretro

import "core:dynlib"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:log"

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
    unload_game: proc "c" (),
    deinit: proc "c" (),
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

unload_core :: proc (core: LibretroCore) {
    core.unload_game()
    core.deinit()
    dynlib.unload_library(core.__handle)
}

initialize_core :: proc (core: ^LibretroCore, callbacks: ^Callbacks) {
    core.set_environment(callbacks.environment)

    core.init()

    core.set_video_refresh(callbacks.video_refresh)
    core.set_input_poll(callbacks.input_poll)
    core.set_audio_sample(callbacks.audio_sample)
    core.set_audio_sample_batch(callbacks.audio_sample_batch)
    core.set_input_state(callbacks.input_state)
}

load_rom :: proc (core: ^LibretroCore, rom_path: string) -> bool {
    log.infof("Loading rom '%s'", rom_path)

    rom_contents, ok_read_entire_file := os.read_entire_file(rom_path)
    if !ok_read_entire_file {
        log.errorf("Failed reading rom '%s'", rom_path)
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
        log.errorf("Failed loading rom '%s'", rom_path)
        return false
    }

    log.infof("Successfully loaded rom '%s'", rom_path)

    return true
}
