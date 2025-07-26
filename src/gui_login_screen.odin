package main

import cl "clay"
import "core:log"
import sdl "vendor:sdl3"

gui_login_get_default_focus_element :: proc () -> cl.ElementId {
    return cl.ID("Login Tile", 0)
}

gui_layout_login_user_tile :: proc (username: string, idx: int) -> (clicked: bool) {
    id := cl.ID("Login Tile", u32(idx))
    if cl.UI()({
        id = id,
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
        backgroundColor = gui_is_focused(id) \
            ? UI_COLOR_ACCENT \
            : {},
        cornerRadius = cl.CornerRadiusAll(10),
    }) {
        gui_register_focus_element(id)

        cl.TextDynamic(username, cl.TextConfig({
            textColor = UI_COLOR_MAIN_TEXT,
            fontSize = UI_FONTSIZE_24,
        }))

        clicked = gui_is_clicked(id)
    }

    return
}

gui_layout_login_add_user :: proc () {
    id := cl.ID("Add User")
    if cl.UI()({
        id = id,
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
        border = (gui_is_focused(id) ? {
            color = UI_COLOR_ACCENT,
            width = cl.BorderAll(5),
        } : {}),
        cornerRadius = cl.CornerRadiusAll(UI_USER_TILE_SIZE / 2.0),
    }) {
        gui_register_focus_element(id)
        cl.Text("+", cl.TextConfig({
            textColor = UI_COLOR_MAIN_TEXT,
            fontSize = UI_FONTSIZE_72,
        }))
    }
}

gui_layout_login_screen :: proc () -> cl.ClayArray(cl.RenderCommand) {
    cl.BeginLayout()

    if widgets_container(childAlignment={.Center, .Center}, direction=.TopToBottom) {
        widgets_header_bar()

        cl.Text("Welcome!", &{
            fontId = auto_cast FontID.Title,
            textColor = UI_COLOR_MAIN_TEXT,
            fontSize = UI_FONTSIZE_72,
        })

        if cl.UI()({
            layout = {
                childGap = UI_USER_TILE_GAP,
            },
        }) {
            usernames := []string{"tralph3", "Shadow", "Celes"}
            for username, i in usernames {
                if gui_layout_login_user_tile(username, i) {
                    user_login(username)
                }
            }
        }
    }

    notifications_evict_and_layout()

    return cl.EndLayout()
}
