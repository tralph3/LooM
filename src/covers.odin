package main

import "core:strings"
import "core:slice"
import "core:sync/chan"
import "core:log"
import sdl "vendor:sdl3"
import "core:mem"
import fp "core:path/filepath"
import "utils"

CoverResult :: struct {
    texture: Texture,
    id: u64,
    success: bool,
}

CoverRequest :: struct {
    id: u64,
    key: string,
}

COVER_CURRENTLY_LOADING: [dynamic]u64
COVER_RESULT_CHAN: chan.Chan(CoverResult, .Both)
COVER_STORAGE_CACHE := CacheStorage{
    base_path = "./cache",
}
COVER_MEMORY_CACHE := CacheMemory(u64, Texture){
    eviction_time_ms = 3000,
    item_free_proc = proc (key: u64, tex: Texture) {
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
    id := utils.string_hash(system) * utils.string_hash(name)

    for res in chan.try_recv(COVER_RESULT_CHAN) {
        idx, found := slice.linear_search(COVER_CURRENTLY_LOADING[:], res.id)
        log.assertf(found, "{} was not in the currently loading array", res.id)
        unordered_remove(&COVER_CURRENTLY_LOADING, idx)

        tex: Texture
        if res.success {
            tex = res.texture
        } else {
            tex = assets_get_texture(.NoCover)
        }

        cache_set(&COVER_MEMORY_CACHE, res.id, tex)
    }

    if cache_has(&COVER_MEMORY_CACHE, id) {
        return cache_get(&COVER_MEMORY_CACHE, id)^
    }

    if !slice.contains(COVER_CURRENTLY_LOADING[:], id) {
        request := new(CoverRequest)
        request.id = id
        request.key = fp.join({ system, name })
        thread_pool_add_task(cover_process_load_request, request, 0)
        append(&COVER_CURRENTLY_LOADING, id)
    }

    cache_set(&COVER_MEMORY_CACHE, id, assets_get_texture(.TextureLoading))

    return cache_get(&COVER_MEMORY_CACHE, id)^
}


cover_process_load_request :: proc (task: Task) {
    request := cast(^CoverRequest)task.data
    // TODO: this is vulnerable to race conditions
    defer delete(request.key, state_get_context().allocator)
    defer free(request, state_get_context().allocator)

    cover_result := CoverResult{
        id = request.id,
    }

    tex: Texture
    ok: bool
    if cache_has(&COVER_STORAGE_CACHE, request.key) {
        bytes, err := cache_get(&COVER_STORAGE_CACHE, request.key, context.allocator)
        if err != nil {
            cache_delete(&COVER_STORAGE_CACHE, request.key)
            ok = false
        } else {
            tex, ok = texture_load_from_bytes(bytes)
            delete(bytes)
        }
    }

    system, name := fp.split(request.key)
    system = system[:len(system) - 1]
    if !ok {
        bytes, ok_download := thumbnail_download(system, name)
        log.info(system, name)
        if !ok_download {
            ok = false
        } else {
            cache_set(&COVER_STORAGE_CACHE, request.key, bytes)
            tex, ok = texture_load_from_bytes(bytes)
            delete(bytes)
        }
    }

    if !ok {
        log.errorf("Failed loading texture '{}': {}", request.key, sdl.GetError())
        cover_result.success = false
    } else {
        cover_result.success = true
        cover_result.texture = tex
    }

    chan.send(COVER_RESULT_CHAN, cover_result)
}
