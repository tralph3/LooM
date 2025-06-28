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
}
