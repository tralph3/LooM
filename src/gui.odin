package main

import cl "clay"
import sdl "vendor:sdl3"
import "core:slice"
import "core:log"
import "core:strings"

@(private="file")
GUI_STATE := struct #no_copy {
    arena: cl.Arena,
} {}

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

    GUI_STATE.arena = cl.CreateArenaWithCapacityAndMemory(
        uint(min_arena_size), raw_data(memory))

    if cl.Initialize(GUI_STATE.arena, {}, { handler = gui_error_handler }) == nil {
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
            GUI_STATE.arena.memory, int(GUI_STATE.arena.capacity)
        )
    )
}

gui_update :: proc () {
    mouse_state := input_get_mouse_state()
    cl.UpdateScrollContainers(true, mouse_state.wheel * 5, 0.016)

    cl.SetPointerState(mouse_state.position, mouse_state.down)

    window_size := video_get_window_dimensions()
    cl.SetLayoutDimensions({ f32(window_size.x), f32(window_size.y) })
}

@(private="file")
gui_error_handler :: proc "c" (error_data: cl.ErrorData) {
    context = GLOBAL_STATE.ctx
    log.errorf("CLAY: {}: {}", error_data.errorType, strings.string_from_ptr(error_data.errorText.chars, int(error_data.errorText.length)))
}

gui_is_clicked :: proc () -> bool {
    return cl.Hovered() && input_get_mouse_state().clicked
}

gui_is_focused :: proc () -> bool {
    return cl.Hovered()
}
