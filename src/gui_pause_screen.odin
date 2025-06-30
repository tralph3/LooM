package main

import cl "clay"
import sdl "vendor:sdl3"
import "core:math/ease"
import "core:log"

@(rodata)
UI_PAUSE_BUTTON_TEXT_CONFIG := cl.TextElementConfig {
    textColor = UI_COLOR_MAIN_TEXT,
    fontSize = 24,
    textAlignment = .Center,
}

gui_pause_button_layout :: proc (label: string, callback: proc ()) {
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

        if gui_is_clicked() {
            callback()
        }
    }
}

// gui_quick_access_button_layout :: proc (label: string, cb: proc ()) {
//     if cl.UI()({
//         layout = {
//             sizing = {
//                 width = cl.SizingGrow({}),
//                 height = cl.SizingGrow({}),
//             },
//             padding = cl.PaddingAll(24),
//         },
//         cornerRadius = cl.CornerRadiusAll(10),
//         backgroundColor = UI_COLOR_BACKGROUND,
//         border = cl.Hovered() ? {
//             color = UI_COLOR_ACCENT,
//             width = cl.BorderOutside(10),
//         } : {},
//     }) {
//         cl.TextDynamic(label, cl.TextConfig({
//             textColor = UI_COLOR_MAIN_TEXT,
//             fontSize = 24,
//         }))

//         if gui_is_clicked() {
//             cb()
//         }
//     }
// }

// gui_core_option_layout :: proc (option: ^CoreOption) {
//     if cl.UI()({
//         layout = {
//             sizing = {
//                 width = cl.SizingGrow({}),
//                 height = cl.SizingGrow({}),
//             },
//             layoutDirection = .LeftToRight,
//             padding = cl.PaddingAll(24),
//         },
//         cornerRadius = cl.CornerRadiusAll(10),
//         backgroundColor = UI_COLOR_BACKGROUND,
//         border = cl.Hovered() ? {
//             color = UI_COLOR_ACCENT,
//             width = cl.BorderOutside(10),
//         } : {},
//     }) {
//         if cl.UI()({
//             layout = {
//                 sizing = {
//                     width = cl.SizingFit({}),
//                     height = cl.SizingFit({}),
//                 },
//                 layoutDirection = .TopToBottom,
//             },
//         }) {
//             cl.TextDynamic(string(option.display), cl.TextConfig({
//                 textColor = UI_COLOR_MAIN_TEXT,
//                 fontSize = 24,
//             }))

//             cl.TextDynamic(string(option.info), cl.TextConfig({
//                 textColor = UI_COLOR_MAIN_TEXT,
//                 fontSize = 16,
//             }))
//         }

//         if cl.UI()({
//             layout = {
//                 sizing = {
//                     width = cl.SizingGrow({}),
//                     height = cl.SizingGrow({}),
//                 },
//             },
//         }) {}

//         if cl.UI()({
//             layout = {
//                 sizing = {
//                     width = cl.SizingFit({}),
//                     height = cl.SizingFit({}),
//                 },
//                 layoutDirection = .TopToBottom,
//             },
//         }) {
//             cl.TextDynamic(string(option.current_value), cl.TextConfig({
//                 textColor = UI_COLOR_MAIN_TEXT,
//                 fontSize = 24,
//                 textAlignment = .Right,
//             }))
//         }
//     }
// }

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
            aspectRatio = { f32(GLOBAL_STATE.emulator_state.av_info.geometry.base_width) / f32(GLOBAL_STATE.emulator_state.av_info.geometry.base_height) },
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

                gui_pause_button_layout("Resume", proc () {
                    scene_change(.RUNNING)
                })
                gui_pause_button_layout("Save State", proc () {
                    event_push(.SaveState)
                })
                gui_pause_button_layout("Load State", proc () {
                    event_push(.LoadState)
                })
                gui_pause_button_layout("Controller", proc () {
                    log.info("Controller config!")
                })
                gui_pause_button_layout("Shaders", proc () {
                    log.info("Shader menu!")
                })
                gui_pause_button_layout("Manual", proc () {
                    log.info("Game manual!")
                })
                gui_pause_button_layout("Reset", proc () {
                    emulator_reset_game()
                    scene_change(.RUNNING)
                })
                gui_pause_button_layout("Hard Reset", proc () {
                    core_hard_reset()
                    scene_change(.RUNNING)
                })
                gui_pause_button_layout("Close", proc () {
                    core_unload_game()
                    scene_change(.MENU)
                })
            }
        }
    }

    return cl.EndLayout()
}
