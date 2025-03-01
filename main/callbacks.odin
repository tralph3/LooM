package main

import "libretro"
import "core:fmt"
import "core:mem"
import "core:c"
import "base:runtime"

environment_callback :: proc "c" (command: libretro.RetroEnvironment, data: rawptr) -> bool {
    context = runtime.default_context()

    #partial switch command {
        case libretro.RetroEnvironment.GetCoreOptionsVersion:
        (^int)(data)^ = 2
        case libretro.RetroEnvironment.GetVariableUpdate:
        (^bool)(data)^ = false
        case libretro.RetroEnvironment.GetCanDupe:
        (^bool)(data)^ = true
        case libretro.RetroEnvironment.SetPixelFormat:
        frame_buffer_set_pixel_format((^libretro.RetroPixelFormat)(data)^)
        (^bool)(data)^ = true
        case libretro.RetroEnvironment.GetFastforwarding:
        (^bool)(data)^ = false // TODO: mark if we're actually in ff mode
        // case RetroEnvironment.SetVariables:
        // fallthrough // TODO: deprecated, implement for compatibility
        // case RetroEnvironment.SetCoreOptions:
        // fallthrough // TODO: deprecated, implement for compatibility
        // case RetroEnvironment.SetCoreOptionsV2:
        // emulator_set_core_optionsv2((^RetroCoreOptionsV2)(data)^)
        // case RetroEnvironment.SetCoreOptionsV2Intl:
        // emulator_set_core_optionsv2_intl((^RetroCoreOptionsV2Intl)(data)^)
        // case RetroEnvironment.GetLanguage:
        // (^RetroLanguage)(data)^ = RetroLanguage.English // TODO: fetch system language
        // case RetroEnvironment.GetVariable:
        // variable := (^RetroVariable)(data)
        // fmt.println(variable)
        return false
        case:
        fmt.printf("Got called with %s\n", command)
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
    return input_state_get_button(libretro.RetroDevice(id))
}

audio_sample_batch_callback :: proc "c" (data: ^i16, frames: i32) -> i32 {
    return audio_buffer_push_batch(data, frames)
}

raylib_audio_sample_batch_callback :: proc "c" (data: rawptr, frames: c.uint) {
    audio_buffer_pop_batch(data, frames)
}
