package main

import cl "clay"
import sdl "vendor:sdl3"
import "core:math/ease"
import "core:log"
import fp "core:path/filepath"

GRID_ITEM_WIDTH :: 210

gui_menu_get_default_focus_element :: proc () -> cl.ElementId {
    return cl.ID("Rom Entry", 0)
}

@(private="file")
game_entry_button :: proc (entry: ^RomEntry, idx: u32) -> (clicked: bool) {
    id := cl.ID("Rom Entry", idx)

    if cl.UI()({
        id = id,
        layout = {
            sizing = {
                width = cl.SizingFixed(GRID_ITEM_WIDTH),
                height = cl.SizingFit({}),
            },
            layoutDirection = .TopToBottom,
        },
    }) {
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
                    width = cl.SizingFixed(GRID_ITEM_WIDTH),
                    height = cl.SizingFixed(GRID_ITEM_WIDTH / 0.75),
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

        clicked = gui_is_clicked(id)
    }

    return
}

gui_layout_menu_screen :: proc () -> cl.ClayArray(cl.RenderCommand) {
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
        backgroundColor = UI_COLOR_BACKGROUND,
    }) {
        widgets_header_bar(floating=false)

        grid_id := cl.ID("Game Grid")
        if cl.UI()({
            id = grid_id,
            layout = {
                sizing = {
                    width = cl.SizingGrow({ max = f32(video_get_window_dimensions().x) - UI_SPACING_64 }),
                    height = cl.SizingGrow({}),
                },
                childAlignment = {
                    x = .Center,
                    y = .Center,
                },
                childGap = UI_SPACING_16,
                layoutDirection = .TopToBottom,
            },
            clip = {
                vertical = true,
                childOffset = cl.GetScrollOffset(),
            },
        }) {
            grid_bb := cl.GetElementData(grid_id).boundingBox
            gap: int = UI_SPACING_12
            item_w := GRID_ITEM_WIDTH
            available_w := int(grid_bb.width)

            row_height: f32 = 56 + GRID_ITEM_WIDTH / 0.75
            start_row: int = int(abs(cl.GetScrollOffset().y) / row_height)
            visible_rows: int = int(grid_bb.height / row_height) + 2
            end_row := start_row + visible_rows

            n := int(clamp((available_w + gap) / (item_w + gap), 1, 32))
            entries := GLOBAL_STATE.rom_entries
            total := len(entries)
            if n > total {
                n = total
            }
            rows := (total + n - 1) / n

            if grid_bb.height == 0 {
                start_row = 0
                end_row = rows
            }

            if cl.UI()({
                layout = {
                    sizing = {
                        width = cl.SizingFixed(f32(n * item_w + gap * (n - 1))),
                        height = cl.SizingFixed(row_height * f32(start_row)),
                    }
                },
            }) {}

            end_row_capped := min(rows, end_row)
            // we want to layout one more row so that directional
            // movement upwards works
            start_row_capped := max(0, start_row - 1)
            for i in start_row_capped..<end_row_capped {
                if cl.UI()({
                    layout = {
                        childGap = 12,
                        sizing = {
                            width = cl.SizingFixed(f32(n * item_w + gap * (n - 1))),
                        },
                    },
                }) {
                    for j in 0..<n {
                        index := i * n + j
                        if index >= total {
                            break
                        }

                        entry := &entries[index]
                        if game_entry_button(entry, u32(index)) {
                            if emulator_init(entry) {
                                scene_change(.RUNNING)
                            }
                        }
                    }
                }
            }

            if cl.UI()({
                layout = {
                    sizing = {
                        width = cl.SizingFixed(f32(n * item_w + gap * (n - 1))),
                        height = cl.SizingFixed(row_height * f32(rows - end_row_capped)),
                    }
                },
            }) {}
        }



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
                fontId = auto_cast FontID.Default,
                textColor = UI_COLOR_MAIN_TEXT,
            }))

            widgets_spacer(.Horizontal)


        }

    }

    notifications_evict_and_layout()

    return cl.EndLayout()
}
