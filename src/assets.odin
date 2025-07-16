#+private file
package main

import sdl "vendor:sdl3"
import "core:log"
import "core:slice"

@(private="package")
assets_init :: proc () -> (ok: bool) {
    load_all_sounds() or_return
    load_all_textures() or_return

    return true
}

@(private="package")
assets_deinit :: proc () {
    unload_all_sounds()
}

@(private="package")
assets_get_sound :: proc (id: SoundID) -> Sound {
    return ASSETS.sounds[id]
}

@(private="package")
assets_get_texture :: proc (id: TextureID) -> Texture {
    return ASSETS.textures[id]
}

ASSETS := struct {
    sounds: [SoundID]Sound,
    textures: [TextureID]Texture,
} {}

load_all_sounds :: proc () -> (ok: bool) {
    ok = true
    for path, id in SoundPaths {
        sound, ok_load := sound_load(path)
        if !ok_load {
            log.errorf("Failed loading sound '{}': {}", path, sdl.GetError())
            ok = false
            continue
        }

        ASSETS.sounds[id] = sound
    }

    return
}

load_all_textures :: proc () -> (ok: bool) {
    ok = true
    for path, id in TexturePaths {
        tex, ok_load := texture_load_stock(path)
        if !ok_load {
            log.errorf("Failed loading texture '{}': {}", path, sdl.GetError())
            ok = false
            continue
        }

        ASSETS.textures[id] = tex
    }

    return
}

unload_all_textures :: proc () {
    for &tex in ASSETS.textures {
        texture_unload(&tex)
    }
}

unload_all_sounds :: proc () {
    for sound in ASSETS.sounds {
        sound_unload(sound)
    }
}
