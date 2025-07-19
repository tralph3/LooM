package main

import sdl "vendor:sdl3"
import "core:log"
import "core:strings"

SceneOnEnter :: proc ()
SceneOnExit :: proc ()
SceneUpdate :: proc ()
SceneRender :: proc ()

Scene :: struct {
    on_enter: SceneOnEnter,
    on_exit: SceneOnExit,
    update: SceneUpdate,
    render: SceneRender,

    allowed_transitons: bit_set[SceneID],
}

SceneID :: enum {
    LOGIN,
    MENU,
    PAUSE,
    RUNNING,
}

SCENES := [SceneID]Scene{
        .LOGIN = {
            on_enter = proc () {
                gui_reset_focus()
                id := gui_login_get_default_focus_element()
                gui_set_default_focus_element(id)
            },
            on_exit = proc () {
                username := user_get_current()
                notifications_add(
                    strings.concatenate({ "Succesfully logged in as ", username }, context.temp_allocator),
                    3000)
            },
            update = proc () {},
            render = proc () {
                layout := gui_layout_login_screen()
                gui_renderer_render_commands(&layout)
            },
            allowed_transitons = { .MENU },
        },
        .MENU = {
            on_enter = proc () {
                gui_reset_focus()
                id := gui_menu_get_default_focus_element()
                gui_set_default_focus_element(id)
            },
            update = proc () {
                cache_evict(&COVER_MEMORY_CACHE)
            },
            render = proc () {
                layout := gui_layout_menu_screen()
                gui_renderer_render_commands(&layout)
            },
            allowed_transitons = { .RUNNING, .LOGIN },
        },
        .PAUSE = {
            on_enter = proc () {
                gui_reset_focus()
                id := gui_pause_get_default_focus_element()
                gui_set_default_focus_element(id)
            },
            update = proc () {
            },
            render = proc () {
                layout := gui_layout_pause_screen()
                gui_renderer_render_commands(&layout)
            },
            allowed_transitons = { .RUNNING, .MENU },
        },
        .RUNNING = {
            on_enter = proc () {
                gui_reset_focus()
                audio_resume()
                _ = sdl.HideCursor()
            },
            on_exit = proc () {
                audio_pause()
                _ = sdl.ShowCursor()
            },
            update = proc () {
                emulator_run_one_frame()
            },
            render = proc () {
                layout := gui_layout_running_screen()
                gui_renderer_render_commands(&layout)
            },
            allowed_transitons = { .PAUSE },
        },
}

scene_change :: proc (new_scene_id: SceneID, location:=#caller_location) {
    current_scene := scene_get(GLOBAL_STATE.current_scene_id)

    if new_scene_id not_in current_scene.allowed_transitons {
        log.warnf("Attempted an invalid scene change. From '{}' to '{}' -> {}",
                  GLOBAL_STATE.current_scene_id, new_scene_id, location)
        return
    }

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

scene_init :: proc () -> (ok: bool) {
    initial_scene := scene_get(GLOBAL_STATE.current_scene_id)

    if initial_scene.on_enter != nil {
        initial_scene.on_enter()
    }

    return true
}
