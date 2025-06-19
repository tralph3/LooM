package main

import lr "libretro"
import sdl "vendor:sdl3"
import "core:c"

video_refresh_callback :: proc "c" (data: rawptr, width: u32, height: u32, pitch: u32) {
    if data == nil {
        return
    }

    if width != u32(GLOBAL_STATE.video_state.render_texture.w) ||
        height != u32(GLOBAL_STATE.video_state.render_texture.h) {
            GLOBAL_STATE.emulator_state.av_info.geometry.max_width = width
            GLOBAL_STATE.emulator_state.av_info.geometry.max_height = height
            renderer_update_texture_dimensions_and_format()
        }

    if ((^int)(data))^ ==  lr.RETRO_HW_FRAME_BUFFER_VALID {
        // hardware rendering, framebuffer has already been rendered to

    } else {
        // software rendering, we must update the framebuffer with the given pixels
        sdl.UpdateTexture(GLOBAL_STATE.video_state.render_texture, nil, data, i32(pitch))
    }
}

audio_sample_callback :: proc "c" (left: i16, right: i16) {
}

input_poll_callback :: proc "c" () {
}

input_state_callback :: proc "c" (port: u32, device: u32, index: u32, id: u32) -> i16 {
    // TODO: support multiple devices
    return GLOBAL_STATE.input_state.libretro_input[lr.RetroDevice(id)]
}

audio_sample_batch_callback :: proc "c" (data: ^i16, frames: i32) -> i32 {
    return audio_buffer_push_batch(data, frames)
}
