package main

import cl "clay"
import "core:log"

UI_COLOR_BACKGROUND :: cl.Color { 66, 106, 90, 0xFF }
UI_COLOR_SECONDARY_BACKGROUND :: cl.Color { 127, 182, 133, 0xFF }
UI_COLOR_ACCENT :: cl.Color { 242, 197, 124, 0xFF }

UI_COLOR_MAIN_TEXT :: cl.Color { 0xFF, 0xEB, 0xC6, 0xFF }

UI_USER_TILE_SIZE :: 180
UI_USER_TILE_GAP :: UI_SPACING_16

gui_layout_login_user_tile :: proc (username: string, index: int) {
    if cl.UI()({
        backgroundColor = UI_COLOR_SECONDARY_BACKGROUND,
        layout = {
            sizing = {
                width = cl.SizingFixed(UI_USER_TILE_SIZE),
                height = cl.SizingFixed(UI_USER_TILE_SIZE),
            },
            childAlignment = {
                x = .Center,
                y = .Center,
            },
        },
        border = (cl.Hovered() ? {
            color = UI_COLOR_ACCENT,
            width = cl.BorderAll(5),
        } : {}),
        cornerRadius = cl.CornerRadiusAll(5),

    }) {
        cl.TextDynamic(username, cl.TextConfig({
            textColor = UI_COLOR_MAIN_TEXT,
            fontSize = UI_FONTSIZE_24,
        }))
    }
}

gui_layout_login_screen :: proc () -> cl.ClayArray(cl.RenderCommand) {
    cl.BeginLayout()

    if cl.UI()({
        id = cl.ID("Root"),
        backgroundColor = UI_COLOR_BACKGROUND,
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
    }) {
        usernames := []string{"test", "tralph3"}
        for username, index in usernames {
            gui_layout_login_user_tile(username, index)
        }
        gui_layout_login_user_tile("+", len(usernames))
    }

    return cl.EndLayout()
}
