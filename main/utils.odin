package main

import "core:mem"

xrgb_to_rgba :: proc "c" (buffer: ^FrameBuffer) {
    buffer_slice := mem.slice_ptr((^u32)(buffer.data), int(buffer.height * (buffer.pitch / 4)))

    for pixel, i in buffer_slice {
        r: u32 = (pixel >> 16) & 0xFF
        g: u32 = (pixel >> 8)  & 0xFF
        b: u32 = (pixel >> 0)  & 0xFF
        a: u32 = 0xFF

        buffer_slice[i] = (a << 24) | (b << 16) | (g << 8) | r
    }
}
