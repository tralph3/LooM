package utils

import "core:mem"
import fp "core:path/filepath"
import "core:log"

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

print_leaked_allocations :: proc (track: ^mem.Tracking_Allocator) {
    if len(track.allocation_map) > 0 {
		log.errorf("=== %v allocations not freed ===\n", len(track.allocation_map))
        total: int
		for _, entry in track.allocation_map {
            total += entry.size
			log.errorf("%v bytes @ %v", entry.size, entry.location)
		}

        log.errorf("Total memory leaked: {} bytes", total)
	}
}

string_hash :: proc (str: string) -> (hash: u64) {
    hash = 14695981039346656037  // offset basis
    for b in transmute([]u8)str {
        hash = (hash ~ u64(b)) * 1099511628211  // prime
    }
    return hash
}
