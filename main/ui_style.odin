package main

import cl "clay"

// COLORS
UI_COLOR_BACKGROUND :: cl.Color { 0x00, 0x38, 0x44, 0xFF }
UI_COLOR_SECONDARY_BACKGROUND :: cl.Color { 0x00, 0x6C, 0x67, 0xFF }
UI_COLOR_ACCENT :: cl.Color { 0x04, 0x8B, 0xA8, 0xFF }

UI_COLOR_MAIN_TEXT :: cl.Color { 0xFF, 0xEB, 0xC6, 0xFF }

// USER TILE
UI_USER_TILE_STYLING: cl.ElementDeclaration = {
    backgroundColor = UI_COLOR_SECONDARY_BACKGROUND,
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
    backgroundColor = UI_COLOR_SECONDARY_BACKGROUND,
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

// MENU ENTRY
UI_MENU_ENTRY_STYLING: cl.ElementDeclaration = {
    layout = {
        sizing = {
            width = cl.SizingGrow({}),
            height = cl.SizingFixed(UI_SPACING_64),
        },
        padding = { UI_SPACING_24, 0, 0, 0 },
        childAlignment = {
            y = .Center,
        },
    },
}

UI_MENU_ENTRY_STYLING_SELECTED: cl.ElementDeclaration = {
    layout = {
        sizing = {
            width = cl.SizingGrow({}),
            height = cl.SizingFixed(UI_SPACING_64),
        },
        padding = { UI_SPACING_24, 0, 0, 0 },
        childAlignment = {
            y = .Center,
        },
    },
    backgroundColor = UI_COLOR_ACCENT,
}
