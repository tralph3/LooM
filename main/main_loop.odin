package main

import "core:time"
import rl "vendor:raylib"
import cl "clay"

should_process_frame :: #force_inline proc (fps: f64, last_time: time.Time) -> bool {
    frame_time := 1 / fps

    elapsed_time := time.since(last_time)
    return time.duration_seconds(elapsed_time) > frame_time
}

update_clay_state :: #force_inline proc () {
    cl.SetLayoutDimensions({
        width = f32(rl.GetScreenWidth()),
        height = f32(rl.GetScreenHeight()),
    })

    mouse_pos := rl.GetMousePosition()
    cl.SetPointerState(
        { mouse_pos.x, mouse_pos.y, },
        rl.IsMouseButtonDown(.LEFT))

    mouse_wheel_move_v := rl.GetMouseWheelMoveV()
    cl.UpdateScrollContainers(
        true,
        { mouse_wheel_move_v.x, mouse_wheel_move_v.y } * 5,
        rl.GetFrameTime(),
    )
}

main_loop :: proc () {
    last_time := time.Time { _nsec = 0 }     // 2k38 compliant lulz

    for !STATE.should_exit && !rl.WindowShouldClose() {
        if (!should_process_frame(STATE.av_info.timing.fps, last_time)) {
            continue
        }
        last_time = time.now()

        process_input()

        update_clay_state()

        render()
    }

    quit()
}
