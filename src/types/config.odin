package types

UserConfig :: struct #no_copy {
    saves_path: string,
    system_path: string,
}

SystemConfig :: struct {
    name: string,
    core: string,
}
