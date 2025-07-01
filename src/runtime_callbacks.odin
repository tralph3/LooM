package main

import lr "libretro"
import sdl "vendor:sdl3"
import "core:c"
import "core:log"
import gl "vendor:OpenGL"

video_refresh_callback :: proc "c" (data: rawptr, width, height, pitch: u32) {
    if data == nil { return }

    GLOBAL_STATE.emulator_state.actual_width = width
    GLOBAL_STATE.emulator_state.actual_height = height

    if int((uintptr)(data)) == lr.RETRO_HW_FRAME_BUFFER_VALID {
        // hardware rendering, nothing to do
    } else {
        // software rendering
        video_upload_pixels_to_fbo(data, width, height, pitch)
    }
}

input_poll_callback :: proc "c" () {
    state := sdl.GetKeyboardState(nil)

    for port in 0..<INPUT_MAX_PLAYERS {
        player := input_get_player_input_state(u32(port))
        gamepad := player.gamepad
        if gamepad == nil { continue }

        player.joypad[.Left]   = i16(state[sdl.Scancode.LEFT]      || sdl.GetGamepadButton(gamepad, .DPAD_LEFT))
        player.joypad[.Right]  = i16(state[sdl.Scancode.RIGHT]     || sdl.GetGamepadButton(gamepad, .DPAD_RIGHT))
        player.joypad[.Up]     = i16(state[sdl.Scancode.UP]        || sdl.GetGamepadButton(gamepad, .DPAD_UP))
        player.joypad[.Down]   = i16(state[sdl.Scancode.DOWN]      || sdl.GetGamepadButton(gamepad, .DPAD_DOWN))
        player.joypad[.Select] = i16(state[sdl.Scancode.BACKSPACE] || sdl.GetGamepadButton(gamepad, .BACK))
        player.joypad[.Start]  = i16(state[sdl.Scancode.RETURN]    || sdl.GetGamepadButton(gamepad, .START))
        player.joypad[.A]      = i16(state[sdl.Scancode.D]         || sdl.GetGamepadButton(gamepad, .EAST))
        player.joypad[.B]      = i16(state[sdl.Scancode.X]         || sdl.GetGamepadButton(gamepad, .SOUTH))
        player.joypad[.X]      = i16(state[sdl.Scancode.W]         || sdl.GetGamepadButton(gamepad, .NORTH))
        player.joypad[.Y]      = i16(state[sdl.Scancode.A]         || sdl.GetGamepadButton(gamepad, .WEST))

        player.joypad[.L]      = i16(sdl.GetGamepadButton(gamepad, .LEFT_SHOULDER))
        player.joypad[.R]      = i16(sdl.GetGamepadButton(gamepad, .RIGHT_SHOULDER))
        player.joypad[.L2]     = i16(sdl.GetGamepadAxis(gamepad, .LEFT_TRIGGER) > 0)
        player.joypad[.R2]     = i16(sdl.GetGamepadAxis(gamepad, .RIGHT_TRIGGER) > 0)
        player.joypad[.L3]     = i16(sdl.GetGamepadButton(gamepad, .LEFT_STICK))
        player.joypad[.R3]     = i16(sdl.GetGamepadButton(gamepad, .RIGHT_STICK))

        player.analog[0] = sdl.GetGamepadAxis(gamepad, .LEFTX)
        player.analog[1] = sdl.GetGamepadAxis(gamepad, .LEFTY)
        player.analog[2] = sdl.GetGamepadAxis(gamepad, .RIGHTX)
        player.analog[3] = sdl.GetGamepadAxis(gamepad, .RIGHTY)
        player.analog[4] = sdl.GetGamepadAxis(gamepad, .LEFT_TRIGGER)
        player.analog[5] = sdl.GetGamepadAxis(gamepad, .RIGHT_TRIGGER)
    }
}

input_state_callback :: proc "c" (port: u32, device: lr.RetroDevice, index: u32, id: u32) -> (val: i16) {
    if port >= INPUT_MAX_PLAYERS { return 0 }

    // masking the device id ensures that if new values are added in
    // the future the frontend won't break until explicitely supported
    device := lr.RetroDevice(u32(device) & lr.RETRO_DEVICE_MASK)

    player := input_get_player_input_state(port)
    #partial switch device {
    case .None:
        return 0
    case .Joypad:
        id := lr.RetroDeviceIdJoypad(id)
        if u32(id) == lr.RETRO_DEVICE_ID_JOYPAD_MASK {
            mask: u16 = 0
            for button_id in lr.RetroDeviceIdJoypad {
                if player.joypad[button_id] != 0 {
                    mask |= u16(1 << u32(button_id))
                }
            }
            return i16(mask)
        }
        return player.joypad[id]
    case .Analog:
        index := lr.RetroDeviceIndexAnalog(index)
        switch index {
        case .Left:
            id := lr.RetroDeviceIdAnalog(id)
            return player.analog[id]
        case .Right:
            id := lr.RetroDeviceIdAnalog(id)
            return player.analog[2 + i32(id)]
        case .Button:
            id := lr.RetroDeviceIdJoypad(id)
            if id == .L2 {
                return player.analog[4]
            } else if id == .R2 {
                return player.analog[5]
            }
        }
    case .Keyboard:
        id := (lr.RetroKey)(id)
        return input_get_keyboard_key_state(id)
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
