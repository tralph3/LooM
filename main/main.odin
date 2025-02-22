package main

main :: proc () {
    emulator_init("cores/bsnes_libretro.so", "roms/Super Castlevania IV (USA).sfc")
    emulator_main_loop()
    emulator_quit()
}
