package main

import cl "clay"
import "core:log"
import sdl "vendor:sdl3"

gui_layout_login_user_tile :: proc (username: string) -> (clicked: bool) {
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
        border = (gui_is_focused() ? {
            color = UI_COLOR_ACCENT,
            width = cl.BorderAll(5),
        } : {}),
        cornerRadius = cl.CornerRadiusAll(10),
    }) {
        cl.TextDynamic(username, cl.TextConfig({
            textColor = UI_COLOR_MAIN_TEXT,
            fontSize = UI_FONTSIZE_24,
        }))

        clicked = gui_is_clicked()
    }

    return
}

gui_layout_login_add_user :: proc () {
    if cl.UI()({
        id = cl.ID("Add User"),
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
        border = (gui_is_focused() ? {
            color = UI_COLOR_ACCENT,
            width = cl.BorderAll(5),
        } : {}),
        cornerRadius = cl.CornerRadiusAll(UI_USER_TILE_SIZE / 2),
    }) {
        cl.Text("+", cl.TextConfig({
            textColor = UI_COLOR_MAIN_TEXT,
            fontSize = UI_FONTSIZE_72,
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
            layoutDirection = .TopToBottom,
        },
    }) {
        if cl.UI()({

        }) {
            cl.Text("Welcome!", &{
                textColor = UI_COLOR_MAIN_TEXT,
                fontSize = UI_FONTSIZE_72,
            })
        }

        if cl.UI()({
            id = cl.ID("Users Container"),
            layout = {
                childGap = UI_USER_TILE_GAP,
            },
        }) {
            usernames := []string{"test", "tralph3"}
            for username in usernames {
                if gui_layout_login_user_tile(username) {
                    user_login(username)
                }
            }

            gui_layout_login_add_user()
        }
    }

    return cl.EndLayout()
}
