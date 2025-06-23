package main

import cl "clay"
import sdl "vendor:sdl3"

gui_layout_pause_screen :: proc () -> cl.ClayArray(cl.RenderCommand) {
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
        window_x: i32
        window_y: i32
        sdl.GetWindowSize(GLOBAL_STATE.video_state.window, &window_x, &window_y)

        if cl.UI()({
            id = cl.ID("Top Container"),
            layout = {
                sizing = {
                    width = cl.SizingGrow({}),
                    height = cl.SizingPercent(0.5),
                },
                childAlignment = {
                    x = .Center,
                    y = .Center,
                },
                layoutDirection = .LeftToRight,
            },
            backgroundColor = { 0, 0, 0, 255 },
        }) {
            if cl.UI()({
                id = cl.ID("Stats"),
                layout = {
                    sizing = {
                        width = cl.SizingPercent(0.5),
                        height = cl.SizingGrow({}),
                    },
                },
                border = {
                    color = { 0, 0, 0, 255 },
                    width = { 0, 0, 5, 0, 0 },
                },
                backgroundColor = UI_COLOR_SECONDARY_BACKGROUND,
            }) {}

            if cl.UI()({
                id = cl.ID("Game Container"),
                layout = {
                    sizing = {
                        width = cl.SizingPercent(0.5),
                        height = cl.SizingGrow({}),
                    },
                    childAlignment = {
                        x = .Center,
                        y = .Center,
                    },
                },
                backgroundColor = { 0, 0, 0, 255 },
                border = {
                    color = { 0, 0, 0, 255 },
                    width = { 0, 0, 5, 0, 0 },
                },
            }) {
                if cl.UI()({
                    id = cl.ID("Game"),
                    layout = {
                        sizing = {
                            width = cl.SizingGrow({}),
                            height = cl.SizingGrow({}),
                        },
                    },
                    aspectRatio = { f32(GLOBAL_STATE.video_state.actual_width) / f32(GLOBAL_STATE.video_state.actual_height) },
                    image = { rawptr(uintptr(fbo_id)) },

                }) { }
            }
        }

        if cl.UI()({
            id = cl.ID("Bottom Container"),
            layout = {
                sizing = {
                    width = cl.SizingGrow({}),
                    height = cl.SizingPercent(0.5),
                },
                childAlignment = {
                    x = .Center,
                    y = .Center,
                },
            },
            backgroundColor = UI_COLOR_BACKGROUND,
        }) {}

    }

    return cl.EndLayout()
}
