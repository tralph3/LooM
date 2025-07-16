package main

import gl "vendor:OpenGL"
import sdl "vendor:sdl3"
import "base:intrinsics"
import "core:reflect"
import "core:strings"
import "base:runtime"
import "core:log"

gl_load_shader_locs :: proc (uniform_table: ^$T, shader_program: u32, location := #caller_location) where intrinsics.type_is_struct(T) {
    for uniform in reflect.struct_fields_zipped(T) {
        #partial switch v in uniform.type.variant {
        case runtime.Type_Info_Integer:
            break
        case:
            log.warnf("Uniform '{}' is not an i32. Ignoring", uniform.name)
            continue
        }

        name_cstr := strings.clone_to_cstring(uniform.name)
        defer delete(name_cstr)

        loc := gl.GetUniformLocation(shader_program, name_cstr)

        uniform_ptr := (^i32)(uintptr(uniform_table) + uniform.offset)
        uniform_ptr^ = loc

        if loc == -1 {
            log.warnf("Uniform '{}' wasn't found in program.", uniform.name, location=location)
            continue
        }
	}
}

gl_load_shader :: proc {
    gl_load_shader_with_locs,
    gl_load_shader_no_locs,
}

gl_load_shader_with_locs :: proc (vert, frag: cstring, uniform_table: ^$T, location := #caller_location) -> (program_id: u32, ok: bool) where intrinsics.type_is_struct(T) {
    program_id = gl_load_shader_impl(vert, frag) or_return
    gl_load_shader_locs(uniform_table, program_id, location=location)

    return program_id, true
}

gl_load_shader_no_locs :: proc (vert, frag: cstring) -> (program_id: u32, ok: bool) {
    return gl_load_shader_impl(vert, frag)
}

gl_load_shader_impl :: proc (vert, frag: cstring) -> (progam_id: u32, ok: bool) {
    vert := vert
    frag := frag

    vertex_shader := gl.CreateShader(gl.VERTEX_SHADER)
    gl.ShaderSource(vertex_shader, 1, &vert, nil)
    gl.CompileShader(vertex_shader)

    success: i32
    gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &success);
    if !bool(success) {
        log_str := gl_get_shader_log(vertex_shader)
        defer delete(log_str)

        log.errorf("Vertex compilation failed: {}", log_str)
        return 0, false
    }

    fragment_shader := gl.CreateShader(gl.FRAGMENT_SHADER)
    gl.ShaderSource(fragment_shader, 1, &frag, nil)
    gl.CompileShader(fragment_shader)

    gl.GetShaderiv(fragment_shader, gl.COMPILE_STATUS, &success);
    if !bool(success) {
        log_str := gl_get_shader_log(fragment_shader)
        defer delete(log_str)

        log.errorf("Fragment compilation failed: {}", log_str)
        return 0, false
    }

    shader_program := gl.CreateProgram()
    gl.AttachShader(shader_program, vertex_shader)
    gl.AttachShader(shader_program, fragment_shader)
    gl.LinkProgram(shader_program)

    gl.GetProgramiv(shader_program, gl.LINK_STATUS, &success);
    if !bool(success) {
        log_str := gl_get_program_log(shader_program)
        defer delete(log_str)

        log.errorf("Program linking failed: {}", log_str)
        return 0, false
    }

    gl.DeleteShader(vertex_shader)
    gl.DeleteShader(fragment_shader)

    return shader_program, true
}

gl_get_shader_log :: proc(shader: u32) -> string {
    info_log_len: i32
    gl.GetShaderiv(shader, gl.INFO_LOG_LENGTH, &info_log_len)

    if info_log_len > 1 {
        buffer := make([^]u8, info_log_len)
        gl.GetShaderInfoLog(shader, info_log_len, nil, buffer)
        return strings.string_from_ptr(buffer, int(info_log_len))
    }

    return strings.clone("")
}

gl_get_program_log :: proc(program: u32) -> string {
    info_log_len: i32
    gl.GetProgramiv(program, gl.INFO_LOG_LENGTH, &info_log_len)

    if info_log_len > 1 {
        buffer := make([^]u8, info_log_len)
        gl.GetShaderInfoLog(program, info_log_len, nil, buffer)
        return strings.string_from_ptr(buffer, int(info_log_len))
    }

    return strings.clone("")
}

gl_load_texture_from_surface :: proc "contextless" (surface: ^sdl.Surface) -> (id: u32) {
    assert_contextless(surface.format == .RGBA8888)

    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)

    gl.GenTextures(1, &id)
    gl.BindTexture(gl.TEXTURE_2D, id)

    gl.TexImage2D(
        gl.TEXTURE_2D, 0, gl.RGBA8,
        surface.w, surface.h,
        0, gl.RGBA, gl.UNSIGNED_INT_8_8_8_8, surface.pixels)

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 4)

    return id
}
