package rdb

import "core:os/os2"
import "core:encoding/endian"
import "core:slice"
import "core:strings"

RDB_HEADER : u64 : 0x52_41_52_43_48_44_42_00

// unless reading strings, we'll at most read 8 bytes at once. for
// those operations, this buffer will be reused.
BUFFER: [8]byte

ParseError :: enum {
    None,
    InvalidHeader,
    ByteUnpackingError,
    UnexpectedType,
    UnknownTypeError,
    UnsupportedItemType,
    NoCRCHash,
}

Error :: union #shared_nil {
    os2.Error,
    ParseError,
}

Item :: union {
    []byte,
    string,
    u8,
    u16,
    u32,
    u64,
    i8,
    i16,
    i32,
    i64,
}

Entry :: map[string]Item
Database :: map[u32]Entry

FIX_MAP_END   :: DataType(0x8F)
FIX_ARRAY_END :: DataType(0x9F)
FIX_STR_END   :: DataType(0xBF)
DataType :: enum u8 {
    FixMap    = 0x80,
    FixArray  = 0x90,
    FixStr    = 0xA0,

    Nil       = 0xC0,
    False     = 0xC2,
    True      = 0xC3,

    Bin8      = 0xC4,
    Bin16     = 0xC5,
    Bin32     = 0xC6,

    Uint8     = 0xCC,
    Uint16    = 0xCD,
    Uint32    = 0xCE,
    Uint64    = 0xCF,

    Int8      = 0xD0,
    Int16     = 0xD1,
    Int32     = 0xD2,
    Int64     = 0xD3,

    Str8      = 0xD9,
    Str16     = 0xDA,
    Str32     = 0xDB,

    Array16   = 0xDC,
    Array32   = 0xDD,

    Map16     = 0xDE,
    Map32     = 0xDF,
}

parse :: proc {
    parse_from_file,
    parse_from_path,
}

read_byte :: proc (file: ^os2.File) -> (res: byte, err: Error) {
    os2.read(file, BUFFER[:1]) or_return
    return BUFFER[0], nil
}

read_binary :: proc (file: ^os2.File, count: u32, allocator:=context.allocator) -> (res: []byte, err: Error) {
    buf := make([]byte, count, allocator)
    os2.read(file, buf) or_return
    return buf, nil
}

read_uint8 :: proc (file: ^os2.File) -> (res: u8, err: Error) {
    return read_byte(file)
}

read_uint16 :: proc (file: ^os2.File) -> (res: u16, err: Error) {
    os2.read(file, BUFFER[:2]) or_return
    val, ok := endian.get_u16(BUFFER[:2], .Big)
    if !ok { return 0, .ByteUnpackingError }

    return val, nil
}

read_uint32 :: proc (file: ^os2.File) -> (res: u32, err: Error) {
    os2.read(file, BUFFER[:4]) or_return
    val, ok := endian.get_u32(BUFFER[:4], .Big)
    if !ok { return 0, .ByteUnpackingError }

    return val, nil
}

read_uint64 :: proc (file: ^os2.File) -> (res: u64, err: Error) {
    os2.read(file, BUFFER[:8]) or_return
    val, ok := endian.get_u64(BUFFER[:8], .Big)
    if !ok { return 0, .ByteUnpackingError }

    return val, nil
}

read_int8 :: proc (file: ^os2.File) -> (res: i8, err: Error) {
    r := read_byte(file) or_return
    return i8(r), nil
}

read_int16 :: proc (file: ^os2.File) -> (res: i16, err: Error) {
    r := read_uint16(file) or_return
    return i16(r), nil
}

read_int32 :: proc (file: ^os2.File) -> (res: i32, err: Error) {
    r := read_uint32(file) or_return
    return i32(r), nil
}

read_int64 :: proc (file: ^os2.File) -> (res: i64, err: Error) {
    r := read_uint64(file) or_return
    return i64(r), nil
}

read_string :: proc (file: ^os2.File, length: u32, allocator:=context.allocator) -> (res: string, err: Error) {
    buf := make([]byte, length, allocator)
    os2.read(file, buf) or_return
    return strings.string_from_ptr(raw_data(buf), int(length)), nil
}

identify_type :: proc (file: ^os2.File) -> (type: DataType, size: u32, err: Error) {
    b := read_byte(file) or_return

    switch DataType(b) {
    // we don't care about the size for any of these types because its implicit
    case .Nil, .False, .True, .Uint8, .Uint16, .Uint32, .Uint64, .Int8, .Int16, .Int32, .Int64:
        type = DataType(b)
    case .FixMap..=FIX_MAP_END:
        type = .FixMap
        size = u32(b & 0b1111)
    case .FixStr..=FIX_STR_END:
        type = .FixStr
        size = u32(b & 0b11111)
    case .FixArray..=FIX_ARRAY_END:
        type = .FixArray
        size = u32(b & 0b1111)
    case .Str8:
        type = .Str8
        size = u32(read_uint8(file) or_return)
    case .Str16:
        type = .Str16
        size = u32(read_uint16(file) or_return)
    case .Str32:
        type = .Str32
        size = u32(read_uint32(file) or_return)
    case .Bin8:
        type = .Bin8
        size = u32(read_uint8(file) or_return)
    case .Bin16:
        type = .Bin16
        size = u32(read_uint16(file) or_return)
    case .Bin32:
        type = .Bin32
        size = u32(read_uint32(file) or_return)
    case .Map16:
        type = .Map16
        size = u32(read_uint16(file) or_return)
    case .Map32:
        type = .Map32
        size = u32(read_uint32(file) or_return)
    case .Array16:
        type = .Array16
        size = u32(read_uint16(file) or_return)
    case .Array32:
        type = .Array32
        size = u32(read_uint32(file) or_return)
    case:
        return nil, 0, .UnknownTypeError
    }

    return
}

read_item :: proc (file: ^os2.File) -> (item: Item, err: Error) {
    type, size := identify_type(file) or_return

    switch type {
    case .FixStr:
        item = read_string(file, size) or_return
    case .Bin8, .Bin16, .Bin32:
        item = read_binary(file, size) or_return
    case .Str8, .Str16, .Str32:
        item = read_string(file, size) or_return
    case .Uint8:
        item = read_uint8(file) or_return
    case .Uint16:
        item = read_uint16(file) or_return
    case .Uint32:
        item = read_uint32(file) or_return
    case .Uint64:
        item = read_uint64(file) or_return
    case .Int8:
        item = read_int8(file) or_return
    case .Int16:
        item = read_int16(file) or_return
    case .Int32:
        item = read_int32(file) or_return
    case .Int64:
        item = read_int64(file) or_return
    case .FixMap, .Map16, .Map32, .Nil:
        return nil, .UnexpectedType
    case .FixArray, .Array16, .Array32, .False, .True:
        return nil, .UnsupportedItemType
    }

    return
}

read_entry :: proc (file: ^os2.File, key_count: u32) -> (entry: Entry, crc: u32, err: Error) {
    for _ in 0..<key_count {
        key := read_item(file) or_return
        val := read_item(file) or_return

        #partial switch key_str in key {
        case string:
            if key_str == "crc" {
                val_byte_array, assertion_ok := val.([]byte)
                if !assertion_ok {
                    return nil, 0, .UnexpectedType
                }
                crc = parse_crc_hash(val_byte_array) or_return
                delete(key_str)
                delete(val_byte_array)
                continue
            }
            if key_str in entry {
                delete(key_str)
                delete_item(val)
                continue
            }
            entry[key_str] = val
        case:
            return nil, 0, .UnexpectedType
        }
    }

    if crc == 0 {
        delete_entry(entry)
        return nil, 0, .NoCRCHash
    }

    return
}

parse_crc_hash :: proc (crc: []byte) -> (hash: u32, err: Error) {
    val, ok := endian.get_u32(crc, .Big)
    if !ok {
        return 0, .ByteUnpackingError
    }

    return val, nil
}

validate_header :: proc (file: ^os2.File) -> (err: Error) {
    file_header := read_uint64(file) or_return
    if file_header != RDB_HEADER {
        return .InvalidHeader
    }

    return nil
}

parse_from_file :: proc (file: ^os2.File) -> (res: Database, err: Error) {
    validate_header(file) or_return

    // metadata start, we don't care
    _ = read_uint64(file) or_return

    loop: for {
        type, size := identify_type(file) or_return

        #partial switch type {
        case .FixMap, .Map16, .Map32:
            entry, crc, error := read_entry(file, size)
            if error == .NoCRCHash { continue }
            if crc in res {
                delete_entry(entry)
                continue
            }
            res[crc] = entry
        case .Nil:
            type, size = identify_type(file) or_return
            entry, crc, error := read_entry(file, size)
            if error != .NoCRCHash { return nil, error }
            break loop
        case:
            return nil, .UnexpectedType
        }
    }

    return
}

parse_from_path :: proc (file_path: string) -> (res: map[u32]Entry, err: Error) {
    f := os2.open(file_path) or_return
	defer os2.close(f)

    return parse_from_file(f)
}

delete_item :: proc (item: Item, allocator:=context.allocator) {
    #partial switch value in item {
    case string:
        delete(value, allocator)
    case []byte:
        delete(value, allocator)
    }
}

delete_entry :: proc (entry: Entry, allocator:=context.allocator) {
    for k, v in entry {
        delete(k, allocator)
        delete_item(v)
    }

    delete(entry)
}

delete_database :: proc (database: Database, allocator:=context.allocator) {
    for _, entry in database {
        delete_entry(entry, allocator)
    }

    delete(database)
}
