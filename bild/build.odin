package bild

import "core:fmt"
import "core:os"

main :: proc () {
    if !sync_submodules() {
        return
    }

    clay := CTarget{
        mode = .Archive,
        files = { "lib/clay/clay.h" },
        dest = "src/clay/clay",
        defines = { "CLAY_IMPLEMENTATION" },
    }

    vararg := CTarget{
        mode = .Object,
        files = { "vararg.c" },
        dest = "vararg",
        workdir = "src",
    }

    loom := OdinTarget{
        pkg_path = "src",
        dest = "build/debug",
        flags = { .Debug },
        depends = { clay, vararg },
        collections = {
            { "ext", "ext" },
        },
    }

    if compile_target(loom) {
        fmt.println("[FINISH] Compilation succesful")
    } else {
        fmt.eprintln("[FINISH] Compilation failed")
        os.exit(1)
    }
}
