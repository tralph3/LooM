package main

import cl "clay"
import sdl "vendor:sdl3"
import "core:slice"
import "core:log"
import "core:strings"

GuiState :: struct {
GuiState :: struct #no_copy {
    arena: cl.Arena,
}

gui_init :: proc () -> (ok: bool) {
    // TODO: Temp fix. Clay runs out of elements with the debug view
    // on. Ideally it should't draw out of view elements.
    cl.SetMaxElementCount(10000)

    min_arena_size := cl.MinMemorySize()
    memory, err := make([]byte, min_arena_size)
    if err != nil {
        log.error("Failed allocating GUI arena")
        return false
    }

    GLOBAL_STATE.gui_state.arena = cl.CreateArenaWithCapacityAndMemory(
        uint(min_arena_size), raw_data(memory))

    if cl.Initialize(GLOBAL_STATE.gui_state.arena, {}, { handler = gui_error_handler }) == nil {
        log.error("Failed initializing Clay")
        return false
    }

    cl.SetMeasureTextFunction(gui_renderer_measure_text, nil)

    when ODIN_DEBUG {
        cl.SetDebugModeEnabled(true)
    }

    gui_renderer_init() or_return

    return true
}

gui_deinit :: proc () {
    gui_renderer_deinit()
    delete(
        slice.from_ptr(
            GLOBAL_STATE.gui_state.arena.memory, int(GLOBAL_STATE.gui_state.arena.capacity)
        )
    )
}

gui_update :: proc () {
    mouse_x: f32
    mouse_y: f32
    state := sdl.GetMouseState(&mouse_x, &mouse_y)

    cl.UpdateScrollContainers(true, { 0, GLOBAL_STATE.input_state.mouse_wheel_y } * 10, 0.016)
    GLOBAL_STATE.input_state.mouse_wheel_y = 0

    window_x: i32
    window_y: i32
    sdl.GetWindowSize(GLOBAL_STATE.video_state.window, &window_x, &window_y)

    cl.SetPointerState({mouse_x, mouse_y}, .LEFT in state)
    cl.SetLayoutDimensions({ f32(window_x), f32(window_y) })
}

@(private="file")
gui_error_handler :: proc "c" (error_data: cl.ErrorData) {
    context = GLOBAL_STATE.ctx
    log.errorf("CLAY: {}: {}", error_data.errorType, strings.string_from_ptr(error_data.errorText.chars, int(error_data.errorText.length)))
}
