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

game_entries := [][]string {
    {
        "The Legend of Zelda",
        "Rescue the princess lol",
        "cores/fceumm_libretro.so",
        "roms/Legend of Zelda, The (U) (PRG1) [!].nes",
    },
    {
        "Super Mario Bros",
        "Stomp on some goombas and eat mushrooms idk",
        "cores/fceumm_libretro.so",
        "roms/Super Mario Bros. (Europe) (Rev A).nes"
    },
    {
        "Super Castlevania IV",
        "Kill dracula. That's it, go",
        "cores/bsnes_libretro_debug.so",
        "roms/Super Castlevania IV (USA).sfc"
    },
    {
        "Donkey Kong Country GBC",
        "Return to monke",
        "cores/gambatte_libretro.so",
        "roms/Donkey Kong Country (UE).gbc"
    },
}


set_selected_menu_callback :: proc "c" (id: cl.ElementId, pointerData: cl.PointerData, userData: rawptr) {
    if pointerData.state == .PressedThisFrame {
        UI_STATE.selected_menu = MenuType(uintptr(userData))
    }
    if UI_STATE.selected_menu == .QUIT {
        os.exit(0)
    }
}

run_game_callback :: proc "c" (id: cl.ElementId, pointerData: cl.PointerData, userData: rawptr) {
    context = GLOBAL_CONTEXT

    if pointerData.state == .PressedThisFrame {
        game_index := int(uintptr(userData))
        run_game(game_entries[game_index][2], game_entries[game_index][3])
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
        cl.OnHover(set_selected_menu_callback, rawptr(uintptr(type)))
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

// setting :: proc (index: int) {
//     if cl.UI()({
//         layout = {
//             sizing = {
//                 width = cl.SizingGrow({}),
//                 height = cl.SizingFit({ 50, 0 }),
//             },
//             layoutDirection = .TopToBottom,
//         },
//     }) {
//         option := STATE.core_options_definitions.definitions[index]
//         // cl.OnHover(run_game_callback, rawptr(uintptr(index)))
//         cl.Text(string(option.display), cl.TextConfig({
//             textColor = { 255, 255, 255, 255 },
//             fontSize = 20,
//             textAlignment = .Left,
//         }))
//         cl.Text(string(option.info), cl.TextConfig({
//             textColor = { 255, 255, 255, 255 },
//             fontSize = 14,
//             textAlignment = .Left,
//         }))
//     }
// }

menu_entry :: proc (title, description: string, index: int) {
    if cl.UI()({
        layout = {
            sizing = {
                width = cl.SizingGrow({}),
                height = cl.SizingFit({ 50, 0 }),
            },
            layoutDirection = .TopToBottom,
        },
    }) {
        cl.OnHover(run_game_callback, rawptr(uintptr(index)))
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
