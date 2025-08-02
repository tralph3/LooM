package main

import cl "clay"
import sdl "vendor:sdl3"
import "core:math/ease"
import "core:log"
import fp "core:path/filepath"
import g "gui"

GRID_ITEM_WIDTH :: 210

gui_menu_get_default_focus_element :: proc () -> cl.ElementId {
    return cl.ID("Rom Entry", 0)
}

@(private="file")
game_entry_button :: proc (entry: RomEntry, idx: u32) {
    id := cl.ID("Rom Entry", idx)

    if g.container(.TopToBottom, { .GrowX, .GrowY }, id) {
        gui_register_focus_element(id)
        file_name := fp.base(string(entry.name))
        name := fp.base(string(entry.display_name))
        system_name := string(entry.category)

        if gui_is_focused(id) {
            gui_scroll_container_to_focus(cl.ID("Game Grid"))
        }

        if cl.UI()({
            id = cl.ID("Cover", idx),
            layout = {
                sizing = {
                    width = cl.SizingGrow({}),
                    height = cl.SizingGrow({}),
                },
                childAlignment = {
                    x = .Center,
                    y = .Bottom,
                },
                padding = cl.PaddingAll(UI_SPACING_4),
            },
        }) {
            if gui_is_element_near_bounds(cl.ID("Cover", idx)) {
                cover_texture := cover_get(system_name, file_name)
                if cl.UI()({
                    layout = {
                        sizing = {
                            width = cl.SizingGrow({}),
                            height = cl.SizingGrow({}),
                        },
                    },
                    aspectRatio = { cover_texture.width / cover_texture.height },
                    image = { rawptr(uintptr(cover_texture.gl_id)) },
                    border = gui_is_focused(id) ? {
                        color = UI_COLOR_MAIN_TEXT,
                        width = cl.BorderAll(12),
                    } : {}
                }) { }
            }
        }

        if cl.UI()({
            layout = {
                sizing = {
                    width = cl.SizingGrow({}),
                    height = cl.SizingFixed(40),
                },
                layoutDirection = .TopToBottom,
                childAlignment = {
                    x = .Center,
                    y = .Center,
                },
            },
        }) {
            cl.TextDynamic(name, cl.TextConfig({
                textColor = UI_COLOR_MAIN_TEXT,
                textAlignment = .Center,
                fontSize = 12,
            }))
        }

        if gui_is_clicked(id) {
            entry := entry
            if emulator_init(&entry) {
                scene_change(.RUNNING)
            }
        }
    }
}

gui_layout_menu_screen :: proc () -> cl.ClayArray(cl.RenderCommand) {
    cl.BeginLayout()

    if g.container(.TopToBottom, { .GrowX }) {
        widgets_header_bar(floating=false)

        grid_id := cl.ID("Game Grid")
        g.grid(GLOBAL_STATE.rom_entries[:], { GRID_ITEM_WIDTH, GRID_ITEM_WIDTH / 0.75 }, game_entry_button, grid_id)

        if cl.UI()({
            id = cl.ID("Bottom Bar"),
            layout = {
                sizing = {
                    width = cl.SizingGrow({}),
                    height = cl.SizingFixed(UI_SPACING_64),
                },
                childAlignment = {
                    y = .Center,
                },
                padding = {
                    left = UI_SPACING_12,
                    right = UI_SPACING_12,
                },
            },
            backgroundColor = UI_COLOR_BACKGROUND,
            border = {
                color = UI_COLOR_SECONDARY_BACKGROUND,
                width = { top = 2 },
            },
        }) {
            icon := assets_get_texture(.ControllerConnected)
            if cl.UI()({
                layout = {
                    sizing = {
                        width = cl.SizingFixed(UI_SPACING_32),
                        height = cl.SizingFixed(UI_SPACING_32),
                    },
                },
                aspectRatio = { icon.width / icon.height },
                image = { rawptr(uintptr(icon.gl_id)) },
            }) { }

            cl.TextDynamic("Sony - PlayStation", cl.TextConfig({
                fontSize = UI_FONTSIZE_30,
                fontId = auto_cast g.FontID.Default,
                textColor = UI_COLOR_MAIN_TEXT,
            }))

            g.spacer(.LeftToRight)
        }
    }

    notifications_evict_and_layout()

    return cl.EndLayout()
}
