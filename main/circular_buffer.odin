package main

import "base:runtime"
import "core:mem"
import "core:fmt"

CircularBuffer :: struct($Num: u64) where Num > 0 {
    read: u64,
    write: u64,
    data: [Num]byte,
}

bytes_to_read: u64 = 0

circular_buffer_push :: proc "contextless" (b: ^$T/CircularBuffer($N), src: rawptr, data_length: u64) {
    space_left := len(b.data) - u64(bytes_to_read)
    length := data_length
    if length > space_left {
        length = space_left
    }

    bytes_to_eob := len(b.data) - b.write
    if bytes_to_eob < length {
        if bytes_to_eob > 0 {
            mem.copy_non_overlapping(&b.data[b.write], src, int(bytes_to_eob))
        }
        b.write = 0
        left_to_write := length - bytes_to_eob
        mem.copy_non_overlapping(&b.data[b.write], mem.ptr_offset((^u8)(src), bytes_to_eob), int(left_to_write))
        b.write += left_to_write
    } else {
        mem.copy_non_overlapping(&b.data[b.write], src, int(length))
        b.write += length
    }

    bytes_to_read += length
}

circular_buffer_pop :: proc "contextless" (b: ^$T/CircularBuffer($N), dest: rawptr, data_length: u64) {
    length := data_length
    if length > u64(bytes_to_read) {
        length = u64(bytes_to_read)
    }

    bytes_to_eob := len(b.data) - b.read
    if bytes_to_eob < length {
        if bytes_to_eob > 0 {
            mem.copy_non_overlapping(dest, &b.data[b.read], int(bytes_to_eob))
        }
        b.read = 0
        left_to_read := length - bytes_to_eob
        mem.copy_non_overlapping(mem.ptr_offset((^u8)(dest), bytes_to_eob), &b.data[b.read], int(left_to_read))
        b.read += left_to_read
    } else {
        mem.copy_non_overlapping(dest, &b.data[b.read], int(length))
        b.read += length
    }

    bytes_to_read -= length
}
