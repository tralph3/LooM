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

    if int((uintptr)(data)) == lr.RETRO_HW_FRAME_BUFFER_VALID {
        // hardware rendering, nothing to do
    } else {
        // software rendering
        gl.BindTexture(gl.TEXTURE_2D, tex_id)

        format: u32
        type: u32
        bbp: u32

        switch GLOBAL_STATE.video_state.pixel_format {
        case .RGB565:
            format = gl.RGB
            type = gl.UNSIGNED_SHORT_5_6_5
            bbp = 2
        case .XRGB1555:
            format = gl.BGRA
            type = gl.UNSIGNED_SHORT_5_5_5_1
            bbp = 2
        case .XRGB8888:
            format = gl.BGRA
            type = gl.UNSIGNED_INT_8_8_8_8_REV
            bbp = 4
        }

        gl.PixelStorei(gl.UNPACK_ROW_LENGTH, i32(pitch / bbp))
        defer gl.PixelStorei(gl.UNPACK_ROW_LENGTH, 0)

        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, i32(width), i32(height), 0, format, type, data)
        gl.BindTexture(gl.TEXTURE_2D, 0)
    }
}

input_poll_callback :: proc "c" () {
    state := sdl.GetKeyboardState(nil)
    gamepad_id := sdl.GetGamepads(nil)[0]
    gamepad := sdl.OpenGamepad(gamepad_id)

    GLOBAL_STATE.input_state.i[.JoypadLeft]   = i16(state[sdl.Scancode.LEFT]      || sdl.GetGamepadButton(gamepad, .DPAD_LEFT))
    GLOBAL_STATE.input_state.i[.JoypadRight]  = i16(state[sdl.Scancode.RIGHT]     || sdl.GetGamepadButton(gamepad, .DPAD_RIGHT))
    GLOBAL_STATE.input_state.i[.JoypadUp]     = i16(state[sdl.Scancode.UP]        || sdl.GetGamepadButton(gamepad, .DPAD_UP))
    GLOBAL_STATE.input_state.i[.JoypadDown]   = i16(state[sdl.Scancode.DOWN]      || sdl.GetGamepadButton(gamepad, .DPAD_DOWN))
    GLOBAL_STATE.input_state.i[.JoypadSelect] = i16(state[sdl.Scancode.BACKSPACE] || sdl.GetGamepadButton(gamepad, .BACK))
    GLOBAL_STATE.input_state.i[.JoypadStart]  = i16(state[sdl.Scancode.RETURN]    || sdl.GetGamepadButton(gamepad, .START))
    GLOBAL_STATE.input_state.i[.JoypadA]      = i16(state[sdl.Scancode.D]         || sdl.GetGamepadButton(gamepad, .EAST))
    GLOBAL_STATE.input_state.i[.JoypadB]      = i16(state[sdl.Scancode.X]         || sdl.GetGamepadButton(gamepad, .SOUTH))
    GLOBAL_STATE.input_state.i[.JoypadX]      = i16(state[sdl.Scancode.W]         || sdl.GetGamepadButton(gamepad, .NORTH))
    GLOBAL_STATE.input_state.i[.JoypadY]      = i16(state[sdl.Scancode.A]         || sdl.GetGamepadButton(gamepad, .WEST))

    GLOBAL_STATE.input_state.i[.JoypadL]      = i16(sdl.GetGamepadButton(gamepad, .LEFT_SHOULDER))
    GLOBAL_STATE.input_state.i[.JoypadR]      = i16(sdl.GetGamepadButton(gamepad, .RIGHT_SHOULDER))
    GLOBAL_STATE.input_state.i[.JoypadL2]     = i16(sdl.GetGamepadAxis(gamepad, .LEFT_TRIGGER) > 0)
    GLOBAL_STATE.input_state.i[.JoypadR2]     = i16(sdl.GetGamepadAxis(gamepad, .RIGHT_TRIGGER) > 0)
    GLOBAL_STATE.input_state.i[.JoypadL3]     = i16(sdl.GetGamepadButton(gamepad, .LEFT_STICK))
    GLOBAL_STATE.input_state.i[.JoypadR3]     = i16(sdl.GetGamepadButton(gamepad, .RIGHT_STICK))

    GLOBAL_STATE.input_state.analog[0] = sdl.GetGamepadAxis(gamepad, .LEFTX)
    GLOBAL_STATE.input_state.analog[1] = sdl.GetGamepadAxis(gamepad, .LEFTY)
    GLOBAL_STATE.input_state.analog[2] = sdl.GetGamepadAxis(gamepad, .RIGHTX)
    GLOBAL_STATE.input_state.analog[3] = sdl.GetGamepadAxis(gamepad, .RIGHTY)
}

input_state_callback :: proc "c" (port: u32, device: lr.RetroDevice, index: u32, id: lr.RetroDeviceId) -> i16 {
    // TODO: support multiple devices
    #partial switch device {
    case .None:
        return 0
    case .Joypad:
        return GLOBAL_STATE.input_state.i[id]
    case .Analog:
        offset: u32 = 2
        return GLOBAL_STATE.input_state.analog[offset * index + u32(id)]
    }

    return 0
}

audio_sample_callback :: proc "c" (left: i16, right: i16) {
    data := [2]i16{ left, right }
    audio_buffer_push_batch((^i16)(&data[0]), 1)
}

audio_sample_batch_callback :: proc "c" (data: ^i16, frames: i32) -> i32 {
    return audio_buffer_push_batch(data, frames)
}
