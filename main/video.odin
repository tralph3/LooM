package main

import lr "libretro"
import rl "vendor:raylib"

FrameBuffer :: struct {
    data: rawptr,
    width: i32,
    height: i32,
    pitch: i32,
    pixel_format: lr.RetroPixelFormat,
    render_texture: rl.Texture2D,
}

render_texture_init :: proc () {
    render_texture := rl.LoadRenderTexture(STATE.video.width, STATE.video.height)
    defer rl.UnloadRenderTexture(render_texture)

    image := rl.LoadImageFromTexture(render_texture.texture)
    defer rl.UnloadImage(image)

    raylib_format: rl.PixelFormat = ---
    switch STATE.video.pixel_format {
    case lr.RetroPixelFormat.ZRGB1555:
        raylib_format = rl.PixelFormat.UNCOMPRESSED_R5G5B5A1 // TODO: check if this is actually correct
    case lr.RetroPixelFormat.XRGB8888:
        raylib_format = rl.PixelFormat.UNCOMPRESSED_R8G8B8A8
    case lr.RetroPixelFormat.RGB565:
        raylib_format = rl.PixelFormat.UNCOMPRESSED_R5G6B5
    }

    rl.ImageFormat(&image, raylib_format)

    STATE.video.render_texture = rl.LoadTextureFromImage(image)
}

frame_buffer_update :: proc "c" (data: rawptr, width: u32, height: u32, pitch: u32) {
    // frame duping support
    if data == nil {
        return
    }

    STATE.video.data = data
    STATE.video.width = i32(width)
    STATE.video.height = i32(height)
    STATE.video.pitch = i32(pitch)

    // branch predictor save us
    if STATE.video.pixel_format == lr.RetroPixelFormat.XRGB8888 {
        xrgb_to_rgba(&STATE.video)
    }
}
