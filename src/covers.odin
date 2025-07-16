package main

import "core:strings"
import "core:slice"
import "core:sync/chan"
import "core:thread"
import "core:log"
import sdl "vendor:sdl3"
import "core:mem"

CoverResult :: struct {
    texture: Texture,
    name: string,
    success: bool,
}

COVER_CURRENTLY_LOADING: [dynamic]string
COVER_RESULT_CHAN: chan.Chan(CoverResult, .Both)
COVER_MEMORY_CACHE := CacheMemory(Texture){
    eviction_time_ms = 1000,
    item_free_proc = proc (tex: Texture) {
        tex := tex
        texture_unload(&tex)
    }
}

covers_init :: proc () -> (ok: bool) {
    err: mem.Allocator_Error
    COVER_RESULT_CHAN, err = chan.create(type_of(COVER_RESULT_CHAN), 30, context.allocator)
    if err != nil {
        return false
    }

    return true
}

covers_deinit :: proc () {
    cache_delete(&COVER_MEMORY_CACHE)

    chan.close(&COVER_RESULT_CHAN)
    chan.destroy(&COVER_RESULT_CHAN)

    delete(COVER_CURRENTLY_LOADING)
}

cover_get :: proc (name: string) -> (tex: Texture) {
    for res in chan.try_recv(COVER_RESULT_CHAN) {
        defer delete(res.name)

        idx, found := slice.linear_search(COVER_CURRENTLY_LOADING[:], res.name)
        log.assertf(found, "{} was not in the currently loading array", res.name)
        unordered_remove(&COVER_CURRENTLY_LOADING, idx)

        tex: Texture
        if res.success {
            tex = res.texture
        } else {
            tex = assets_get_texture(.NoCover)
        }

        cache_set(&COVER_MEMORY_CACHE, res.name, tex)
    }

    if cache_has(&COVER_MEMORY_CACHE, name) {
        return cache_get(&COVER_MEMORY_CACHE, name)^
    }

    if !slice.contains(COVER_CURRENTLY_LOADING[:], name) {
        cloned_name := strings.clone(name)
        thread_pool_add_task(cover_process_load_request, raw_data(cloned_name), len(cloned_name))
        append(&COVER_CURRENTLY_LOADING, cloned_name)
    }

    cache_set(&COVER_MEMORY_CACHE, name, assets_get_texture(.TextureLoading))

    return cache_get(&COVER_MEMORY_CACHE, name)^
}

cover_process_load_request :: proc (task: thread.Task) {
    context = state_get_context()

    name := strings.string_from_ptr((^u8)(task.data), task.user_index)
    cover_result := CoverResult{ name = name }

    tex, ok := texture_load_stock(name)
    if !ok {
        log.errorf("Failed loading texture '{}': {}", name, sdl.GetError())
        cover_result.success = false
    } else {
        cover_result.success = true
        cover_result.texture = tex
    }

    chan.send(COVER_RESULT_CHAN, cover_result)
}
