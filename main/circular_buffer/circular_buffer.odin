package circular_buffer

import "base:runtime"
import "core:mem"
import "core:fmt"
import "core:testing"

CircularBuffer :: struct($Num: u64) where Num > 0 {
    read: u64,
    write: u64,
    data: [Num]byte,
    size: u64,
}

// Pushes up to data_length bytes from src into the circular buffer.
// Returns the number of bytes actually pushed.
circular_buffer_push :: proc "contextless" (b: ^$T/CircularBuffer($N), src: rawptr, data_length: u64) -> u64 {
    capacity := u64(len(b.data))
    space_left := capacity - b.size
    length := data_length
    if length > space_left {
        length = space_left
    }
    // Early return if nothing to push (prevents using an out-of-bounds pointer)
    if length == 0 {
        return 0;
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

// Pops up to data_length bytes from the circular buffer into dest.
// Returns the number of bytes actually popped.
circular_buffer_pop :: proc "contextless" (b: ^$T/CircularBuffer($N), dest: rawptr, data_length: u64) -> u64 {
    length := data_length
    if length > b.size {
        length = b.size
    }
    // Early return if nothing to pop (prevents using an out-of-bounds pointer)
    if length == 0 {
        return 0;
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

circular_buffer_clear :: proc "contextless" (b: ^$T/CircularBuffer($N)) {
    b.write = 0
    b.read = 0
    b.size = 0
}

//
// Tests
//

// Basic test: push a u32 and pop it.
@(test)
circular_buffer_can_push_and_pop :: proc (t: ^testing.T) {
    cb := CircularBuffer(4){}
    data: u32 = 69
    result: ^u32 = new(u32)
    defer free(result)

    circular_buffer_push(&cb, &data, size_of(u32))
    testing.expect_value(t, cb.size, 4)
    circular_buffer_pop(&cb, result, size_of(u32))
    testing.expect_value(t, data, result^)
}

// Test a crossing of the end-of-buffer boundary.
@(test)
circular_buffer_can_cross_boundary :: proc (t: ^testing.T) {
    cb := CircularBuffer(5){}
    data: u32 = 420
    result: ^u32 = new(u32)
    defer free(result)

    // First push/pop to set read/write near end.
    circular_buffer_push(&cb, &data, size_of(u32))
    testing.expect_value(t, cb.size, 4)
    circular_buffer_pop(&cb, result, size_of(u32))

    // Now push so that the write pointer will wrap.
    data = 1337
    circular_buffer_push(&cb, &data, size_of(u32))
    circular_buffer_pop(&cb, result, size_of(u32))
    testing.expect_value(t, data, result^)
}

// Test that when there is not enough space, only the available space is used.
@(test)
circular_buffer_drops_data_when_no_space_left :: proc (t: ^testing.T) {
    cb := CircularBuffer(2){}
    data: u32 = 293
    result: ^u16 = new(u16)
    defer free(result)

    // Only 2 bytes can be stored from the 4-byte u32.
    circular_buffer_push(&cb, &data, size_of(u32))
    testing.expect_value(t, cb.size, 2)
    circular_buffer_pop(&cb, result, size_of(u16))
    testing.expect_value(t, u16(data), result^)
}

// Test that a pop on an empty buffer does not modify the destination.
@(test)
circular_buffer_cant_read_from_empty_buffer :: proc (t: ^testing.T) {
    cb := CircularBuffer(2){}
    result: ^u8 = new(u8)
    result^ = 13
    defer free(result)

    circular_buffer_pop(&cb, result, size_of(u8))
    testing.expect_value(t, u8(13), result^)
}

// --- Additional tests ---

// Test FIFO order across multiple push/pop cycles, including wrap-around.
@(test)
circular_buffer_fifo_order :: proc (t: ^testing.T) {
    cb := CircularBuffer(10){}
    // Push 6 bytes (values 1..6)
    data_in: [6]u8 = [6]u8{1,2,3,4,5,6}
    out: [7]u8
    pushed := circular_buffer_push(&cb, &data_in[0], 6)
    testing.expect_value(t, pushed, 6)

    // Pop first 3 bytes; expect 1,2,3.
    popped := circular_buffer_pop(&cb, &out[0], 3)
    testing.expect_value(t, popped, 3)
    testing.expect_value(t, out[0], 1)
    testing.expect_value(t, out[1], 2)
    testing.expect_value(t, out[2], 3)

    // Push another 4 bytes (values 7,8,9,10)
    data_in2: [4]u8 = [4]u8{7,8,9,10}
    pushed2 := circular_buffer_push(&cb, &data_in2[0], 4)
    testing.expect_value(t, pushed2, 4)

    // At this point, the buffer holds: 4,5,6,7,8,9,10 (in order)
    total: u64
    popped_total := circular_buffer_pop(&cb, &out[0], total)
    testing.expect_value(t, popped_total, total)

    expected: [7]u8 = [7]u8{4,5,6,7,8,9,10}
    for i in 0..<total {
        testing.expect_value(t, out[i], expected[i])
    }
}

// Test that pushing more than the available capacity only writes what fits.
@(test)
circular_buffer_overflow_push :: proc (t: ^testing.T) {
    cb := CircularBuffer(5){}
    // Prepare 7 bytes of data.
    data_in: [7]u8 = [7]u8{10,20,30,40,50,60,70}
    pushed := circular_buffer_push(&cb, &data_in[0], 7)
    testing.expect_value(t, pushed, 5) // only capacity bytes can be pushed

    // Buffer is now full; an extra push should write 0 bytes.
    pushed2 := circular_buffer_push(&cb, &data_in[0], 2)
    testing.expect_value(t, pushed2, 0)
}

// Test that popping more bytes than available returns only the available bytes.
@(test)
circular_buffer_partial_pop :: proc (t: ^testing.T) {
    cb := CircularBuffer(6){}
    data_in: [4]u8 = [4]u8{1,2,3,4}
    circular_buffer_push(&cb, &data_in[0], 4)
    out: [4]u8 = [4]u8{0,0,0,0}

    // Request 6 bytes, but only 4 are available.
    popped := circular_buffer_pop(&cb, &out[0], 6)
    testing.expect_value(t, popped, 4)

    expected: [4]u8 = [4]u8{1,2,3,4}
    for i in 0..<4 {
        testing.expect_value(t, out[i], expected[i])
    }
}
