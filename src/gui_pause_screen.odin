package main

import cl "clay"
import sdl "vendor:sdl3"
import "core:math/ease"
import "core:log"

gui_pause_button_layout :: proc (label: string) -> (clicked: bool) {
    if cl.UI()({
        layout = {
            sizing = {
                width = cl.SizingGrow({}),
            },
            childAlignment = {
                x = .Center,
            },
            padding = {
                top = UI_SPACING_12,
                bottom = UI_SPACING_12,
                left = UI_SPACING_32,
                right = UI_SPACING_32,
            },
        },
        border = gui_is_focused() ? {
            color = UI_COLOR_ACCENT,
            width = cl.BorderOutside(10),
        } : {},
        cornerRadius = cl.CornerRadiusAll(5),
        backgroundColor = UI_COLOR_SECONDARY_BACKGROUND,
    }) {
        cl.TextDynamic(label, &UI_PAUSE_BUTTON_TEXT_CONFIG)

        clicked = gui_is_clicked()
    }

    return
}

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

        if cl.UI()({
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
            floating = {
	            attachment = {
                    element = .LeftTop,
                    parent = .LeftTop,
                },
                attachTo = .Root,
            },
            backgroundColor = { 0, 0, 0, 170 },
        }) {
            if cl.UI()({
                id = cl.ID("Pause Options Container"),
                layout = {
                    sizing = {
                        width = cl.SizingFixed(UI_SPACING_256),
                    },
                    padding = cl.PaddingAll(UI_SPACING_12),
                    layoutDirection = .TopToBottom,
                    childGap = UI_SPACING_12,
                },
                cornerRadius = cl.CornerRadiusAll(5),
                backgroundColor = UI_COLOR_BACKGROUND,
            }) {
                cl.Text("PAUSED", &UI_PAUSE_BUTTON_TEXT_CONFIG)

                if gui_pause_button_layout("Resume") {
                    scene_change(.RUNNING)
                }
                if gui_pause_button_layout("Save State") {
                    event_push(.SaveState)
                }
                if gui_pause_button_layout("Load State") {
                    event_push(.LoadState)
                }
                if gui_pause_button_layout("Controller") {
                    log.info("Controller config!")
                }
                if gui_pause_button_layout("Emulator Options") {
                    log.info("EMU!")
                }
                if gui_pause_button_layout("LOOM Options") {
                    log.info("LOOM!")
                }
                if gui_pause_button_layout("Shaders") {
                    log.info("Shader menu!")
                }
                if gui_pause_button_layout("Manual") {
                    log.info("Game manual!")
                }
                if gui_pause_button_layout("Reset") {
                    emulator_reset_game()
                    scene_change(.RUNNING)
                }
                if gui_pause_button_layout("Hard Reset") {
                    emulator_hard_reset_game()
                    scene_change(.RUNNING)
                }
                if gui_pause_button_layout("Close") {
                    emulator_close()
                    scene_change(.MENU)
                }
            }
        }
    }

    return cl.EndLayout()
}
