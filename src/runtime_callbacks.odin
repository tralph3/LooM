package main

import lr "libretro"
import sdl "vendor:sdl3"
import "core:c"
import "core:log"
import gl "vendor:OpenGL"

video_refresh_callback :: proc "c" (data: rawptr, width: u32, height: u32, pitch: u32) {
    if data == nil { return }

    GLOBAL_STATE.video_state.actual_width = width
    GLOBAL_STATE.video_state.actual_height = height

    if int((uintptr)(data)) == lr.RETRO_HW_FRAME_BUFFER_VALID {
        // hardware rendering, nothing to do
    } else {
        // software rendering
        gl.BindTexture(gl.TEXTURE_2D, GLOBAL_STATE.video_state.fbo.texture)
        defer gl.BindTexture(gl.TEXTURE_2D, 0)

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
    }
}

input_poll_callback :: proc "c" () {
    state := sdl.GetKeyboardState(nil)
    gamepad_id := sdl.GetGamepads(nil)[0]
    gamepad := sdl.OpenGamepad(gamepad_id)

    GLOBAL_STATE.input_state.i[.Left]   = i16(state[sdl.Scancode.LEFT]      || sdl.GetGamepadButton(gamepad, .DPAD_LEFT))
    GLOBAL_STATE.input_state.i[.Right]  = i16(state[sdl.Scancode.RIGHT]     || sdl.GetGamepadButton(gamepad, .DPAD_RIGHT))
    GLOBAL_STATE.input_state.i[.Up]     = i16(state[sdl.Scancode.UP]        || sdl.GetGamepadButton(gamepad, .DPAD_UP))
    GLOBAL_STATE.input_state.i[.Down]   = i16(state[sdl.Scancode.DOWN]      || sdl.GetGamepadButton(gamepad, .DPAD_DOWN))
    GLOBAL_STATE.input_state.i[.Select] = i16(state[sdl.Scancode.BACKSPACE] || sdl.GetGamepadButton(gamepad, .BACK))
    GLOBAL_STATE.input_state.i[.Start]  = i16(state[sdl.Scancode.RETURN]    || sdl.GetGamepadButton(gamepad, .START))
    GLOBAL_STATE.input_state.i[.A]      = i16(state[sdl.Scancode.D]         || sdl.GetGamepadButton(gamepad, .EAST))
    GLOBAL_STATE.input_state.i[.B]      = i16(state[sdl.Scancode.X]         || sdl.GetGamepadButton(gamepad, .SOUTH))
    GLOBAL_STATE.input_state.i[.X]      = i16(state[sdl.Scancode.W]         || sdl.GetGamepadButton(gamepad, .NORTH))
    GLOBAL_STATE.input_state.i[.Y]      = i16(state[sdl.Scancode.A]         || sdl.GetGamepadButton(gamepad, .WEST))

    GLOBAL_STATE.input_state.i[.L]      = i16(sdl.GetGamepadButton(gamepad, .LEFT_SHOULDER))
    GLOBAL_STATE.input_state.i[.R]      = i16(sdl.GetGamepadButton(gamepad, .RIGHT_SHOULDER))
    GLOBAL_STATE.input_state.i[.L2]     = i16(sdl.GetGamepadAxis(gamepad, .LEFT_TRIGGER) > 0)
    GLOBAL_STATE.input_state.i[.R2]     = i16(sdl.GetGamepadAxis(gamepad, .RIGHT_TRIGGER) > 0)
    GLOBAL_STATE.input_state.i[.L3]     = i16(sdl.GetGamepadButton(gamepad, .LEFT_STICK))
    GLOBAL_STATE.input_state.i[.R3]     = i16(sdl.GetGamepadButton(gamepad, .RIGHT_STICK))

    GLOBAL_STATE.input_state.analog[0] = sdl.GetGamepadAxis(gamepad, .LEFTX)
    GLOBAL_STATE.input_state.analog[1] = sdl.GetGamepadAxis(gamepad, .LEFTY)
    GLOBAL_STATE.input_state.analog[2] = sdl.GetGamepadAxis(gamepad, .RIGHTX)
    GLOBAL_STATE.input_state.analog[3] = sdl.GetGamepadAxis(gamepad, .RIGHTY)
    GLOBAL_STATE.input_state.analog[4] = sdl.GetGamepadAxis(gamepad, .LEFT_TRIGGER)
    GLOBAL_STATE.input_state.analog[5] = sdl.GetGamepadAxis(gamepad, .RIGHT_TRIGGER)
}

input_state_callback :: proc "c" (port: u32, device: lr.RetroDevice, index: u32, id: u32) -> i16 {
    // masking the device id ensures that if new values are added in
    // the future the frontend won't break until explicitely supported
    device := lr.RetroDevice(u32(device) & lr.RETRO_DEVICE_MASK)

    // TODO: support multiple devices
    #partial switch device {
    case .None:
        return 0
    case .Joypad:
        id := lr.RetroDeviceIdJoypad(id)
        if u32(id) == lr.RETRO_DEVICE_ID_JOYPAD_MASK {
            mask: u16 = 0
            for button_id in lr.RetroDeviceIdJoypad {
                if GLOBAL_STATE.input_state.i[button_id] != 0 {
                    mask |= u16(1 << u32(button_id))
                }
            }
            return i16(mask)
        }
        return GLOBAL_STATE.input_state.i[id]
    case .Analog:
        index := lr.RetroDeviceIndexAnalog(index)
        switch index {
        case .Left:
            id := lr.RetroDeviceIdAnalog(id)
            return GLOBAL_STATE.input_state.analog[id]
        case .Right:
            id := lr.RetroDeviceIdAnalog(id)
            return GLOBAL_STATE.input_state.analog[2 + i32(id)]
        case .Button:
            id := lr.RetroDeviceIdJoypad(id)
            if id == .L2 {
                return GLOBAL_STATE.input_state.analog[4]
            } else if id == .R2 {
                return GLOBAL_STATE.input_state.analog[5]
            }
        }
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
