package main

import "core:thread"
import "core:log"
import sdl "vendor:sdl3"

THREAD_POOL: thread.Pool
THREAD_POOL_THREAD_COUNT :: 30

thread_pool_init :: proc () -> (ok: bool) {
    thread.pool_init(&THREAD_POOL, context.allocator, THREAD_POOL_THREAD_COUNT)
    thread.pool_start(&THREAD_POOL)

    return true
}

thread_pool_deinit :: proc () {
    thread.pool_finish(&THREAD_POOL)
    thread.pool_destroy(&THREAD_POOL)
}

thread_pool_add_task :: proc (task: thread.Task_Proc, data: rawptr, index: int) {
    thread.pool_add_task(&THREAD_POOL, context.allocator, task, data, index)
}
