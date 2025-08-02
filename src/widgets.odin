// Widgets that need to access global state
package main

import cl "clay"
import g "gui"

widgets_loom_title :: proc () {
    g.label("LooM", .Title)
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

widgets_header_bar :: proc (floating := true) {
    if g.container(.LeftToRight, { .GrowX }) {
        widgets_loom_title()
        g.spacer(.LeftToRight)
        widgets_controller_status()
    }
}
