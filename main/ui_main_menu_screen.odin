package main

import cl "clay"
import "core:fmt"
import "core:log"

@(private="file")
UiMenuEntries :: enum {
    Play = 0,
    Settings,
    Logout,
    Quit,
}

UiMenuEntriesDefinition: UiListDefinition = {
    orientation = .Vertical,
    elem_type = .MAIN_MENU_ENTRY,
}

ui_handle_menu_item_press :: proc (entry: UiMenuEntries) {
    #partial switch entry {
        case .Logout:
        logout()
        case .Quit:
        log.warn("Exiting not yet implemented")
    }
}

ui_menu_init :: proc () {
    UiMenuEntriesDefinition.elem_count = len(UiMenuEntries)
    UI_STATE.selected_list.next_list = &UiMenuEntriesDefinition
}

ui_layout_menu_entry :: proc (entry: UiMenuEntries) {
    style, should_press := ui_decide_layout_and_action_state(
        { .MAIN_MENU_ENTRY, int(entry) }, UI_MENU_ENTRY_STYLING, UI_MENU_ENTRY_STYLING_SELECTED)

    if should_press {
        ui_handle_menu_item_press(entry)
    }

    if cl.UI()(style) {
        cl.Text(fmt.aprint(entry), cl.TextConfig({
            textColor = UI_MAIN_TEXT_COLOR,
            fontSize = UI_FONTSIZE_24,
        }))
    }
}

ui_layout_main_menu_screen :: proc () {
    if cl.UI()({
        layout = {
            sizing = { width = cl.SizingGrow({}), height = cl.SizingGrow({}) },
        },
        backgroundColor = UI_COLOR_BACKGROUND,
    }) {
        if cl.UI()({
            layout = {
                sizing = {
                    width = cl.SizingFixed(UI_SPACING_256),
                    height = cl.SizingGrow({}),
                },
                layoutDirection = .TopToBottom,
                childAlignment = {
                    y = .Bottom,
                },
            },
            backgroundColor = UI_COLOR_SECONDARY_BACKGROUND,
        }) {
            for entry in UiMenuEntries {
                ui_layout_menu_entry(entry)
            }
        }
    }
}
