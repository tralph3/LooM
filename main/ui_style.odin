package main

import cl "clay"

// COLORS
UI_BACKGROUND_COLOR :: cl.Color { 0x00, 0x38, 0x44, 0xFF }
UI_SECONDARY_BACKGROUND_COLOR :: cl.Color { 0x00, 0x6C, 0x67, 0xFF }

UI_MAIN_TEXT_COLOR :: cl.Color { 0xFF, 0xEB, 0xC6, 0xFF }

// USER TILE
UI_USER_TILE_STYLING: cl.ElementDeclaration = {
    backgroundColor = UI_SECONDARY_BACKGROUND_COLOR,
    layout = {
        sizing = {
            width = cl.SizingFixed(UI_USER_TILE_SIZE),
            height = cl.SizingFixed(UI_USER_TILE_SIZE),
        },
        childAlignment = {
            x = .Center,
            y = .Bottom,
        },
    },
}

UI_USER_TILE_STYLING_SELECTED: cl.ElementDeclaration = {
    backgroundColor = UI_SECONDARY_BACKGROUND_COLOR,
    layout = {
        sizing = {
            width = cl.SizingFixed(UI_USER_TILE_SIZE * 1.1),
            height = cl.SizingFixed(UI_USER_TILE_SIZE * 1.1),
        },
        childAlignment = {
            x = .Center,
            y = .Bottom,
        },
    },
}

UI_USER_TILE_SIZE :: 180
UI_USER_TILE_GAP :: UI_SPACING_16
