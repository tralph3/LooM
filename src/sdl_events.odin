package main

import sdl "vendor:sdl3"

sdl_events_handle :: proc () {
    event: sdl.Event
    for sdl.PollEvent(&event) {
        #partial switch event.type {
        case .QUIT:
            GLOBAL_STATE.should_exit = true
        case .MOUSE_WHEEL:
            GLOBAL_STATE.input_state.mouse_wheel_y = event.wheel.y
        }
    }
}
