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
