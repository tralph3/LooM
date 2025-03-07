package main

import cb "circular_buffer"
import rl "vendor:raylib"
import "core:c"

AUDIO_BUFFER_SIZE_BYTES :: 16384

AudioBuffer :: struct {
    buffer: cb.CircularBuffer(AUDIO_BUFFER_SIZE_BYTES),
    stream: rl.AudioStream,
}

audio_buffer_push_batch :: proc "c" (src: ^i16, frames: i32) -> i32 {
    context = GLOBAL_CONTEXT
    bytes_pushed := cb.circular_buffer_push(&STATE.audio.buffer, src, u64(frames * 4))

    return i32(bytes_pushed / 4)
}

audio_buffer_pop_batch :: proc "c" (dest: rawptr, frames: c.uint) {
    context = GLOBAL_CONTEXT
    cb.circular_buffer_pop(&STATE.audio.buffer, dest, u64(frames * 4))
}

audio_buffer_init :: proc "c" () {
    STATE.audio.stream = rl.LoadAudioStream(
        u32(STATE.av_info.timing.sample_rate), 16, 2)

    rl.PlayAudioStream(
        STATE.audio.stream)
    rl.SetAudioStreamCallback(
        STATE.audio.stream, raylib_audio_sample_batch_callback)
}
