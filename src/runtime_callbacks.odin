package main

import lr "libretro"
import sdl "vendor:sdl3"
import "core:c"
import "core:log"
import gl "vendor:OpenGL"

video_refresh_callback :: proc "c" (data: rawptr, width: u32, height: u32, pitch: u32) {
    if data == nil {
        return
    }

    GLOBAL_STATE.video_state.actual_width = width
    GLOBAL_STATE.video_state.actual_height = height

    sdl.GL_MakeCurrent(GLOBAL_STATE.video_state.window, gl_context)

    if int((uintptr)(data)) ==  lr.RETRO_HW_FRAME_BUFFER_VALID {
        // hardware rendering, nothing to do
    } else {
        // software rendering
        gl.BindTexture(gl.TEXTURE_2D, tex_id)

        format: u32
        type: u32

        switch GLOBAL_STATE.video_state.pixel_format {
        case .RGB565:
            format = gl.RGB
            type = gl.UNSIGNED_SHORT_5_6_5
        case .XRGB1555:
            format = gl.BGRA
            type = gl.UNSIGNED_SHORT_1_5_5_5_REV
        case .XRGB8888:
            format = gl.BGRA
            type = gl.UNSIGNED_INT_8_8_8_8_REV
        }

        gl.TexSubImage2D(gl.TEXTURE_2D, 0, 0, 0, i32(width), i32(height), format, type, data)
        gl.BindTexture(gl.TEXTURE_2D, 0)
    }
}

audio_sample_callback :: proc "c" (left: i16, right: i16) {
}

input_poll_callback :: proc "c" () {
}

input_state_callback :: proc "c" (port: u32, device: u32, index: u32, id: u32) -> i16 {
    // TODO: support multiple devices
    return GLOBAL_STATE.input_state.i[lr.RetroDevice(id)]
}

audio_sample_batch_callback :: proc "c" (data: ^i16, frames: i32) -> i32 {
    return audio_buffer_push_batch(data, frames)
}
