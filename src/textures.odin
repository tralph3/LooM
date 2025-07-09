package main

import gl "vendor:OpenGL"
import "core:image"
import "core:image/png"
import fp "core:path/filepath"
import "core:log"
import "core:strings"
import "core:slice"
import sdl "vendor:sdl3"
import sdl_image "vendor:sdl3/image"
import "core:sync/chan"
import "core:thread"
import "core:mem"
import "core:bytes"

Texture :: struct {
    gl_id: u32,
    ratio: f32,
}

@(private="file")
TextureRequest :: struct {
    name: string,
}

@(private="file")
TextureResult :: struct {
    name: string,
    img: ^image.Image,
}

LOADED_TEXTURES: map[string]Texture
DEFAULT_COVER_TEXTURE: Texture

TEXTURE_REQUEST_CHAN: chan.Chan(TextureRequest, .Both)
TEXTURE_RESULT_CHAN: chan.Chan(TextureResult, .Both)

textures_init :: proc () -> (ok: bool) {
    image.register(kind = .JPEG, loader = jpeg_image_loader, destroyer = jpeg_image_destroyer)

    err: image.Error
    DEFAULT_COVER_TEXTURE, err = texture_load_from_path("./assets/img/nocover.png")
    if err != nil {
        log.errorf("Failed loading default cover art: {}", err)
        return false
    }

    if t := thread.create_and_start(rstrt, context, self_cleanup=true); t == nil {
        log.error("Failed to create thread")
        return false
    }

    TEXTURE_REQUEST_CHAN, err = chan.create(type_of(TEXTURE_REQUEST_CHAN), 30, context.allocator)
    if err != nil {
        log.errorf("Failed creating request channel: {}", err)
        return false
    }

    TEXTURE_RESULT_CHAN, err = chan.create(type_of(TEXTURE_RESULT_CHAN), 30, context.allocator)
    if err != nil {
        log.errorf("Failed creating result channel: {}", err)
        return false
    }

    return true
}

textures_deinit :: proc () {
    chan.close(TEXTURE_REQUEST_CHAN)
    chan.close(TEXTURE_RESULT_CHAN)

    chan.destroy(TEXTURE_REQUEST_CHAN)
    chan.destroy(TEXTURE_RESULT_CHAN)

    for name, &tex in LOADED_TEXTURES {
        delete(name)
        gl.DeleteTextures(1, &tex.gl_id)
    }

    delete(LOADED_TEXTURES)
}

texture_load_from_path :: proc (path: string) -> (texture: Texture, err: image.Error) {
    img := image.load(path) or_return
    defer image.destroy(img)

    return texture_load_from_image(img), nil
}

texture_load_from_bytes :: proc (bytes: []byte) -> (texture: Texture, err: image.Error) {
    img := image.load(bytes) or_return
    defer image.destroy(img)

    return texture_load_from_image(img), nil
}

texture_load_from_image :: proc (img: ^image.Image) -> (texture: Texture) {
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

    if img.height == 0 {
        texture.ratio = 0
    } else {
        texture.ratio = f32(img.width) / f32(img.height)
    }

    return
}

texture_get_or_load :: proc (name: string) -> (texture: Texture) {
    for res in chan.try_recv(TEXTURE_RESULT_CHAN) {
        defer delete(res.name)
        defer image.destroy(res.img)

        tex: Texture
        if res.img == nil {
            tex = DEFAULT_COVER_TEXTURE
        } else {
            tex = texture_load_from_image(res.img)
        }

        LOADED_TEXTURES[res.name] = tex
    }

    if name in LOADED_TEXTURES {
        return LOADED_TEXTURES[name]
    }

    chan.send(TEXTURE_REQUEST_CHAN, TextureRequest{
        name = strings.clone(name),
    })

    LOADED_TEXTURES[strings.clone(name)] = DEFAULT_COVER_TEXTURE

    return LOADED_TEXTURES[name]
}

rstrt :: proc () {
    for res in chan.recv(TEXTURE_REQUEST_CHAN) {
        name := res.name

        name_ext := strings.concatenate({ name, ".png" })
        defer delete(name_ext)

        full_path := fp.join({ "./assets/img", name_ext })
        defer delete(full_path)

        tex_result := TextureResult{ name = name }

        err: image.Error
        tex_result.img, err = image.load(full_path)
        if err != nil {
            log.errorf("Failed loading image '{}': {}", full_path, err)
            tex_result.img = nil
        }

        chan.send(TEXTURE_RESULT_CHAN, tex_result)
    }
}

jpeg_image_loader :: proc (data: []byte, options: image.Options, allocator: mem.Allocator) -> (img: ^image.Image, err: image.Error) {
    img = new(image.Image, allocator) or_return
    stream := sdl.IOFromMem(raw_data(data), len(data))
    if stream == nil {
        return nil, .Unable_To_Read_File
    }
    defer sdl.CloseIO(stream)

    surface := sdl_image.LoadJPG_IO(stream)
    if surface == nil {
        return nil, .Invalid_Input_Image
    }
    defer sdl.DestroySurface(surface)

    if surface.format != .RGB24 {
        old_surface := surface
        defer sdl.DestroySurface(old_surface)

        surface = sdl.ConvertSurface(surface, .RGB24)
        if surface == nil {
            return nil, .Unable_To_Read_File
        }
    }

    img.width = int(surface.w)
    img.height = int(surface.h)
    img.channels = 3
    img.depth = 8
    img.which = .JPEG

    buf: bytes.Buffer
    pixels := slice.from_ptr((^u8)(surface.pixels), int(surface.pitch * surface.h))
    bytes.buffer_init(&buf, pixels)
    img.pixels = buf
    return
}

jpeg_image_destroyer :: proc (img: ^image.Image) {
    bytes.buffer_destroy(&img.pixels)
    free(img)
}
