package main

import "core:testing"
import "core:mem"
import "core:os/os2"
import fp "core:path/filepath"
import "core:time"

free_proc_string_int :: proc(key: string, val: int) { }

free_proc_string_ptr :: proc(key: string, val: ^int) {
    if val != nil {
        free(val)
    }
}

@(test)
cache_memory_set_and_get_test :: proc(t: ^testing.T) {
    cache := CacheMemory(string, int){
        eviction_time_ms = 10000,
        item_free_proc = free_proc_string_int,
    }
    defer cache_memory_delete(&cache)

    cache_memory_set(&cache, "foo", 42)
    cache_memory_set(&cache, "bar", 69)

    val := cache_memory_get(&cache, "foo")
    testing.expect(t, val != nil)
    testing.expect_value(t, val^, 42)

    val2 := cache_memory_get(&cache, "bar")
    testing.expect(t, val2 != nil)
    testing.expect_value(t, val2^, 69)

    val3 := cache_memory_get(&cache, "baz")
    testing.expect_value(t, val3, nil)
}

@(test)
cache_memory_has_test :: proc(t: ^testing.T) {
    cache := CacheMemory(string, int){
        eviction_time_ms = 10000,
        item_free_proc = free_proc_string_int,
    }
    defer cache_memory_delete(&cache)

    cache_memory_set(&cache, "foo", 1)
    cache_memory_set(&cache, "bar", 2)
    testing.expect_value(t, cache_memory_has(&cache, "foo"), true)
    testing.expect_value(t, cache_memory_has(&cache, "bar"), true)
    testing.expect_value(t, cache_memory_has(&cache, "baz"), false)
}

@(test)
cache_memory_evict_test :: proc(t: ^testing.T) {
    cache := CacheMemory(string, int){
        eviction_time_ms = 0, // evict immediately
        item_free_proc = free_proc_string_int,
    }
    defer cache_memory_delete(&cache)

    cache_memory_set(&cache, "foo", 1)
    cache_memory_set(&cache, "bar", 2)
    testing.expect_value(t, cache_memory_has(&cache, "foo"), true)
    testing.expect_value(t, cache_memory_has(&cache, "bar"), true)

    cache_memory_evict(&cache)
    testing.expect_value(t, cache_memory_has(&cache, "foo"), false)
    testing.expect_value(t, cache_memory_has(&cache, "bar"), false)
}

@(test)
cache_storage_set_and_get_test :: proc(t: ^testing.T) {
    temp_dir, err1 := os2.temp_dir(context.allocator)
    defer delete(temp_dir)
    testing.expect_value(t, err1, nil)

    base_path := fp.join({ temp_dir, "cache_test" })
    defer delete(base_path)
    defer os2.remove_all(base_path)

    cache := CacheStorage{
        base_path = base_path,
    }

    key := "testfile"
    data := []byte{ 'T', 'e', 's', 't' }

    err2 := cache_storage_set(&cache, key, data)
    testing.expect_value(t, err2, nil)

    res, err3 := cache_storage_get(&cache, key)
    defer delete(res)
    testing.expect_value(t, err3, nil)
    testing.expect_value(t, len(res), 4)
    testing.expect_value(t, res[0], 'T')
    testing.expect_value(t, res[1], 'e')
    testing.expect_value(t, res[2], 's')
    testing.expect_value(t, res[3], 't')
}

@(test)
cache_storage_has_and_delete_test :: proc(t: ^testing.T) {
    temp_dir, err1 := os2.temp_dir(context.allocator)
    defer delete(temp_dir)

    testing.expect_value(t, err1, nil)

    base_path := fp.join({ temp_dir, "cache_test2" })
    defer delete(base_path)
    defer os2.remove_all(base_path)

    cache := CacheStorage{
        base_path = base_path,
    }

    key := "testfile2"
    data := []byte{ 'T', 'e', 's', 't' }

    err2 := cache_storage_set(&cache, key, data)
    testing.expect_value(t, err2, nil)

    testing.expect_value(t, cache_storage_has(&cache, key), true)
    err3 := cache_storage_delete(&cache, key)
    testing.expect_value(t, err2, nil)
    testing.expect_value(t, cache_storage_has(&cache, key), false)
}

@(test)
cache_memory_set_pointer_type_test :: proc(t: ^testing.T) {
    cache := CacheMemory(string, ^int){
        eviction_time_ms = 10000,
        item_free_proc = free_proc_string_ptr,
    }
    defer cache_memory_delete(&cache)

    val := new(int)
    val^ = 123
    cache_memory_set(&cache, "ptr", val)
    got := cache_memory_get(&cache, "ptr")
    testing.expect(t, got != nil)
    testing.expect_value(t, got^^, 123)
}

@(test)
cache_storage_get_nonexistent_file :: proc(t: ^testing.T) {
    temp_dir, err1 := os2.temp_dir(context.allocator)
    defer delete(temp_dir)

    testing.expect_value(t, err1, nil)

    base_path := fp.join({ temp_dir, "cache_test3" })
    defer delete(base_path)
    defer os2.remove_all(base_path)

    cache := CacheStorage{
        base_path = base_path,
    }

    res, err := cache_storage_get(&cache, "does_not_exist")
    testing.expect(t, err != nil)
    testing.expect_value(t, len(res), 0)
}
