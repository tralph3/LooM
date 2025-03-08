package main

import cl "clay"
import "core:log"

UserListDefinition: UiListDefinition = {
    orientation = .Horizontal,
    elem_type = .USER_TILE,
}

ui_login_init :: proc () {
    UserListDefinition.elem_count = len(STATE.config.users)
}

ui_layout_login_user_tile :: proc (username: string, index: int) {
    style, should_press := ui_decide_layout_and_action_state(
        { .USER_TILE, index }, UI_USER_TILE_STYLING, UI_USER_TILE_STYLING_SELECTED)

    if should_press {
        login_with_user(username)
    }

    if cl.UI()(style) {
        cl.Text(username, cl.TextConfig({
            textColor = UI_MAIN_TEXT_COLOR,
            fontSize = UI_FONTSIZE_24,
        }))
    }
}

ui_layout_login_screen :: proc () {
    if cl.UI()({
        id = cl.ID("Main Container"),
        backgroundColor = UI_BACKGROUND_COLOR,
        layout = {
            sizing = {
                width = cl.SizingGrow({}),
                height = cl.SizingGrow({}),
            },
            childAlignment = {
                x = .Center,
                y = .Center,
            },
            childGap = UI_USER_TILE_GAP,
        },
        scroll = { horizontal = true }
    }) {
        for username, index in STATE.config.users {
            ui_layout_login_user_tile(username, index)
        }
    }
}
