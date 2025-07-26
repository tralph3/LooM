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
            ? assets_get_texture(.ControllerConnected) \
            : assets_get_texture(.ControllerDisconnected)

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
                width = { bottom = 3 },
            } : {}
        }) {}
    }
}

widgets_loom_title :: proc () {
    cl.Text("LooM", cl.TextConfig({
        fontSize = UI_FONTSIZE_48,
        textColor = UI_COLOR_MAIN_TEXT,
        fontId = auto_cast FontID.Title,
    }))
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

@(deferred_none = cl._CloseElement)
widgets_container :: proc (
    id:=cl.ElementId{},
    childAlignment:=cl.ChildAlignment{},
    sizing_x:=cl.SizingAxis{type = .Grow},
    sizing_y:=cl.SizingAxis{type = .Grow},
    backgroundColor:=UI_COLOR_BACKGROUND,
    direction:=cl.LayoutDirection.LeftToRight,
) -> bool {
    cl._OpenElement()

    cl.ConfigureOpenElement({
        id=id,
        layout = {
            sizing = {
                width = sizing_x,
                height = sizing_y,
            },
            childAlignment = childAlignment,
            layoutDirection = direction,
        },
        backgroundColor = backgroundColor,
    })

	return true
}
