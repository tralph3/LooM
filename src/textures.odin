package main

import gl "vendor:OpenGL"
import "core:image/png"
import fp "core:path/filepath"
import "core:log"
import "core:strings"

Texture :: struct {
    gl_id: u32,
    ratio: f32,
}

LOADED_TEXTURES: map[string]Texture
DEFAULT_COVER_TEXTURE: Texture

textures_init :: proc () -> (ok: bool) {
    err: png.Error
    DEFAULT_COVER_TEXTURE, err = texture_load_from_image_path("./assets/img/nocover.png")
    if err != nil { return false }

    return true
}

texture_load_from_image_path :: proc (path: string) -> (texture: Texture, err: png.Error) {
    img := png.load(path) or_return
    defer png.destroy(img)

    format: u32

    switch img.channels {
    case 4:
        format = gl.RGBA
    case 3:
        format = gl.RGB
    case 2:
        format = gl.RG
    case 1:
        format = gl.RED
    }

    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)
    gl.GenTextures(1, &texture.gl_id)
    gl.BindTexture(gl.TEXTURE_2D, texture.gl_id)
    gl.TexImage2D(
        gl.TEXTURE_2D, 0, gl.RGBA8,
        i32(img.width), i32(img.height),
        0, format, gl.UNSIGNED_BYTE, raw_data(img.pixels.buf))
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 4)

    texture.ratio = f32(img.width) / f32(img.height)
    return
}


texture_get_or_load :: proc (name: string) -> (texture: Texture) {
    if name in LOADED_TEXTURES {
        return LOADED_TEXTURES[name]
    }

    name_ext := strings.concatenate({ name, ".png" })
    delete(name_ext)

    full_path := fp.join({ "./assets/img", name_ext })
    defer delete(full_path)

    err: png.Error
    texture, err = texture_load_from_image_path(full_path)
    if err != nil {
        log.errorf("Failed loading image '{}': {}", full_path, err)
        texture = DEFAULT_COVER_TEXTURE
    }

    LOADED_TEXTURES[name] = texture

    return
}
