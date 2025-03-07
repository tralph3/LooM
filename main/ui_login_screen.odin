package main

import cl "clay"

UI_USER_TILE_SIZE :: 120
UI_USER_TILE_GAP :: UI_SPACING_16

ui_layout_login_user_tile :: proc (name: string) {
    if cl.UI()({
        backgroundColor = UI_SECONDARY_BACKGROUND_COLOR,
        layout = {
            sizing = {
                width = cl.SizingFit({ min = UI_USER_TILE_SIZE }),
                height = cl.SizingFit({ min = UI_USER_TILE_SIZE }),
            },
            childAlignment = {
                x = .Center,
                y = .Bottom,
            },
        },
    }) {
        cl.Text(name, cl.TextConfig({
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
        ui_layout_login_user_tile("tralph3")
        ui_layout_login_user_tile("urmom")
    }
}
