package main

import lr "libretro"
import "core:c"

video_refresh_callback :: proc "c" (data: rawptr, width: u32, height: u32, pitch: u32) {
    frame_buffer_update(data, width, height, pitch)
}

audio_sample_callback :: proc "c" (left: i16, right: i16) {
}

input_poll_callback :: proc "c" () {
}

input_state_callback :: proc "c" (port: u32, device: u32, index: u32, id: u32) -> i16 {
    return STATE.input[lr.RetroDevice(id)]
}

audio_sample_batch_callback :: proc "c" (data: ^i16, frames: i32) -> i32 {
    return audio_buffer_push_batch(data, frames)
}

raylib_audio_sample_batch_callback :: proc "c" (data: rawptr, frames: c.uint) {
    audio_buffer_pop_batch(data, frames)
}
