package main

import lr "libretro"
import sdl "vendor:sdl3"
import cb "circular_buffer"
import "core:log"
import "core:strings"
import "core:os/os2"

// You only need to free the returned array, the strings themselves
// are views into the core's memory
core_get_valid_extensions :: proc (core: ^lr.LibretroCore, allocator:=context.allocator) -> []string {
    if core == nil { return {} }
    return strings.split(string(core.system_info.valid_extensions), "|", allocator=allocator)
}
