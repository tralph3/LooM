package main

import sdl "vendor:sdl3"
import lr "libretro"
import "core:log"

InputState :: struct {
    i: [lr.RetroDevice]i16,
    mouse_wheel_y: f32,
}

input_process :: proc () {
    state := sdl.GetKeyboardState(nil)
    gamepad_id := sdl.GetGamepads(nil)[0]
    gamepad := sdl.OpenGamepad(gamepad_id)

    GLOBAL_STATE.input_state.i[.IdJoypadLeft]   = i16(state[sdl.Scancode.LEFT]      || sdl.GetGamepadButton(gamepad, .DPAD_LEFT))
    GLOBAL_STATE.input_state.i[.IdJoypadRight]  = i16(state[sdl.Scancode.RIGHT]     || sdl.GetGamepadButton(gamepad, .DPAD_RIGHT))
    GLOBAL_STATE.input_state.i[.IdJoypadUp]     = i16(state[sdl.Scancode.UP]        || sdl.GetGamepadButton(gamepad, .DPAD_UP))
    GLOBAL_STATE.input_state.i[.IdJoypadDown]   = i16(state[sdl.Scancode.DOWN]      || sdl.GetGamepadButton(gamepad, .DPAD_DOWN))
    GLOBAL_STATE.input_state.i[.IdJoypadSelect] = i16(state[sdl.Scancode.BACKSPACE] || sdl.GetGamepadButton(gamepad, .BACK))
    GLOBAL_STATE.input_state.i[.IdJoypadStart]  = i16(state[sdl.Scancode.RETURN]    || sdl.GetGamepadButton(gamepad, .START))
    GLOBAL_STATE.input_state.i[.IdJoypadA]      = i16(state[sdl.Scancode.D]         || sdl.GetGamepadButton(gamepad, .EAST))
    GLOBAL_STATE.input_state.i[.IdJoypadB]      = i16(state[sdl.Scancode.X]         || sdl.GetGamepadButton(gamepad, .SOUTH))
    GLOBAL_STATE.input_state.i[.IdJoypadX]      = i16(state[sdl.Scancode.W]         || sdl.GetGamepadButton(gamepad, .NORTH))
    GLOBAL_STATE.input_state.i[.IdJoypadY]      = i16(state[sdl.Scancode.A]         || sdl.GetGamepadButton(gamepad, .WEST))
}
