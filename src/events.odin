package main

import sdl "vendor:sdl3"
import "core:log"

Event :: enum u32 {
    SaveState,
    LoadState,
}

event_to_sdl_event :: proc (event: Event) -> sdl.EventType {
    return sdl.EventType(u32(event) + GLOBAL_STATE.event_offset)
}

event_push :: proc (event: Event, data1: rawptr = nil, data2: rawptr = nil) {
    e: sdl.Event
    e.type = event_to_sdl_event(event)
    e.user.data1 = data1
    e.user.data2 = data2

    if !sdl.PushEvent(&e) {
        log.warn("Failed pushing event '{}': {}", event, sdl.GetError())
    }
}
