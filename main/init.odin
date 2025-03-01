package main

import rl "vendor:raylib"
import cl "clay"
import "core:log"
import "base:runtime"

error_handler :: proc "c" (error: cl.ErrorData) {
    context = runtime.default_context()

    log.error(error.errorText)
}

init_raylib :: proc () -> bool {
    rl.SetConfigFlags({.WINDOW_RESIZABLE})

    log.debug("Initializing Raylib window")

    rl.InitWindow(800, 600, "Odin Libretro")

    log.debug("Initializing audio device")

    rl.InitAudioDevice()

    rl.SetExitKey(rl.KeyboardKey.KEY_NULL)

    return true
}

init_clay :: proc () -> bool {
    log.debug("Requesting min memory size for Clay")

    memory_size := cl.MinMemorySize()

    log.debugf("Clay requested %d bytes", memory_size)

    memory := make([^]byte, memory_size)

    log.debug("Initializing Clay arena")

    arena := cl.CreateArenaWithCapacityAndMemory(memory_size, memory)

    log.debug("Initializing Clay")

    cl.Initialize(arena, { width = 800, height = 600 }, { handler = error_handler })

    cl.SetMeasureTextFunction(cl.measureText, nil)

    load_font(0, rl.GetFontDefault())

    return true
}

load_font_path :: proc(fontId: u16, fontSize: u16, path: cstring) {
    cl.raylibFonts[fontId] = {
        font   = rl.LoadFontEx(path, cast(i32)fontSize * 2, nil, 0),
        fontId = u16(fontId),
    }
    rl.SetTextureFilter(cl.raylibFonts[fontId].font.texture, rl.TextureFilter.TRILINEAR)
}

load_font_struct :: proc(fontId: u16, font: rl.Font) {
    cl.raylibFonts[fontId] = {
        font   = font,
        fontId = u16(fontId),
    }
    rl.SetTextureFilter(cl.raylibFonts[fontId].font.texture, rl.TextureFilter.TRILINEAR)
}

load_font :: proc {
    load_font_path,
    load_font_struct,
}
