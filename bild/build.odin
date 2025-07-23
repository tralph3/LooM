package bild

main :: proc () {
    if !sync_submodules() {
        return
    }

    clay := CTarget{
        mode = .Archive,
        files = { "lib/clay/clay.h" },
        dest = "src/clay/clay.a",
        defines = { "CLAY_IMPLEMENTATION" },
    }

    vararg := CTarget{
        mode = .Object,
        files = { "vararg.c" },
        dest = "vararg.o",
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

    compile_target(loom)
}
