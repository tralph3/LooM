package main

import cb "circular_buffer"
import sdl "vendor:sdl3"
import "core:c"
import "core:log"
import "core:mem"

BYTES_PER_FRAME :: 4

AUDIO_BUFFER_SIZE_BYTES :: 1024 * 64
AUDIO_BUFFER_UNDERRUN_LIMIT :: 1024 * 12
AUDIO_BUFFER_OVERFLOW_LIMIT :: 1024 * 52

AudioState :: struct #no_copy {
    buffer: cb.CircularBuffer(AUDIO_BUFFER_SIZE_BYTES),
    stream: ^sdl.AudioStream,
}

audio_buffer_push_batch :: proc "c" (src: ^i16, frames: i32) -> i32 {
    context = state_get_context()
    bytes_pushed := cb.push(&GLOBAL_STATE.audio_state.buffer, src, u64(frames * BYTES_PER_FRAME))

    return i32(bytes_pushed / BYTES_PER_FRAME)
}

audio_buffer_pop_batch :: proc "c" (userdata: rawptr, stream: ^sdl.AudioStream, additional_amount, total_amount: c.int) {
    context = state_get_context()

    buffered_bytes := int(GLOBAL_STATE.audio_state.buffer.size)
    if buffered_bytes < AUDIO_BUFFER_UNDERRUN_LIMIT {
        return
    }

    cb.pop_to_audio_stream(&GLOBAL_STATE.audio_state.buffer, GLOBAL_STATE.audio_state.stream, u64(additional_amount))
}

audio_init :: proc "c" () -> (ok: bool) {
    context = state_get_context()

    GLOBAL_STATE.audio_state.stream = sdl.OpenAudioDeviceStream(
        sdl.AUDIO_DEVICE_DEFAULT_PLAYBACK,
        &{
            format = .S16LE,
            channels = 2,
            freq = 48000,
        },
        audio_buffer_pop_batch,
        nil,
    )
    if GLOBAL_STATE.audio_state.stream == nil {
        log.errorf("Failed creating audio device: {}", sdl.GetError())
        return false
    }

    sdl.ResumeAudioStreamDevice(GLOBAL_STATE.audio_state.stream)

    return true
}

audio_update_sample_rate :: proc () {
    dst_spec: sdl.AudioSpec
    src_spec: sdl.AudioSpec
    sdl.GetAudioStreamFormat(GLOBAL_STATE.audio_state.stream, &src_spec, &dst_spec)

    dst_spec.freq = i32(GLOBAL_STATE.emulator_state.av_info.timing.sample_rate)
    src_spec.freq = i32(GLOBAL_STATE.emulator_state.av_info.timing.sample_rate)
    sdl.SetAudioStreamFormat(GLOBAL_STATE.audio_state.stream, &src_spec, &dst_spec)
}

audio_deinit :: proc () {
    // This also destroys the bound device because it was created with
    // OpenAudioDeviceStream
    sdl.DestroyAudioStream(GLOBAL_STATE.audio_state.stream)
}
