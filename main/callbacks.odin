package main

import "libretro"
import "core:fmt"
import "core:mem"
import "core:c"
import "base:runtime"
import "core:log"

retro_log_callback :: proc "c" (level: libretro.RetroLogLevel, fmt: string, args: ..any) {
    context = GLOBAL_CONTEXT

    // TODO: figure out how to convert c variadic args to odin
    switch level {
    case .DEBUG:
        log.debug(fmt)
    case .INFO:
        log.info(fmt)
    case .WARN:
        log.warn(fmt)
    case .ERROR:
        log.error(fmt)
    }
}

environment_callback :: proc "c" (command: libretro.RetroEnvironment, data: rawptr) -> bool {
    context = GLOBAL_CONTEXT

    using libretro
    #partial switch command {
        case RetroEnvironment.GetCoreOptionsVersion:
        (^int)(data)^ = 2
        case RetroEnvironment.GetVariableUpdate:
        (^bool)(data)^ = false
        case RetroEnvironment.GetCanDupe:
        (^bool)(data)^ = true
        case RetroEnvironment.SetPixelFormat:
        EMULATOR_STATE.frame_buffer.pixel_format = (^libretro.RetroPixelFormat)(data)^
        (^bool)(data)^ = true
        case RetroEnvironment.GetFastforwarding:
        (^bool)(data)^ = false // TODO: mark if we're actually in ff mode
        case RetroEnvironment.SetVariables:
        fallthrough // TODO: deprecated, implement for compatibility
        case RetroEnvironment.SetCoreOptions:
        fallthrough // TODO: deprecated, implement for compatibility
        case RetroEnvironment.SetCoreOptionsV2:
        emulator_clone_core_options_v2((^RetroCoreOptionsV2)(data)^)
        case RetroEnvironment.SetCoreOptionsV2Intl:
        emulator_clone_core_options_v2((^RetroCoreOptionsV2Intl)(data)^)
        case RetroEnvironment.GetLanguage:
        (^RetroLanguage)(data)^ = RetroLanguage.English // TODO: fetch system language
        case RetroEnvironment.GetLogInterface:
        (^RetroLogCallback)(data)^ = { log = retro_log_callback }
        case:
        log.debugf("Got called with %s", command)
        return false
    }

    return true
}

video_refresh_callback :: proc "c" (data: rawptr, width: u32, height: u32, pitch: u32) {
    frame_buffer_update(data, width, height, pitch)
}

audio_sample_callback :: proc "c" (left: i16, right: i16) {
}

input_poll_callback :: proc "c" () {
}

input_state_callback :: proc "c" (port: u32, device: u32, index: u32, id: u32) -> i16 {
    return EMULATOR_STATE.input_state[libretro.RetroDevice(id)]
}

audio_sample_batch_callback :: proc "c" (data: ^i16, frames: i32) -> i32 {
    return audio_buffer_push_batch(data, frames)
}

raylib_audio_sample_batch_callback :: proc "c" (data: rawptr, frames: c.uint) {
    audio_buffer_pop_batch(data, frames)
}
