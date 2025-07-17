package main

import "core:log"
import sdl "vendor:sdl3"
import "core:strings"
import "core:os/os2"
import fp "core:path/filepath"

CacheMemoryItem :: struct($T: typeid) {
    last_access: u64,
    item: T,
}

CacheMemory :: struct($T: typeid) {
    cache: map[string]CacheMemoryItem(T),
    eviction_time_ms: u64,
    item_free_proc: proc (T),
}

CacheStorage :: struct {
    base_path: string,
}

cache_get :: proc {
    cache_memory_get,
    cache_storage_get,
}

cache_set :: proc {
    cache_memory_set,
    cache_storage_set,
}

cache_delete :: proc {
    cache_memory_delete,
    cache_storage_delete,
}

cache_has :: proc {
    cache_memory_has,
    cache_storage_has,
}

cache_evict :: proc {
    cache_memory_evict,
}

cache_memory_get :: proc (cache: ^CacheMemory($T), key: string) -> ^T {
    if entry, found := &cache.cache[key]; found {
        entry.last_access = sdl.GetTicks()
        return &entry.item
    }

    return nil
}

cache_storage_get :: proc (cache: ^CacheStorage, key: string, allocator:=context.allocator) -> (res: []byte, err: os2.Error) {
    full_path := fp.join({ cache.base_path, key }, context.temp_allocator)
    return os2.read_entire_file(full_path, allocator)
}

cache_memory_set :: proc (cache: ^CacheMemory($T), key: string, item: T) {
    key_safe: string
    if !cache_has(cache, key) {
        key_safe = strings.clone(key)
    } else {
        key_safe = key
    }

    cache.cache[key_safe] = {
        last_access = sdl.GetTicks(),
        item = item,
    }
}

cache_storage_set :: proc (cache: ^CacheStorage, key: string, val: []byte) -> (err: os2.Error) {
    full_path := fp.join({ cache.base_path, key }, context.temp_allocator)
    base_dir := fp.dir(full_path, context.temp_allocator)
    mk_err := os2.make_directory_all(base_dir)
    if mk_err != .Exist && mk_err != nil {
        return mk_err
    }

    return os2.write_entire_file(full_path, val)
}

cache_memory_delete :: proc (cache: ^CacheMemory($T)) {
    for key, item in cache.cache {
        cache.item_free_proc(item.item)
        delete(key)
    }
    delete(cache.cache)
}

cache_storage_delete :: proc (cache: ^CacheStorage, key: string) -> (err: os2.Error) {
    full_path := fp.join({ cache.base_path, key }, context.temp_allocator)
    return os2.remove(full_path)
}

cache_memory_has :: proc (cache: ^CacheMemory($T), key: string) -> bool {
    return key in cache.cache
}

cache_storage_has :: proc (cache: ^CacheStorage, key: string) -> bool {
    full_path := fp.join({ cache.base_path, key }, context.temp_allocator)
    return os2.exists(full_path)
}

cache_memory_evict :: proc (cache: ^CacheMemory($T)) {
    keys_to_remove: [dynamic]string
    defer delete(keys_to_remove)

    current_time_ms := sdl.GetTicks()
    for key, item in cache.cache {
        elapsed_time_ms := current_time_ms - item.last_access
        if elapsed_time_ms > cache.eviction_time_ms {
            append(&keys_to_remove, key)
        }
    }

    for key in keys_to_remove {
        cache.item_free_proc(cache.cache[key].item)
        delete_key(cache.cache, key)
        delete(key)
    }
}
