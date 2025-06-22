package libretro

import "core:dynlib"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:log"

RETRO_HW_FRAME_BUFFER_VALID :: -1

LibretroCore :: struct {
    loaded: bool,
    api: LibretroCoreAPI,
}

LibretroCoreAPI :: struct {
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
    core := LibretroCore {}
    count, ok := dynlib.initialize_symbols(&core.api, core_path, "retro_")
    if !ok {
        log.error("Failed loading libretro core")
        return core, false
    }

    core.loaded = true

    return core, true
}

unload_core :: proc (core: ^LibretroCore) {
    core.api.unload_game()
    core.api.deinit()
    core.loaded = false
    dynlib.unload_library(core.api.__handle)
}

initialize_core :: proc (core: ^LibretroCore, callbacks: ^Callbacks) {
    core.api.set_environment(callbacks.environment)

    core.api.init()

    core.api.set_video_refresh(callbacks.video_refresh)
    core.api.set_input_poll(callbacks.input_poll)
    core.api.set_audio_sample(callbacks.audio_sample)
    core.api.set_audio_sample_batch(callbacks.audio_sample_batch)
    core.api.set_input_state(callbacks.input_state)
}

load_rom :: proc (core: ^LibretroCore, rom_path: string) -> (ok: bool) {
    log.infof("Loading rom '%s'", rom_path)

    rom_contents, ok_read_entire_file := os.read_entire_file(rom_path)
    if !ok_read_entire_file {
        log.errorf("Failed reading rom '%s'", rom_path)
        return false
    }
    defer delete(rom_contents)

    info := GameInfo {
        path = strings.clone_to_cstring(rom_path),
        data = raw_data(rom_contents),
        size = len(rom_contents),
        meta = "",
    }
    defer delete(info.path)

    ok_load_game := core.api.load_game(&info)
    if !ok_load_game {
        log.errorf("Failed loading rom '%s'", rom_path)
        return false
    }

    log.infof("Successfully loaded rom '%s'", rom_path)

    return true
}
