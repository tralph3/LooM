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
            aspectRatio = { emulator_get_aspect_ratio() },
            custom = { rawptr(uintptr(CustomRenderType.EmulatorFramebuffer)) },
        }) { }
    }

    return cl.EndLayout()
}
