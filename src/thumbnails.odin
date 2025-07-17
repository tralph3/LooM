package main

import "http/client"
import "http"
import "core:log"
import "core:os/os2"
import "core:slice"
import "core:strings"
import "core:net"
import sdli "vendor:sdl3/image"
import sdl "vendor:sdl3"

@(private="file")
BASE_URL :: "https://thumbnails.libretro.com/"

// [0; 33] is Lowest quality, [34; 66] is Middle quality, [67; 100] is Highest quality.
// yes, the covers are at the lowest possible quality. they look good
// enough anyway. bumping to even medium quality results in 3x the
// file size on average.
THUMBNAIL_JPEG_QUALITY :: 1

thumbnail_download :: proc (system: string, name: string) -> (res: []byte, ok: bool) {
    url := strings.concatenate({
        BASE_URL,
        net.percent_encode(system, context.temp_allocator),
        "/Named_Boxarts/",
        net.percent_encode(name, context.temp_allocator),
        ".png"
    }, context.temp_allocator)

    response, err := client.get(url)
    if err != nil {
        log.errorf("Failed requesting thumbnail: {}", err)
        return nil, false
    }
    defer client.response_destroy(&response)

    body, was_alloc, body_err := client.response_body(&response)
    if body_err != nil {
        log.errorf("Failed reading response body: {}", body_err)
        return nil, false
    }
    defer client.body_destroy(body, was_alloc)

    body_str := body.(string) or_else ""
    if body_str == "" {
        log.error("Unexpected server response")
        return nil, false
    }

    res = slice.from_ptr(raw_data(body.(string)), len(body.(string)))
    stream := sdl.IOFromMem(raw_data(res), len(res))
    if !sdli.isJPG(stream) {
        // we do not close this IO, because that would free the memory
        // it points to, which actually belongs to the response body,
        // and will be freed when its destroyed
        surface := sdli.Load_IO(stream, closeio=false)
        if surface == nil {
            log.error("Failed loading downloaded cover image")
            return nil, false
        }
        defer sdl.DestroySurface(surface)

        jpg_stream := sdl.IOFromDynamicMem()
        io_start := sdl.TellIO(jpg_stream)

        defer sdl.CloseIO(jpg_stream)

        sdli.SaveJPG_IO(surface, jpg_stream, closeio=false, quality=THUMBNAIL_JPEG_QUALITY)
        sdl.SeekIO(jpg_stream, io_start, sdl.IO_SEEK_SET)

        size := sdl.GetIOSize(jpg_stream)
        res = make([]byte, size)

        sdl.ReadIO(jpg_stream, raw_data(res), len(res))
    } else {
        res = slice.clone(res)
    }

    ok = true
    return
}
