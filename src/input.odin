package main

import sdl "vendor:sdl3"
import lr "libretro"
import "core:log"

InputState :: struct {
    i: [lr.RetroDeviceIdJoypad]i16,
    analog: [6]i16,
    mouse_wheel_y: f32,
    mouse_pos: [2]i16
}

input_handle_key_pressed :: proc (event: ^sdl.Event) {
input_set_rumble :: proc "c" (port: uint, effect: lr.RetroRumbleEffect, strength: u16) -> bool {
    gamepad_id := sdl.GetGamepads(nil)[0]
    gamepad := sdl.OpenGamepad(gamepad_id)

    switch effect {
    case .Strong:
        sdl.RumbleGamepad(gamepad, 0, strength, 1000) or_return
    case .Weak:
        sdl.RumbleGamepad(gamepad, strength, 0, 1000) or_return
    }

    return true
}
