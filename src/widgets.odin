package main

import cl "clay"

SpacerDirection :: enum {
    Vertical,
    Horizontal,
    Both,
}

widgets_spacer :: proc (direction: SpacerDirection) {
    is_vertical := direction == .Vertical || direction == .Both
    is_horizontal := direction == .Horizontal || direction == .Both

    if cl.UI()({
        id = cl.ID("Spacer"),
        layout = {
            sizing = {
                width = is_horizontal ? cl.SizingGrow({}) : {},
                height = is_vertical ? cl.SizingGrow({}) : {},
            },
        },
    }) {}
}

widgets_controller_status :: proc () {
    for i in 0..<INPUT_MAX_PLAYERS {
        texture := input_is_controller_connected(u32(i)) \
            ? texture_get_or_load("controller_connected") \
            : texture_get_or_load("controller_disconnected")

        if cl.UI()({
            layout = {
                sizing = {
                    width = cl.SizingFixed(42),
                    height = cl.SizingFixed(42),
                },
            },
            aspectRatio = { texture.width / texture.height },
            image = { rawptr(uintptr(texture.gl_id)) },
            border = input_is_controller_active_this_frame(u32(i)) ? {
                color = UI_COLOR_ACCENT,
                width = cl.BorderAll(3),
            } : {}
        }) {}
    }
}

widgets_loom_title :: proc () {
    text_config := new(cl.TextElementConfig, allocator=context.temp_allocator)
    text_config.fontSize = UI_FONTSIZE_48
    text_config.textColor = UI_COLOR_MAIN_TEXT
    text_config.fontId = auto_cast FontID.Title
    cl.Text("LooM", text_config)
}


widgets_header_bar :: proc (floating := true) {
    if cl.UI()({
        id = cl.ID("Header Bar"),
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
        floating = floating ? {
	        attachment = {
                element = .LeftTop,
                parent = .LeftTop,
            },
            attachTo = .Root,
        } : {},
        backgroundColor = UI_COLOR_BACKGROUND,
        border = {
            color = UI_COLOR_SECONDARY_BACKGROUND,
            width = { bottom = 2 },
        },
    }) {
        widgets_loom_title()
        widgets_spacer(.Horizontal)
        widgets_controller_status()
    }
}
