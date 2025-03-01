package main

import cb "circular_buffer"
import rl "vendor:raylib"
import "core:c"

audio_buffer_push_batch :: proc "c" (src: ^i16, frames: i32) -> i32 {
    bytes_pushed := cb.circular_buffer_push(&EMULATOR_STATE.audio_buffer.buffer, src, u64(frames * 4))

    return i32(bytes_pushed / 4)
}

audio_buffer_pop_batch :: proc "c" (dest: rawptr, frames: c.uint) {
    cb.circular_buffer_pop(&EMULATOR_STATE.audio_buffer.buffer, dest, u64(frames * 4))
}

audio_buffer_init :: proc "c" () {
    EMULATOR_STATE.audio_buffer.audio_stream = rl.LoadAudioStream(
        u32(EMULATOR_STATE.av_info.timing.sample_rate), 16, 2)

    rl.PlayAudioStream(
        EMULATOR_STATE.audio_buffer.audio_stream)
    rl.SetAudioStreamCallback(
        EMULATOR_STATE.audio_buffer.audio_stream, raylib_audio_sample_batch_callback)
}
