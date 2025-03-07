package main

import cl "clay"

USERS: []string = {
    "tralph3",
    "urmom",
    "xXx__slayer__xXx",
    "takenUser420"
}

ui_layout_login_user_tile :: proc (username: string, index: int) {
    id := UiElementId { .USER_TILE, index }
    styling: cl.ElementDeclaration
    if UI_STATE.selected == id {
        styling = UI_USER_TILE_STYLING_SELECTED

        if UI_STATE.pressed {
            login_with_user(username)
            UI_STATE.pressed = false
        }
    } else {
        styling = UI_USER_TILE_STYLING
    }

    if cl.UI()(styling) {
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
        for username, index in USERS {
            ui_layout_login_user_tile(username, index)
        }
    }
}
