package main

import gl "vendor:OpenGL"
import fp "core:path/filepath"
import "core:os/os2"
import "core:log"
import "core:strings"
import sdl "vendor:sdl3"
import sdli "vendor:sdl3/image"

BASE_TEXTURE_PATH :: "./assets/images/"

Texture :: struct {
    gl_id: u32,
    width: f32,
    height: f32,
}

TextureID :: enum {
    NoCover,
    TextureLoading,
    ControllerConnected,
    ControllerDisconnected,
}

TexturePaths :: [TextureID]string {
        .NoCover = "nocover",
        .TextureLoading = "nocover",
        .ControllerConnected = "controller_connected",
        .ControllerDisconnected = "controller_disconnected",
}

texture_load_stock :: proc (internal_path: string) -> (tex: Texture, ok: bool){
    filename := strings.concatenate({ internal_path, ".png" })
    defer delete(filename)

    full_path := fp.join({ BASE_TEXTURE_PATH, filename })
    defer delete(full_path)

    return texture_load(full_path)
}

texture_load :: proc {
    texture_load_from_path,
    texture_load_from_bytes,
}

texture_load_from_path :: proc (path: string) -> (tex: Texture, ok: bool) {
    bytes, err := os2.read_entire_file(path, context.allocator)
    if err != nil {
        ok = false
        return
    }
    defer delete(bytes)

    return texture_load_from_bytes(bytes)
}

texture_load_from_bytes :: proc (bytes: []byte) -> (tex: Texture, ok: bool) {
    stream := sdl.IOFromMem(raw_data(bytes), len(bytes))
    if stream == nil {
        ok = false
        return
    }

    surface := sdli.Load_IO(stream, closeio=true)
    if surface == nil {
        ok = false
        return
    }

    if surface.format != .RGBA8888 {
        old_surface := surface
        defer sdl.DestroySurface(old_surface)

        surface = sdl.ConvertSurface(surface, .RGBA8888)
        if surface == nil {
            ok = false
            return
        }
    }

    defer sdl.DestroySurface(surface)

    Data :: struct {
        surface: ^sdl.Surface,
        tex: ^Texture,
    }

    data := Data{
        surface = surface,
        tex = &tex,
    }

    // if texture_load is called on the main thread, this callback
    // runs immediately. if not, the thread will get blocked until
    // texture loading is complete. that also ensures that stack
    // allocated variables like `data` won't get freed by the time the
    // callback runs... we need this because we can't load a GL
    // texture on another thread.
    if !sdl.RunOnMainThread(
        proc "c" (data: rawptr) {
            d := cast(^Data)data

            d.tex.gl_id = gl_load_texture_from_surface(d.surface)
            d.tex.width = f32(d.surface.w)
            d.tex.height = f32(d.surface.h)
        }, &data, wait_complete=true)
    {
        ok = false
        return
    }

    return tex, true
}

texture_unload :: proc (tex: ^Texture) {
    gl.DeleteTextures(1, &tex.gl_id)
}
