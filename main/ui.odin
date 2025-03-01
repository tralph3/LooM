package main



import cl "clay"
import "base:runtime"
import "core:fmt"

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
        if UI_STATE.selected_menu == .PLAY {
            EMULATOR_STATE.running = true
        }
    }
}

menu_entry :: proc (label: string, type: MenuType) {
    if cl.UI()({
        layout = {
            sizing = { width = cl.SizingGrow({}), height = cl.SizingFixed(40) },
            childAlignment = {
                x = .Left,
                y = .Center,
            },
            padding = { 20, 10, 10, 10, },
        },
        backgroundColor = UI_STATE.selected_menu == type ? { 0x28, 0x58, 0x28, 255 } : { 0x18, 0x18, 0x18, 255 },
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

render_ui :: proc (rendererer: proc (^cl.ClayArray(cl.RenderCommand), runtime.Allocator)) {
    cl.BeginLayout()

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
        menu_entry("Play", .PLAY)
        menu_entry("Settings", .SETTINGS)
        menu_entry("Quit", .QUIT)
    }

    render_commands := cl.EndLayout()

    rendererer(&render_commands, context.temp_allocator)
}
