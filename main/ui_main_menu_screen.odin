package main

import cl "clay"

ui_layout_main_menu_screen :: proc () {
    if cl.UI()({
        layout = {
            sizing = { width = cl.SizingGrow({}), height = cl.SizingGrow({}) },
            childAlignment = {
                x = .Center,
                y = .Center,
            },
        },
        backgroundColor = UI_BACKGROUND_COLOR,
    }) {
        cl.Text("This is the main menu, nothing here for now...", cl.TextConfig({
            textColor = { 0xFF, 0xFF, 0xFF, 0xFF },
            fontSize = 24,
        }))
    }
}
