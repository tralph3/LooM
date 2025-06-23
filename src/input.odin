package main

import sdl "vendor:sdl3"
import lr "libretro"
import "core:log"

InputState :: struct {
    i: [lr.RetroDeviceId]i16,
    analog: [4]i16,
    mouse_wheel_y: f32,
    mouse_pos: [2]i16
}

input_process :: proc () {
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
