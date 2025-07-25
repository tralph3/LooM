package main

import cl "clay"
import sdl "vendor:sdl3"
import "core:math/ease"
import "core:log"
import fp "core:path/filepath"

GRID_ITEM_WIDTH :: 180

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
        backgroundColor = gui_is_focused(id) \
            ? UI_COLOR_ACCENT \
            : {},
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
                }) {}
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
                    width = cl.SizingGrow({ max = f32(video_get_window_dimensions().x) }),
                    height = cl.SizingGrow({}),
                },
                childAlignment = {
                    x = .Center,
                    y = .Center,
                },
                childGap = UI_SPACING_16,
                padding = {
                    left = 128,
                    right = 128,
                },
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

            n := int(clamp((available_w + gap) / (item_w + gap), 1, 32))
            entries := GLOBAL_STATE.rom_entries
            total := len(entries)
            if n > total {
                n = total
            }
            rows := (total + n - 1) / n

            for i in 0..<rows {
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
        }
    }

    notifications_evict_and_layout()

    return cl.EndLayout()
}
