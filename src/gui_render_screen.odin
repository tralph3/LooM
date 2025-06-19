package main

import cl "clay"

gui_layout_render_screen :: proc () -> cl.ClayArray(cl.RenderCommand) {
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
        },
        backgroundColor = {0, 0, 0, 255},
    }) {
        if cl.UI()({
            id = cl.ID("Game"),
            layout = {
                sizing = {
                    width = cl.SizingGrow({}),
                    height = cl.SizingGrow({}),
                },
            },
            aspectRatio = { GLOBAL_STATE.emulator_state.av_info.geometry.aspect_ratio },
            image = { GLOBAL_STATE.video_state.render_texture },
        }) { }
    }

    return cl.EndLayout()
}
