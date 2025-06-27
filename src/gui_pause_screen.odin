package main

import cl "clay"
import sdl "vendor:sdl3"
import "core:math/ease"
import "core:log"

gui_quick_access_button_layout :: proc (label: string, cb: proc ()) {
    if cl.UI()({
        layout = {
            sizing = {
                width = cl.SizingGrow({}),
                height = cl.SizingGrow({}),
            },
            padding = cl.PaddingAll(24),
        },
        cornerRadius = cl.CornerRadiusAll(10),
        backgroundColor = UI_COLOR_BACKGROUND,
        border = cl.Hovered() ? {
            color = UI_COLOR_ACCENT,
            width = cl.BorderOutside(10),
        } : {},
    }) {
        cl.TextDynamic(label, cl.TextConfig({
            textColor = UI_COLOR_MAIN_TEXT,
            fontSize = 24,
        }))

        if cl.Hovered() {
            state := sdl.GetMouseState(nil, nil)

            if .LEFT in state {
                cb()
            }
        }
    }
}

gui_core_option_layout :: proc (option: ^CoreOption) {
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
        backgroundColor = UI_COLOR_BACKGROUND,
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
            cl.TextDynamic(string(option.display), cl.TextConfig({
                textColor = UI_COLOR_MAIN_TEXT,
                fontSize = 24,
            }))

            cl.TextDynamic(string(option.info), cl.TextConfig({
                textColor = UI_COLOR_MAIN_TEXT,
                fontSize = 16,
            }))
        }

        if cl.UI()({
            layout = {
                sizing = {
                    width = cl.SizingGrow({}),
                    height = cl.SizingGrow({}),
                },
            },
        }) {}

        if cl.UI()({
            layout = {
                sizing = {
                    width = cl.SizingFit({}),
                    height = cl.SizingFit({}),
                },
                layoutDirection = .TopToBottom,
            },
        }) {
            cl.TextDynamic(string(option.current_value), cl.TextConfig({
                textColor = UI_COLOR_MAIN_TEXT,
                fontSize = 24,
                textAlignment = .Right,
            }))
        }
    }
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
                id = cl.ID("Quick Access"),
                layout = {
                    sizing = {
                        width = cl.SizingPercent(0.5),
                        height = cl.SizingGrow({}),
                    },
                    layoutDirection = .TopToBottom,
                },
                border = {
                    color = { 0, 0, 0, 255 },
                    width = { 0, 0, 5, 0, 0 },
                },
                backgroundColor = UI_COLOR_SECONDARY_BACKGROUND,
            }) {
                gui_quick_access_button_layout("Resume", proc () {
                    scene_change(.RUNNING)
                })
                gui_quick_access_button_layout("Reset", proc () {
                    reset_game()
                    scene_change(.RUNNING)
                })
                gui_quick_access_button_layout("Close", proc () {
                    unload_game()
                    scene_change(.LOGIN)
                })
            }

            if cl.UI()({
                id = cl.ID("Game Container"),
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
            backgroundColor = UI_COLOR_SECONDARY_BACKGROUND,
        }) {
            for _, &option in GLOBAL_STATE.emulator_state.options {
                if option.visible {
                    gui_core_option_layout(&option)
                }
            }
        }
    }

    return cl.EndLayout()
}
