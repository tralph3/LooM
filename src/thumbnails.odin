package main

import "http/client"
import "http"
import "core:log"
import "core:os/os2"
import "core:slice"
import "core:strings"
import "core:net"

@(private="file")
BASE_URL :: "https://thumbnails.libretro.com/"

thumbnail_download :: proc (system: string, name: string) -> (ok: bool) {
    url := strings.concatenate({
        BASE_URL,
        net.percent_encode(system),
        "/Named_Boxarts/",
        net.percent_encode(name),
        ".png"
    })
    defer delete(url)

    res, err := client.get(url)
    if err != nil {
        log.errorf("Failed requesting thumbnail: {}", err)
        return false
    }
    defer client.response_destroy(&res)

    body, was_alloc, body_err := client.response_body(&res)
    if body_err != nil {
        log.errorf("Failed reading response body: {}", body_err)
        return false
    }
    defer client.body_destroy(body, was_alloc)

    body_str := body.(string) or_else ""
    if body_str == "" {
        log.error("Unexpected server response")
        return false
    }

    result := slice.from_ptr(raw_data(body.(string)), len(body.(string)))
    if err := os2.write_entire_file("./image.png", result); err != nil {

    }

    return true
}
