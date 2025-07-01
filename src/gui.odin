package main

import cl "clay"
import sdl "vendor:sdl3"
import "core:slice"
import "core:log"
import "core:strings"

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
    cl.UpdateScrollContainers(true, GLOBAL_STATE.input_state.mouse.wheel_movement * 5, 0.016)

    cl.SetPointerState(GLOBAL_STATE.input_state.mouse.position, GLOBAL_STATE.input_state.mouse.down)

    window_size := video_get_window_dimensions()
    cl.SetLayoutDimensions({ f32(window_size.x), f32(window_size.y) })
}

@(private="file")
gui_error_handler :: proc "c" (error_data: cl.ErrorData) {
    context = GLOBAL_STATE.ctx
    log.errorf("CLAY: {}: {}", error_data.errorType, strings.string_from_ptr(error_data.errorText.chars, int(error_data.errorText.length)))
}

gui_is_clicked :: proc () -> bool {
    return cl.Hovered() && GLOBAL_STATE.input_state.mouse.clicked
}

gui_is_focused :: proc () -> bool {
    return cl.Hovered()
}
