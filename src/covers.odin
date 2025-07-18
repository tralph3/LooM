package main

import "core:strings"
import "core:slice"
import "core:sync/chan"
import "core:log"
import sdl "vendor:sdl3"
import "core:mem"
import fp "core:path/filepath"

CoverResult :: struct {
    texture: Texture,
    name: string,
    success: bool,
}

CoverRequest :: struct {
    name: string,
    system: string,
}

COVER_CURRENTLY_LOADING: [dynamic]string
COVER_RESULT_CHAN: chan.Chan(CoverResult, .Both)
COVER_STORAGE_CACHE := CacheStorage{
    base_path = "./cache",
}
COVER_MEMORY_CACHE := CacheMemory(Texture){
    eviction_time_ms = 3000,
    item_free_proc = proc (tex: Texture) {
        tex := tex
        if tex == assets_get_texture(.NoCover) || tex == assets_get_texture(.TextureLoading) {
            return
        }
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

cover_get :: proc (system: string, name: string) -> (tex: Texture) {
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
        // TODO: the key should be system + name
        cloned_name := strings.clone(name)
        request := new(CoverRequest)
        request.name = cloned_name
        request.system = strings.clone(system)
        thread_pool_add_task(cover_process_load_request, request, 0)
        append(&COVER_CURRENTLY_LOADING, cloned_name)
    }

    cache_set(&COVER_MEMORY_CACHE, name, assets_get_texture(.TextureLoading))

    return cache_get(&COVER_MEMORY_CACHE, name)^
}


cover_process_load_request :: proc (task: Task) {
    request := cast(^CoverRequest)task.data
    defer delete(request.system, state_get_context().allocator)
    defer free(request, state_get_context().allocator)

    cover_result := CoverResult{ name = request.name }

    cache_key := fp.join({ request.system, request.name })
    defer delete(cache_key)

    tex: Texture
    ok: bool
    if cache_has(&COVER_STORAGE_CACHE, cache_key) {
        bytes, err := cache_get(&COVER_STORAGE_CACHE, cache_key, context.allocator)
        if err != nil {
            cache_delete(&COVER_STORAGE_CACHE, cache_key)
            ok = false
        } else {
            tex, ok = texture_load_from_bytes(bytes)
            delete(bytes)
        }
    }

    if !ok {
        bytes, ok_download := thumbnail_download(request.system, request.name)
        if !ok_download {
            ok = false
        } else {
            cache_set(&COVER_STORAGE_CACHE, cache_key, bytes)
            tex, ok = texture_load_from_bytes(bytes)
            delete(bytes)
        }
    }

    if !ok {
        log.errorf("Failed loading texture '{}': {}", cache_key, sdl.GetError())
        cover_result.success = false
    } else {
        cover_result.success = true
        cover_result.texture = tex
    }

    chan.send(COVER_RESULT_CHAN, cover_result)
}
