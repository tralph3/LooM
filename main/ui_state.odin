package main

import cl "clay"

UiElementId :: struct {
    type: UiElementType,
    index: int,
}

UiElementType :: enum {
    NONE,
    USER_TILE,
    MAIN_MENU_ENTRY,
}

UiListOrientation :: enum {
    Horizontal,
    Vertical,
}

UiListDefinition :: struct {
    orientation: UiListOrientation,
    index: int,
    elem_type: UiElementType,
    elem_count: int,
    next_list: ^UiListDefinition,
    prev_list: ^UiListDefinition,
}

UiState :: struct {
    selected_list: UiListDefinition,
    pressed: bool,
}

UI_STATE := UiState {
    pressed = false,
    selected_list = {
        elem_type = .NONE,
    },
}

ui_select_right :: proc () {
    if UI_STATE.selected_list.elem_type == .NONE {
        UI_STATE.selected_list = UI_STATE.selected_list.next_list^
        return
    }

    if UI_STATE.selected_list.orientation == .Horizontal {
        UI_STATE.selected_list.index = min(UI_STATE.selected_list.index + 1, UI_STATE.selected_list.elem_count - 1)
    } else if UI_STATE.selected_list.next_list != nil {
        UI_STATE.selected_list = UI_STATE.selected_list.next_list^
    }
}

ui_select_left :: proc () {
    if UI_STATE.selected_list.elem_type == .NONE {
        UI_STATE.selected_list = UI_STATE.selected_list.next_list^
        return
    }

    if UI_STATE.selected_list.orientation == .Horizontal {
        UI_STATE.selected_list.index = max(UI_STATE.selected_list.index - 1, 0)
    } else if UI_STATE.selected_list.prev_list != nil {
        UI_STATE.selected_list = UI_STATE.selected_list.prev_list^
    }
}

ui_select_up :: proc () {
    if UI_STATE.selected_list.elem_type == .NONE {
        UI_STATE.selected_list = UI_STATE.selected_list.next_list^
        return
    }

    if UI_STATE.selected_list.orientation == .Vertical {
        UI_STATE.selected_list.index = max(UI_STATE.selected_list.index - 1, 0)
    } else if UI_STATE.selected_list.prev_list != nil {
        UI_STATE.selected_list = UI_STATE.selected_list.prev_list^
    }
}

ui_select_down :: proc () {
    if UI_STATE.selected_list.elem_type == .NONE {
        UI_STATE.selected_list = UI_STATE.selected_list.next_list^
        return
    }

    if UI_STATE.selected_list.orientation == .Vertical {
        UI_STATE.selected_list.index = min(UI_STATE.selected_list.index + 1, UI_STATE.selected_list.elem_count - 1)
    } else if UI_STATE.selected_list.next_list != nil {
        UI_STATE.selected_list = UI_STATE.selected_list.next_list^
    }
}

ui_press_element :: proc () {
    UI_STATE.pressed = true
}

ui_decide_layout_and_action_state :: proc (id: UiElementId, normal_style, selected_style: cl.ElementDeclaration) -> (cl.ElementDeclaration, bool) {
    style: cl.ElementDeclaration
    should_press := false

    if UI_STATE.selected_list.elem_type == id.type && UI_STATE.selected_list.index == id.index {
        style = selected_style

        if UI_STATE.pressed {
            should_press = true
            UI_STATE.pressed = false
        }
    } else {
        style = normal_style
    }

    return style, should_press
}
