package circular_buffer

import "base:runtime"
import "core:mem"
import "core:fmt"
import "core:testing"
import "core:log"

CircularBuffer :: struct($Num: u64) where Num > 0 {
    read: u64,
    write: u64,
    data: [Num]byte,
    size: u64,
}

push :: proc (b: ^$T/CircularBuffer($N), src: rawptr, data_length: u64) -> u64 {
    capacity := u64(len(b.data))
    space_left := capacity - b.size
    length := data_length
    if length > space_left {
        // log.warnf("Tried to push more data than available (%d/%d)", length, space_left)
        length = space_left
    }
    if length == 0 {
        return 0
    }

    bytes_to_eob := capacity - b.write
    if bytes_to_eob < length {
        if bytes_to_eob > 0 {
            mem.copy_non_overlapping(&b.data[b.write], src, int(bytes_to_eob))
        }
        b.write = 0
        left_to_write := length - bytes_to_eob
        mem.copy_non_overlapping(&b.data[b.write], mem.ptr_offset((^byte)(src), bytes_to_eob), int(left_to_write))
        b.write += left_to_write
    } else {
        mem.copy_non_overlapping(&b.data[b.write], src, int(length))
        b.write += length
    }

    b.size += length
    return length
}

pop :: proc (b: ^$T/CircularBuffer($N), dest: rawptr, data_length: u64) -> u64 {
    length := data_length
    if length > b.size {
        // log.warnf("Tried to pop more data than available (%d/%d)", length, b.size)
        length = b.size
    }
    if length == 0 {
        return 0
    }

    capacity := u64(len(b.data))
    bytes_to_eob := capacity - b.read
    if bytes_to_eob < length {
        if bytes_to_eob > 0 {
            mem.copy_non_overlapping(dest, &b.data[b.read], int(bytes_to_eob))
        }
        b.read = 0
        left_to_read := length - bytes_to_eob
        mem.copy_non_overlapping(mem.ptr_offset((^byte)(dest), bytes_to_eob), &b.data[b.read], int(left_to_read))
        b.read += left_to_read
    } else {
        mem.copy_non_overlapping(dest, &b.data[b.read], int(length))
        b.read += length
    }

    b.size -= length
    return length
}

clear :: proc "contextless" (b: ^$T/CircularBuffer($N)) {
    b.write = 0
    b.read = 0
    b.size = 0
}
