package main

import "core:fmt"
import "core:mem"
import "core:c"
import "base:runtime"

environment_callback :: proc "c" (command: RetroEnvironment, data: rawptr) -> bool {
    context = runtime.default_context()

    #partial switch command {
        case RetroEnvironment.GetCoreOptionsVersion:
        (^int)(data)^ = 0
        case RetroEnvironment.GetVariableUpdate:
        (^bool)(data)^ = false
        case RetroEnvironment.GetCanDupe:
        (^bool)(data)^ = true
        case RetroEnvironment.SetPixelFormat:
        frame_buffer_set_pixel_format((^RetroPixelFormat)(data)^)
        (^bool)(data)^ = true
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
    return input_state_get_button(RetroDevice(id))
}

audio_sample_batch_callback :: proc "c" (data: ^i16, frames: i32) -> i32 {
    audio_buffer_push_batch(data, frames)
    return frames
}

raylib_audio_sample_batch_callback :: proc "c" (data: rawptr, frames: c.uint) {
    audio_buffer_pop_batch(data, frames)
}
