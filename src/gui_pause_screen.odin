package main

import cl "clay"
import sdl "vendor:sdl3"
import "core:math/ease"
import "core:log"
import g "gui"

@(private="file")
Submenu :: enum {
    None,
    Shaders,
}

@(private="file")
PAUSE_MENU_STATE := struct #no_copy {
    submenu: Submenu
} {}

@(private="file")
pause_change_submenu :: proc (submenu: Submenu) {
    gui_reset_focus()
    gui_set_default_focus_element(cl.ID("No Shader"))
    PAUSE_MENU_STATE.submenu = submenu
}

gui_pause_get_default_focus_element :: proc () -> cl.ElementId {
    return cl.ID("Resume")
}

gui_pause_button_layout :: proc (label: string) -> (clicked: bool) {
    id := cl.ID(label)

    if cl.UI()({
        id = id,
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
        cornerRadius = cl.CornerRadiusAll(5),
        backgroundColor = gui_is_focused(id) \
            ? UI_COLOR_ACCENT \
            : {},
    }) {
        gui_register_focus_element(id)

        cl.TextDynamic(label, &UI_PAUSE_BUTTON_TEXT_CONFIG)

        clicked = gui_is_clicked(id)
    }

    return
}

gui_layout_shader_menu :: proc () {
    cl.Text("Want some shaders, kid?", &UI_PAUSE_BUTTON_TEXT_CONFIG)

    if gui_pause_button_layout("Back") {
        pause_change_submenu(.None)
    }
    if gui_pause_button_layout("No Shader") {
        gui_renderer_set_framebuffer_shader(fragment_framebuffer_shader_src)
    }
    if gui_pause_button_layout("CRT Mattias") {
        gui_renderer_set_framebuffer_shader(crt_mattias_framebuffer_shader_src)
    }
}

gui_layout_main_pause_options :: proc () {
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
    if gui_pause_button_layout("LooM Options") {
        log.info("LooM!")
    }
    if gui_pause_button_layout("Shaders") {
        pause_change_submenu(.Shaders)
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
                x = PAUSE_MENU_STATE.submenu == .Shaders ? .Right : .Center,
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
                    x = PAUSE_MENU_STATE.submenu == .Shaders ? .Left : .Center,
                },
                layoutDirection = .TopToBottom,
            },
            floating = {
	            attachment = {
                    element = .LeftTop,
                    parent = .LeftTop,
                },
                attachTo = .Root,
            },
            backgroundColor = PAUSE_MENU_STATE.submenu == .Shaders ? {} : { 0, 0, 0, 170 },
        }) {
            widgets_header_bar()
            if cl.UI()({
                layout = {
                    sizing = {
                        width = cl.SizingGrow({}),
                        height = cl.SizingGrow({}),
                    },
                    childAlignment = {
                        x = PAUSE_MENU_STATE.submenu == .Shaders ? .Left : .Center,
                        y = .Center,
                    }
                }
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
                    if PAUSE_MENU_STATE.submenu == .Shaders {
                        gui_layout_shader_menu()
                    } else {
                        gui_layout_main_pause_options()
                    }
                }
            }
        }
    }

    notifications_evict_and_layout()

    return cl.EndLayout()
}
