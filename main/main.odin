package main

import "clay"
import rl "vendor:raylib"
import "core:fmt"

error_handler :: proc "c" (error: clay.ErrorData) {

}

create_layout :: proc (size: f32) -> clay.ClayArray(clay.RenderCommand) {
    clay.BeginLayout()

    if clay.UI()({
        id = clay.ID("Side Container"),
        layout = {
            sizing = { width = clay.SizingFixed(230), height = clay.SizingGrow({}) },
            padding = { 10, 10, 10, 10, },
            childAlignment = {
                x = .Center,
                y = .Center,
            },
        },
        backgroundColor = { 0x18, 0x18, 0x18, 255 },
    }) {

    }

    return clay.EndLayout()
}

main :: proc () {
    memory_size := clay.MinMemorySize()
    memory := make([^]byte, memory_size)
    arena := clay.CreateArenaWithCapacityAndMemory(memory_size, memory)
    clay.Initialize(arena, { width = 800, height = 600 }, { handler = error_handler })
    clay.SetMeasureTextFunction(clay.measureText, nil)
    // clay.SetDebugModeEnabled(true)

    // emulator_init("cores/bsnes_libretro.so", "roms/Super Castlevania IV (USA).sfc")
    // emulator_init("cores/fceumm_libretro.so", "roms/Legend of Zelda, The (U) (PRG1) [!].nes")
    emulator_init("cores/fceumm_libretro.so", "roms/Legend of Zelda, The (U) (PRG1) [!].nes")
    emulator_main_loop()
    emulator_quit()


    // raylib.SetConfigFlags({.WINDOW_RESIZABLE})
    // raylib.InitWindow(800, 600, "clay!!")

    // for !raylib.WindowShouldClose() {


    //     render_commands: clay.ClayArray(clay.RenderCommand)

    //     raylib.BeginDrawing()
    //     render_commands = create_layout(button_size)
    //     clay.clayRaylibRender(&render_commands)
    //     raylib.EndDrawing()
    // }
}
