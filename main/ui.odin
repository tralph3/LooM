package main

import cl "clay"
import "base:runtime"
import "core:fmt"
import "core:os"

COLOR_MAIN_BACKGROUND: cl.Color : { 0x18, 0x18, 0x18, 255 }
COLOR_SELECTED: cl.Color : { 0x28, 0x58, 0x28, 255 }

UiState :: struct {
    selected_menu: MenuType,
}

MenuType :: enum {
    NONE,
    PLAY,
    SETTINGS,
    QUIT,
}

UI_STATE := UiState {
    selected_menu = .NONE,
}

set_selected_menu :: proc "c" (id: cl.ElementId, pointerData: cl.PointerData, userData: rawptr) {
    if pointerData.state == .PressedThisFrame {
        // the address is actually the enum value we want to use
        UI_STATE.selected_menu = MenuType(uintptr(userData))
        if UI_STATE.selected_menu == .QUIT {
            os.exit(0)
        }
    }
}

sidebar_entry :: proc (label: string, type: MenuType) {
    if cl.UI()({
        layout = {
            sizing = { width = cl.SizingGrow({}), height = cl.SizingFixed(40) },
            childAlignment = {
                x = .Left,
                y = .Center,
            },
            padding = { 20, 10, 10, 10, },
        },
        backgroundColor = UI_STATE.selected_menu == type ? COLOR_SELECTED : COLOR_MAIN_BACKGROUND,
    }) {
        cl.OnHover(set_selected_menu, rawptr(uintptr(type)))
        cl.Text(
            label,
            cl.TextConfig({
                textColor = { 255, 255, 255, 255 },
                fontSize = 24,
                textAlignment = .Left,
            })
        )
    }
}

menu_entry :: proc (title, description: string) {
    if cl.UI()({
        layout = {
            sizing = { width = cl.SizingGrow({}), height = cl.SizingFixed(50), },
            layoutDirection = .TopToBottom,
        },
    }) {
        cl.Text(title, cl.TextConfig({
            textColor = { 255, 255, 255, 255 },
            fontSize = 20,
            textAlignment = .Left,
        }))
        cl.Text(description, cl.TextConfig({
            textColor = { 255, 255, 255, 255 },
            fontSize = 14,
            textAlignment = .Left,
        }))
    }
}

render_ui :: proc (rendererer: proc (^cl.ClayArray(cl.RenderCommand), runtime.Allocator)) {
    cl.BeginLayout()

    if cl.UI()({
        id = cl.ID("Main Container"),
        layout = {
            sizing = { width = cl.SizingGrow({}), height = cl.SizingGrow({})},
        }
    }) {
        if cl.UI()({
            id = cl.ID("Side Container"),
            layout = {
                sizing = { width = cl.SizingFixed(230), height = cl.SizingGrow({}) },
                padding = { 10, 10, 10, 10, },
                childAlignment = {
                    x = .Center,
                    y = .Center,
                },
                layoutDirection = .TopToBottom,
            },
            backgroundColor = { 0x18, 0x18, 0x18, 255 },
        }) {
            sidebar_entry("Play", .PLAY)
            sidebar_entry("Settings", .SETTINGS)
            sidebar_entry("Quit", .QUIT)
        }

        if cl.UI()({
            id = cl.ID("Main Content Container"),
            layout = {
                layoutDirection = .TopToBottom,
                sizing = { width = cl.SizingGrow({}), height = cl.SizingGrow({})},
                childGap = 16,
                padding = { 20, 20, 20, 20, },
            },
        }) {
            #partial switch UI_STATE.selected_menu {
            case .PLAY:
                menu_entry("Zelda", "This is a description, quite nice looking I'd say.")
                menu_entry("Mario", "This is a description, quite nice looking I'd say.")
                menu_entry("Donkey Kong", "This is a description, quite nice looking I'd say.")
                menu_entry("Resident Evil", "This is a description, quite nice looking I'd say.")
            case .SETTINGS:
                menu_entry("Setting 1", "This is a description, quite nice looking I'd say.")
                menu_entry("Setting 2", "This is a description, quite nice looking I'd say.")
                menu_entry("Setting 3", "This is a description, quite nice looking I'd say.")
                menu_entry("Setting 4", "This is a description, quite nice looking I'd say.")
            }

        }
    }


    render_commands := cl.EndLayout()

    rendererer(&render_commands, context.temp_allocator)
}
