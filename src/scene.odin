package main

import sdl "vendor:sdl3"
import "core:log"

SceneOnEnter :: proc ()
SceneOnExit :: proc ()
SceneUpdate :: proc ()
SceneRender :: proc ()

Scene :: struct {
    on_enter: SceneOnEnter,
    on_exit: SceneOnExit,
    update: SceneUpdate,
    render: SceneRender,
}

SceneID :: enum {
    LOGIN,
    MENU,
    PAUSE,
    RUNNING,
}

SCENES := [SceneID]Scene{
    .LOGIN = {
        update = proc () {
        },
        render = proc () {
            layout := gui_layout_login_screen()
            gui_renderer_render_commands(&layout)
        },
    },
    .MENU = {
    },
    .PAUSE = {
    },
    .RUNNING = {
        update = proc () {
            sdl.GL_MakeCurrent(GLOBAL_STATE.video_state.window, emu_context)
            GLOBAL_STATE.emulator_state.core.api.run()
            sdl.GL_MakeCurrent(GLOBAL_STATE.video_state.window, gl_context)
        },
        render = proc () {
            layout := gui_layout_render_screen()
            gui_renderer_render_commands(&layout)
        }
    },
}

scene_change :: proc (new_scene_id: SceneID) {
    current_scene := scene_get(GLOBAL_STATE.current_scene_id)
    new_scene := scene_get(new_scene_id)

    if current_scene.on_exit != nil {
        current_scene.on_exit()
    }

    if new_scene.on_enter != nil {
        new_scene.on_enter()
    }

    GLOBAL_STATE.current_scene_id = new_scene_id
}

scene_get :: proc (scene_id: SceneID) -> Scene {
    return SCENES[scene_id]
}
