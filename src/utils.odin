package main

import "core:mem"
import fp "core:path/filepath"

clone_cstring :: proc (cstr: cstring, allocator := context.allocator) -> cstring {
    tmp := string(cstr)

    clone := make([^]byte, len(tmp), allocator=allocator)
    mem.copy_non_overlapping(clone, rawptr(cstr), len(tmp))

    return cstring(clone)
}

dir_path_with_trailing_slash_cstr :: proc (dir_path: string) -> (res: cstring, err: mem.Allocator_Error) {
    // it needs enough memory to store the path string plus the
    // forward slash plus the null terminator
    cstr_clone := mem.alloc(len(dir_path) + 2) or_return
    mem.copy(cstr_clone, raw_data(dir_path), len(dir_path))
    ([^]byte)(cstr_clone)[len(dir_path)] = '/'
    ([^]byte)(cstr_clone)[len(dir_path) + 1] = '\x00'

    return cstring(cstr_clone), nil
}
