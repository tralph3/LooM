package main

import sdl "vendor:sdl3"
import "core:log"
import "core:slice"
import "core:strings"
import fp "core:path/filepath"

BASE_SOUND_PATH :: "./assets/sounds/"

Sound :: []byte

SoundID :: enum {
    SelectPositive,
    SelectNegative,
}

SoundPaths :: [SoundID]string {
        .SelectPositive = "select_positive.wav",
        .SelectNegative = "select_negative.wav",
}

sound_load :: proc (internal_path: string) -> (sound: Sound, ok: bool) {
    spec: sdl.AudioSpec
    buf: [^]byte
    length: u32

    full_path := fp.join({ BASE_SOUND_PATH, internal_path})
    defer delete(full_path)

    full_path_cstr := strings.clone_to_cstring(full_path)
    defer delete(full_path_cstr)

    if !sdl.LoadWAV(full_path_cstr, &spec, &buf, &length) {
        return nil, false
    }

    sound = slice.from_ptr(buf, int(length))
    ok = true
    return
}

sound_unload :: proc (sound: Sound) {
    sdl.free(raw_data(sound))
}
