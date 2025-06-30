package libretro

import "core:dynlib"
import "core:os/os2"
import "core:strings"
import "core:log"
import "core:c"

RETRO_HW_FRAME_BUFFER_VALID :: -1

EnvironmentCallback :: proc "c" (RetroEnvironment, rawptr) -> bool
VideoRefreshCallback :: proc "c" (rawptr, u32, u32, u32)
InputPollCallback :: proc "c" ()
InputStateCallback :: proc "c" (u32, RetroDevice, u32, u32) -> i16
AudioSampleCallback :: proc "c" (i16, i16)
AudioSampleBatchCallback :: proc "c" (^i16, i32) -> i32

LibretroCore :: struct {
    api: LibretroCoreAPI,
    system_info: SystemInfo,
}

LibretroCoreAPI :: struct {
    init: proc "c" (),
    deinit: proc "c" (),
    api_version: proc "c" () -> c.uint,
    get_system_info: proc "c" (^SystemInfo),
    get_system_av_info: proc "c" (^SystemAvInfo),
    set_environment: proc "c" (EnvironmentCallback),
    set_video_refresh: proc "c" (VideoRefreshCallback),
    set_controller_port_device: proc "c" (port: c.int, device: RetroDevice),
    set_input_poll: proc "c" (InputPollCallback),
    set_input_state: proc "c" (InputStateCallback),
    set_audio_sample: proc "c" (AudioSampleCallback),
    set_audio_sample_batch: proc "c" (AudioSampleBatchCallback),
    run: proc "c" (),
    reset: proc "c" (),
    load_game: proc "c" (^GameInfo) -> bool,
    unload_game: proc "c" (),
    serialize_size: proc "c" () -> c.size_t,
    serialize: proc "c" (data: rawptr, size: c.size_t) -> c.bool,
    unserialize: proc "c" (data: rawptr, size: c.size_t) -> c.bool,
    get_memory_size: proc "c" (id: c.uint) -> c.size_t,
    get_memory_data: proc "c" (id: c.uint) -> rawptr,

    __handle: dynlib.Library,
}


load_core :: proc (core_path: string, callbacks: ^Callbacks) -> (LibretroCore, bool) {
    core := LibretroCore {}
    count, ok := dynlib.initialize_symbols(&core.api, core_path, "retro_")
    if !ok {
        log.error("Failed loading libretro core")
        return core, false
    }

    initialize_core(&core, callbacks)
    core.api.get_system_info(&core.system_info)

    return core, true
}

unload_core :: proc (core: ^LibretroCore) {
    core.api.unload_game()
    core.api.deinit()
    dynlib.unload_library(core.api.__handle)
}

initialize_core :: proc (core: ^LibretroCore, callbacks: ^Callbacks) {
    core.api.set_environment(callbacks.environment)

    core.api.init()

    core.api.set_video_refresh(callbacks.video_refresh)
    core.api.set_input_poll(callbacks.input_poll)
    core.api.set_input_state(callbacks.input_state)
    core.api.set_audio_sample(callbacks.audio_sample)
    core.api.set_audio_sample_batch(callbacks.audio_sample_batch)
}

load_rom :: proc (core: ^LibretroCore, rom_path: string) -> (ok: bool) {
    log.infof("Loading rom '%s'", rom_path)

    sys_info: SystemInfo
    core.api.get_system_info(&sys_info)

    rom_contents: []byte
    defer delete(rom_contents)

    if !sys_info.need_fullpath {
        rom_contents = os2.read_entire_file_from_path(rom_path, allocator=context.allocator) or_else nil
        if rom_contents == nil {
            log.errorf("Failed reading rom '%s'", rom_path)
            return false
        }
    }

    full_path := os2.get_absolute_path(rom_path, allocator=context.allocator) or_else ""
    if full_path == "" {
        log.errorf("Failed getting full path for '%s'", rom_path)
        return false
    }
    defer delete(full_path)

    info := GameInfo {
        path = strings.clone_to_cstring(full_path),
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
