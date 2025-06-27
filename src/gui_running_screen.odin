package main

import cl "clay"

gui_layout_running_screen :: proc () -> cl.ClayArray(cl.RenderCommand) {
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
        backgroundColor = { 0, 0, 0, 255 },
    }) {
        if cl.UI()({
            id = cl.ID("Game"),
            layout = {
                sizing = {
                    width = cl.SizingGrow({}),
                    height = cl.SizingGrow({}),
                },
            },
            aspectRatio = { f32(GLOBAL_STATE.emulator_state.av_info.geometry.base_width) / f32(GLOBAL_STATE.emulator_state.av_info.geometry.base_height) },
            custom = {
                &CustomRenderData {
                    type = .EmulatorFramebuffer,
                }
            }
        }) { }
    }

    return cl.EndLayout()
}
