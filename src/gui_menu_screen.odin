package main

import cl "clay"
import sdl "vendor:sdl3"
import "core:math/ease"
import "core:log"

@(private="file")
game_entry_button :: proc (entry: ^GameEntry) -> (clicked: bool) {
    if cl.UI()({
        layout = {
            sizing = {
                width = cl.SizingGrow({}),
                height = cl.SizingGrow({}),
            },
            layoutDirection = .LeftToRight,
            padding = cl.PaddingAll(24),
        },
        cornerRadius = cl.CornerRadiusAll(10),
        backgroundColor = UI_COLOR_SECONDARY_BACKGROUND,
        border = cl.Hovered() ? {
            color = UI_COLOR_ACCENT,
            width = cl.BorderOutside(10),
        } : {},
    }) {
        if cl.UI()({
            layout = {
                sizing = {
                    width = cl.SizingFit({}),
                    height = cl.SizingFit({}),
                },
                layoutDirection = .TopToBottom,
            },
        }) {
            cl.TextDynamic(string(entry.path), cl.TextConfig({
                textColor = UI_COLOR_MAIN_TEXT,
                fontSize = 24,
            }))

            cl.TextDynamic(string(entry.core), cl.TextConfig({
                textColor = UI_COLOR_MAIN_TEXT,
                fontSize = 16,
            }))
        }

        clicked = gui_is_clicked()
    }

    return
}

gui_layout_menu_screen :: proc () -> cl.ClayArray(cl.RenderCommand) {
    cl.BeginLayout()

    if cl.UI()({
        id = cl.ID("Root"),
        layout = {
            sizing = {
                width = cl.SizingGrow({}),
                height = cl.SizingGrow({}),
            },
            childAlignment = {
                x = .Center,
                y = .Center,
            },
            layoutDirection = .TopToBottom,
        },
        backgroundColor = { 0, 0, 0, 255 },
    }) {
        if cl.UI()({
            id = cl.ID("Game List"),
            layout = {
                sizing = {
                    width = cl.SizingGrow({}),
                    height = cl.SizingGrow({}),
                },
                childAlignment = {
                    x = .Center,
                    y = .Center,
                },
                childGap = 16,
                layoutDirection = .TopToBottom,
                padding = {
                    left = 128,
                    right = 128,
                },
            },
            clip = {
                vertical = true,
                childOffset = cl.GetScrollOffset(),
            },
            backgroundColor = UI_COLOR_BACKGROUND,
        }) {
            for &entry in GLOBAL_STATE.game_entries {
                if game_entry_button(&entry) {
                    if core_load_game(entry.core, entry.path) {
                        scene_change(.RUNNING)
                    }
                }
            }
        }
    }

    return cl.EndLayout()
}
