package bild

import "core:os/os2"
import "core:strings"
import "core:fmt"
import fp "core:path/filepath"

BaseTarget :: struct {
    workdir: string,
    env: []string,
    depends: []Target,
    dest: string,
}

OdinFlags :: enum {
    Debug,
}

OdinCollection :: struct {
    name: string,
    dir: string,
}

OdinErrorStyle :: enum {
    Default,
    Odin,
    Unix,
}

OdinTarget :: struct {
    using t: BaseTarget,
    pkg_path: string,
    flags: bit_set[OdinFlags],
    collections: []OdinCollection,
    error_style: OdinErrorStyle,
}

CBuildMode :: enum {
    Object,
    Archive,
}

CCompiler :: enum {
    Default,
    GCC,
    Clang,
    MSVC,
}

CTarget :: struct {
    using t: BaseTarget,
    mode: CBuildMode,
    defines: []string,
    files: []string,
    compiler: CCompiler,
}

Target :: union {
    OdinTarget,
    CTarget,
}

run_cmd :: proc (cmd: []string, env: []string, workdir: string) -> (ok: bool) {
    str := strings.join(cmd, " ")
    fmt.printfln("[COMMAND] %s", str)

    handle, start_error := os2.process_start({
        command = cmd,
        stdout = os2.stdout,
        stderr = os2.stderr,
        working_dir = workdir,
        env = env,
    })

    if start_error != nil {
        fmt.eprintfln("[ERROR] Failed running command: '%s'", str)
        return false
    }

    state, wait_error := os2.process_wait(handle)
    if state.exit_code != 0 || wait_error != nil {
        fmt.eprintfln("[ERROR] Failed running command: '%s'", str)
        return false
    }

    return true
}

sync_submodules :: proc () -> (ok: bool) {
    cmd: [dynamic]string

    append(&cmd, "git")
    append(&cmd, "submodule")
    append(&cmd, "update")
    append(&cmd, "--init")
    append(&cmd, "--recursive")

    return run_cmd(cmd[:], {}, "")
}

change_extension :: proc (str: string, new_ext: string) -> string {
    dir := fp.dir(str)
    return fp.join({
        dir,
        strings.concatenate({ fp.stem(str), new_ext })
    })
}

compile_c :: proc (target: CTarget) -> (ok: bool) {
    for t in target.depends {
        compile_target(t) or_return
    }

    compiler: CCompiler
    if target.compiler == .Default {
        when ODIN_OS == .Windows {
            compiler = .MSVC
        } else when ODIN_OS == .Linux {
            compiler = .GCC
        } else {
            compiler = .Clang
        }
    } else {
        compiler = target.compiler
    }

    switch compiler {
    case .GCC:     return compile_c_gcc_like(target, "gcc")
    case .Clang:   return compile_c_gcc_like(target, "clang")
    case .MSVC:    return compile_c_msvc(target)
    case .Default:
        fmt.eprintfln("[ERROR] Tried to compile with 'Default' compiler. Invalid")
        return false
    }

    fmt.eprintfln("[ERROR] Unknown C compiler used")
    return false
}

compile_c_gcc_like :: proc (target: CTarget, compiler_name: string) -> (ok: bool) {
    cmd: [dynamic]string
    append(&cmd, compiler_name, "-x", "c")
    if target.mode == .Archive || target.mode == .Object {
        append(&cmd, "-c")
    }

    for define in target.defines {
        append(&cmd, fmt.tprintf("-D%s", define))
    }

    for file in target.files {
        append(&cmd, file)
    }

    append(&cmd, "-o")
    if target.mode == .Archive {
        append(&cmd, change_extension(target.dest, ".o"))
    } else {
        append(&cmd, change_extension(target.dest, ".o"))
    }

    run_cmd(cmd[:], target.env, target.workdir) or_return

    if target.mode != .Archive { return true }
    clear(&cmd)
    append(&cmd, "ar", "rcs", change_extension(target.dest, ".a"), change_extension(target.dest, ".o"))

    return run_cmd(cmd[:], target.env, target.workdir)
}

compile_c_msvc :: proc (target: CTarget) -> (ok: bool) {
    cmd: [dynamic]string
    append(&cmd, "cl", "/EHsc", "/EHa-", "/GR-", "/nologo")
    if target.mode == .Archive || target.mode == .Object {
        append(&cmd, "/c")
    }

    for define in target.defines {
        append(&cmd, fmt.tprintf("/D%s", define))
    }

    for file in target.files {
        append(&cmd, "/Tc", file)
    }

    if target.mode == .Archive || target.mode == .Object {
        append(&cmd, fmt.tprintf("/Fo%s", change_extension(target.dest, ".obj")))
    } else {
        append(&cmd, fmt.tprintf("/Fe%s", target.dest))
    }

    run_cmd(cmd[:], target.env, target.workdir) or_return

    if target.mode != .Archive { return true }
    clear(&cmd)

    append(&cmd, "lib")
    append(&cmd, fmt.tprintf("/OUT:%s", change_extension(target.dest, ".lib")))
    append(&cmd, change_extension(target.dest, ".obj"))

    return run_cmd(cmd[:], target.env, target.workdir)
}

compile_odin :: proc (target: OdinTarget) -> (ok: bool) {
    for t in target.depends {
        compile_target(t) or_return
    }

    if err := os2.make_directory_all(fp.dir(target.dest)); err != nil && err != .Exist {
        fmt.eprintfln("[ERROR] Failed making destination directory: %s", err)
        return false
    }

    cmd: [dynamic]string
    append(&cmd, "odin", "build", target.pkg_path)
    when ODIN_OS == .Windows {
        append(&cmd, fmt.tprintf("-out:%s.exe", target.dest))
    } else {
        append(&cmd, fmt.tprintf("-out:%s", target.dest))
    }


    for c in target.collections {
        str := fmt.tprintf("-collection:%s=%s", c.name, c.dir)
        append(&cmd, str)
    }

    if .Debug in target.flags {
        append(&cmd, "-debug")
    }

    if target.error_style == .Odin {
        append(&cmd, "-error-pos-style:odin")
    } else if target.error_style == .Unix {
        append(&cmd, "-error-pos-style:unix")
    }

    return run_cmd(cmd[:], target.env, target.workdir)
}

compile_target :: proc (target: Target) -> (ok: bool) {
    switch t in target {
    case OdinTarget:
        compile_odin(t) or_return
    case CTarget:
        compile_c(t) or_return
    }

    return true
}
