package main

import cl "clay"
import "core:fmt"

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
            layoutDirection = .TopToBottom,
        },
        backgroundColor = { 0, 0, 0, 255 },
    }) {
        // AUDIO BUFFER DEBUG STUFF
        // if cl.UI()({
        //     layout = {
        //         sizing = {
        //             width = cl.SizingGrow({}),
        //         },
        //         layoutDirection = .TopToBottom,
        //     },
        // }) {
        //     if cl.UI()({
        //         layout = {
        //             sizing = {
        //                 width = cl.SizingFixed(500),
        //                 height = cl.SizingFixed(30),
        //             },
        //         },
        //         backgroundColor = { 255, 0, 0, 255 },
        //     }) {
        //         if cl.UI()({
        //             layout = {
        //                 sizing = {
        //                     width = cl.SizingFixed(audio_get_buffer_fill_rate() * 500),
        //                     height = cl.SizingFixed(30),
        //                 },
        //             },
        //             backgroundColor = { 0, 255, 0, 255 },
        //         }) {}
        //     }
        //     cl.TextDynamic(fmt.tprintf("Sleep for: {}", audio_should_sleep_for()), &{
        //         fontSize = 24,
        //         textColor = UI_COLOR_MAIN_TEXT,
        //         textAlignment = .Left,
        //     })
        // }

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

    notifications_evict_and_layout()

    return cl.EndLayout()
}
