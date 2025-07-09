package main

import cl "clay"
import sdl "vendor:sdl3"
import "core:slice"
import "core:log"
import "core:strings"
import "core:math"

FocusElement :: struct {
    id: cl.ElementId,
    boundingBox: cl.BoundingBox,
    distance: f32,
}

@(private="file")
GUI_STATE := struct #no_copy {
    arena: cl.Arena,

    focused_element: FocusElement,
    focus_up: FocusElement,
    focus_down: FocusElement,
    focus_left: FocusElement,
    focus_right: FocusElement,

    default_focus: cl.ElementId,
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
    delete(slice.from_ptr(GUI_STATE.arena.memory, int(GUI_STATE.arena.capacity)))
}

gui_update :: proc () {
    window_size := video_get_window_dimensions()
    mouse_state := input_get_mouse_state()

    cl.SetLayoutDimensions({ f32(window_size.x), f32(window_size.y) })
    cl.SetPointerState(mouse_state.position, mouse_state.down)
    cl.UpdateScrollContainers(true, mouse_state.wheel * 5, GLOBAL_STATE.delta_time)

    gui_update_focus_elements_bounding_boxes()
}

@(private="file")
gui_update_focus_elements_bounding_boxes :: proc "contextless" () {
    GUI_STATE.focused_element.boundingBox = cl.GetElementData(GUI_STATE.focused_element.id).boundingBox

    GUI_STATE.focus_up.boundingBox = cl.GetElementData(GUI_STATE.focus_up.id).boundingBox
    GUI_STATE.focus_down.boundingBox = cl.GetElementData(GUI_STATE.focus_down.id).boundingBox
    GUI_STATE.focus_left.boundingBox = cl.GetElementData(GUI_STATE.focus_left.id).boundingBox
    GUI_STATE.focus_right.boundingBox = cl.GetElementData(GUI_STATE.focus_right.id).boundingBox
}

@(private="file")
gui_error_handler :: proc "c" (error_data: cl.ErrorData) {
    context = GLOBAL_STATE.ctx
    log.errorf("CLAY: {}: {}", error_data.errorType, strings.string_from_ptr(error_data.errorText.chars, int(error_data.errorText.length)))
}

gui_is_clicked :: proc (id: cl.ElementId) -> bool {
    return gui_is_focused(id) && input_is_ok_pressed()
}


gui_is_focused :: proc (id: cl.ElementId) -> bool {
    return GUI_STATE.focused_element.id == id
}

gui_focus_up :: proc () {
    if GUI_STATE.focused_element == {} {
        gui_focus_default_element()
    } else if GUI_STATE.focus_up != {} {
        GUI_STATE.focused_element = GUI_STATE.focus_up
        gui_reset_focus_directions()
        audio_play_sound_effect(.SelectNegative)
    }
}

gui_focus_down :: proc () {
    if GUI_STATE.focused_element == {} {
        gui_focus_default_element()
    } else if GUI_STATE.focus_down != {} {
        GUI_STATE.focused_element = GUI_STATE.focus_down
        gui_reset_focus_directions()
        audio_play_sound_effect(.SelectPositive)
    }
}

gui_focus_left :: proc () {
    if GUI_STATE.focused_element == {} {
        gui_focus_default_element()
    } else if GUI_STATE.focus_left != {} {
        GUI_STATE.focused_element = GUI_STATE.focus_left
        gui_reset_focus_directions()
        audio_play_sound_effect(.SelectNegative)
    }
}

gui_focus_right :: proc () {
    if GUI_STATE.focused_element == {} {
        gui_focus_default_element()
    } else if GUI_STATE.focus_right != {} {
        GUI_STATE.focused_element = GUI_STATE.focus_right
        gui_reset_focus_directions()
        audio_play_sound_effect(.SelectPositive)
    }
}

gui_focus_default_element :: proc () {
    bb := cl.GetElementData(GUI_STATE.default_focus).boundingBox
    GUI_STATE.focused_element = {
        id = GUI_STATE.default_focus,
        boundingBox = bb,
    }
    audio_play_sound_effect(.SelectPositive)
}

gui_reset_focus :: proc () {
    gui_reset_focus_directions()
    GUI_STATE.focused_element = {}
    GUI_STATE.default_focus = {}
}

gui_reset_focus_directions :: proc () {
    GUI_STATE.focus_right = {}
    GUI_STATE.focus_left = {}
    GUI_STATE.focus_up = {}
    GUI_STATE.focus_down = {}
}

gui_register_focus_element :: proc (id: cl.ElementId) {
    data := cl.GetElementData(id)
    if !data.found {
        log.warnf("Tried to register a focusable element with non-existent ID: {}", id)
        return
    }

    if gui_is_focused(id) { return }
    if GUI_STATE.focused_element.id == {} { return }

    box_center: [2]f32 = {
        data.boundingBox.x + data.boundingBox.width / 2.0,
        data.boundingBox.y + data.boundingBox.height / 2.0,
    }
    focus_center: [2]f32 = {
        GUI_STATE.focused_element.boundingBox.x + GUI_STATE.focused_element.boundingBox.width / 2.0,
        GUI_STATE.focused_element.boundingBox.y + GUI_STATE.focused_element.boundingBox.height / 2.0,
    }

    d := box_center - focus_center

    angle := math.atan2(d.y, d.x)

    dist_sq := d.x * d.x + d.y * d.y
    assert(dist_sq != 0.0)

    new_focus := FocusElement{
        id = id,
        boundingBox = data.boundingBox,
        distance = dist_sq
    }

    if angle >= -3.0*math.PI/4.0 && angle < -1.0*math.PI/4.0 {
        if GUI_STATE.focus_up.distance == 0 || GUI_STATE.focus_up.distance > dist_sq {
            GUI_STATE.focus_up = new_focus
        }
    } else if angle >= -1.0*math.PI/4.0 && angle < 1.0*math.PI/4.0 {
        if GUI_STATE.focus_right.distance == 0 || GUI_STATE.focus_right.distance > dist_sq {
            GUI_STATE.focus_right = new_focus
        }
    } else if angle >= 1.0*math.PI/4.0 && angle < 3.0*math.PI/4.0 {
        if GUI_STATE.focus_down.distance == 0 || GUI_STATE.focus_down.distance > dist_sq {
            GUI_STATE.focus_down = new_focus
        }
    } else {
        if GUI_STATE.focus_left.distance == 0 || GUI_STATE.focus_left.distance > dist_sq {
            GUI_STATE.focus_left = new_focus
        }
    }
}

gui_set_default_focus_element :: proc (id: cl.ElementId) {
    GUI_STATE.default_focus = id
}

gui_scroll_container_to_focus :: proc (scroll_container_id: cl.ElementId) {
    scroll_container := cl.GetScrollContainerData(scroll_container_id)
    if !scroll_container.found {
        log.warnf("Scroll container not found: {}", scroll_container_id)
        return
    }

    if GUI_STATE.focused_element.boundingBox.y + GUI_STATE.focused_element.boundingBox.height > scroll_container.scrollContainerDimensions.height {
        scroll_container.scrollPosition.y -= GUI_STATE.focused_element.boundingBox.y + GUI_STATE.focused_element.boundingBox.height - scroll_container.scrollContainerDimensions.height
    } else if GUI_STATE.focused_element.boundingBox.y < 0 {
        scroll_container.scrollPosition.y -= GUI_STATE.focused_element.boundingBox.y
    }
}
