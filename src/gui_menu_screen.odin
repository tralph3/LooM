package main

import cl "clay"
import sdl "vendor:sdl3"
import "core:math/ease"
import "core:log"
import "core:strings"
import fp "core:path/filepath"
import g "gui"
import t "loom:types"
import "roms"

@(private="file")
MENU_STATE := struct #no_copy {
    roms: t.RomList,
    input_state: t.GUIInputState,
    selected_playlist_index: int,
    entry_selected: ^t.RomEntry,
    show_details: bool,
} {
    selected_playlist_index = -1
}

GRID_ITEM_WIDTH :: 240

gui_menu_get_default_focus_element :: proc () -> cl.ElementId {
    return cl.ID("Rom Entry", 0)
}


@(private="file")
game_entry_tile :: proc (plst_entry: ^t.PlaylistEntry, idx: u32) {
    // TODO: decouple from the roms package somehow
    entry := roms.get_rom_from_playlist(&MENU_STATE.roms, plst_entry)

    id := cl.ID("Rom Entry", idx)

    if g.container(.TopToBottom, { .GrowX, .GrowY }, id) {
        if !MENU_STATE.show_details {
            gui_register_focus_element(id)
        }
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
                    y = .Center,
                },
                padding = gui_is_focused(id) ? {} : cl.PaddingAll(UI_SPACING_16),
            },
        }) {
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
            }) { }
        }

        if gui_is_focused(id) {
            MENU_STATE.entry_selected = entry

            if .Ok in MENU_STATE.input_state {
                MENU_STATE.show_details = true
                gui_reset_focus()
                gui_set_default_focus_element(cl.ID("Play"))
                gui_focus_default_element()
            }
        }
    }
}

playlist_tile :: proc (playlist: ^t.Playlist, index: u32) {
    id := cl.ID("Playlist Tile", index)
    if cl.UI()({
        id = id,
        layout = {
            sizing = {
                width = cl.SizingGrow({}),
                height = cl.SizingGrow({}),
            },
            childAlignment = {
                x = .Center,
                y = .Center,
            },
        },
        backgroundColor = gui_is_focused(id) ? g.COLOR_ACCENT : {},
    }) {
        if !MENU_STATE.show_details {
            gui_register_focus_element(id)
        }
        cl.TextDynamic(playlist.name, cl.TextConfig({
            fontId = auto_cast g.FontID.Default,
            fontSize = g.FONTSIZE_16,
            textAlignment = .Center,
            textColor = g.COLOR_MAIN_TEXT,
        }))

        if gui_is_clicked(id) {
            MENU_STATE.selected_playlist_index = int(index)
        }
    }
}

gui_details_button :: proc (label: string) -> (clicked: bool) {
    id := cl.ID(label)
    if cl.UI()({
        id = id,
        layout = {
            sizing = {
                width = cl.SizingGrow({}),
                height = cl.SizingFixed(g.SPACING_32),
            },
        },
        backgroundColor = gui_is_focused(id) ? g.COLOR_ACCENT : {},
    }) {
        gui_register_focus_element(id)
        cl.TextDynamic(label, cl.TextConfig({
            fontSize = g.FONTSIZE_24,
            textColor = g.COLOR_MAIN_TEXT,
        }))

        clicked = gui_is_clicked(id)
    }

    return
}

gui_rom_entry_details :: proc () {
    if cl.UI()({
        layout = {
            sizing = {
                width = cl.SizingGrow({}),
                height = cl.SizingGrow({}),
            },
            padding = {
                left = g.SPACING_96,
                right = g.SPACING_96,
                top = g.SPACING_64,
                bottom = g.SPACING_64,
            },
        },
        floating = {
            attachment = {
                element = .LeftTop,
                parent = .LeftTop,
            },
            pointerCaptureMode = .Capture,
            attachTo = .Parent,
        },
        backgroundColor = { 0, 0, 0, 170 },
    }) {
        if cl.UI()({
            layout = {
                sizing = {
                    width = cl.SizingGrow({}),
                    height = cl.SizingGrow({}),
                },
                padding = cl.PaddingAll(g.SPACING_32),
            },
            backgroundColor = g.COLOR_SECONDARY_BACKGROUND,
            cornerRadius = cl.CornerRadiusAll(g.SPACING_16),
        }) {
            if cl.UI()({
                layout = {
                    sizing = {
                        width = cl.SizingGrow({}),
                        height = cl.SizingGrow({}),
                    },
                    padding = {
                        right = g.SPACING_32,
                    },
                    layoutDirection = .TopToBottom,
                    childAlignment = {
                        x = .Center,
                        y = .Center,
                    }
                },
            }) {
                entry := MENU_STATE.entry_selected
                file_name := fp.base(string(entry.name))
                system_name := string(entry.category)
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
                }) { }

                cl.TextDynamic(entry.display_name, cl.TextConfig({
                    textColor = g.COLOR_MAIN_TEXT,
                    fontSize = g.FONTSIZE_30,
                    textAlignment = .Center,
                }))
            }

            if cl.UI()({
                layout = {
                    sizing = {
                        width = cl.SizingFixed(2),
                        height = cl.SizingGrow({}),
                    },
                },
                backgroundColor = g.COLOR_MAIN_TEXT,
            }) { }

            if cl.UI()({
                layout = {
                    sizing = {
                        width = cl.SizingPercent(0.6),
                        height = cl.SizingGrow({}),
                    },
                    padding = {
                        left = g.SPACING_32,
                        right = g.SPACING_32,
                    },
                    layoutDirection = .TopToBottom,
                },
            }) {
                if gui_details_button("Play") {
                    event_push(.StartRom, MENU_STATE.entry_selected)
                }

                if gui_details_button("Save States") {

                }

                if gui_details_button("Read Manual") {

                }
            }
        }
    }
}

gui_layout_menu_screen :: proc (input_state: t.GUIInputState, playlists: []t.Playlist, roms: t.RomList) -> cl.ClayArray(cl.RenderCommand) {
    MENU_STATE.roms = roms
    MENU_STATE.input_state = input_state

    if .Next in input_state {
        MENU_STATE.selected_playlist_index = min(len(playlists) - 1, MENU_STATE.selected_playlist_index + 1)
        MENU_STATE.entry_selected = nil
    } else if .Previous in input_state {
        MENU_STATE.selected_playlist_index = max(0, MENU_STATE.selected_playlist_index - 1)
        MENU_STATE.entry_selected = nil
    } else if .Back in input_state {
        if MENU_STATE.show_details {
            MENU_STATE.show_details = false
        } else {
            MENU_STATE.selected_playlist_index = -1
            MENU_STATE.entry_selected = nil
        }
    }

    cl.BeginLayout()

    if g.container(.TopToBottom, g.Grow) {
        widgets_header_bar(floating=false)

        grid_id := cl.ID("Game Grid")
        cont_cfg := cl.ElementDeclaration{
            layout = {
                sizing = {
                    width = cl.SizingGrow({}),
                    height = cl.SizingGrow({}),
                },
            },
        }

        if MENU_STATE.selected_playlist_index == -1 {
            if cl.UI()(cont_cfg) {
                g.grid(
                    playlists,
                    { GRID_ITEM_WIDTH, GRID_ITEM_WIDTH },
                    playlist_tile,
                    grid_id)

                if MENU_STATE.show_details {
                    gui_rom_entry_details()
                }
            }
        } else {
            if cl.UI()(cont_cfg) {
                g.grid(
                    playlists[MENU_STATE.selected_playlist_index].entries[:],
                    { GRID_ITEM_WIDTH, GRID_ITEM_WIDTH / 0.75 },
                    game_entry_tile,
                    grid_id)

                if MENU_STATE.show_details {
                    gui_rom_entry_details()
                }
            }
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
            if MENU_STATE.selected_playlist_index > -1 {
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

                cl.TextDynamic(playlists[MENU_STATE.selected_playlist_index].name, cl.TextConfig({
                    fontSize = UI_FONTSIZE_30,
                    fontId = auto_cast g.FontID.Default,
                    textColor = UI_COLOR_MAIN_TEXT,
                }))

                g.spacer(.LeftToRight)

                if MENU_STATE.entry_selected != nil {
                    cl.TextDynamic(MENU_STATE.entry_selected.display_name, cl.TextConfig({
                        fontSize = UI_FONTSIZE_18,
                        fontId = auto_cast g.FontID.Default,
                        textColor = UI_COLOR_MAIN_TEXT,
                        textAlignment = .Right,
                    }))
                }
            }
        }
    }

    notifications_evict_and_layout()

    return cl.EndLayout()
}
