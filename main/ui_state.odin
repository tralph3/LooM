package main

import cl "clay"

UiElementType :: enum {
    NONE,
    USER_TILE,
}

UiElementId :: struct {
    type: UiElementType,
    index: int,
}

UiState :: struct {
    selected: UiElementId,
    pressed: bool,
}

UI_STATE := UiState {
    pressed = false,
    selected = {
        .NONE,
        0
    },
}

ui_select_next_element :: proc () {
    new_index := min(UI_STATE.selected.index + 1, 3)

    #partial switch STATE.state {
    case .LOGIN:
        if UI_STATE.selected.type != .USER_TILE {
            UI_STATE.selected = { .USER_TILE, 0 }
        } else {
            UI_STATE.selected = { .USER_TILE, new_index }
        }
    }
}

ui_select_prev_element :: proc () {
    new_index := max(0, UI_STATE.selected.index - 1)
    #partial switch STATE.state {
    case .LOGIN:
        if UI_STATE.selected.type != .USER_TILE {
            UI_STATE.selected = { .USER_TILE, 0 }
        } else {
            UI_STATE.selected = { .USER_TILE, new_index }
        }
    }
}

ui_press_element :: proc () {
    UI_STATE.pressed = true
}
