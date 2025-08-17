package allocators

import "core:mem"
import "core:slice"
import "core:fmt"

DynamicArena :: struct {
    block_size: int,
    out_of_band_size: int,
    blocks: [dynamic]mem.Arena,
    out_of_band_blocks: [dynamic][]byte,
    current_block_index: int,
    block_allocator: mem.Allocator,
}

dynamic_arena_init :: proc (
    arena: ^DynamicArena,
    block_size := mem.DYNAMIC_ARENA_BLOCK_SIZE_DEFAULT,
    out_of_band_size := mem.DYNAMIC_ARENA_OUT_OF_BAND_SIZE_DEFAULT,
    block_allocator := context.allocator,
    loc:=#caller_location,
) {
    arena^ = {}

    arena.block_size = block_size
    arena.out_of_band_size = out_of_band_size
    // will get upped to 0 when adding the initial block
    arena.current_block_index = -1
    arena.block_allocator = block_allocator

    arena.blocks.allocator             = block_allocator
    arena.out_of_band_blocks.allocator = block_allocator

    dynamic_arena_add_block(arena, loc=loc)
}

dynamic_arena_add_block :: proc (arena: ^DynamicArena, alignment: int = mem.DEFAULT_ALIGNMENT, loc:=#caller_location) -> (a: ^mem.Arena, err: mem.Allocator_Error) {
    new_block: mem.Arena
    buf := mem.make_aligned([]byte, arena.block_size, alignment, arena.block_allocator, loc) or_return
    mem.arena_init(&new_block, buf)
    append(&arena.blocks, new_block)
    arena.current_block_index += 1

    #no_bounds_check ret := &arena.blocks[arena.current_block_index]
    return ret, nil
}

dynamic_arena_allocate_out_of_band :: proc (arena: ^DynamicArena, size, alignment: int, loc:=#caller_location) -> (new_mem: []byte, err: mem.Allocator_Error) {
    new_mem = mem.make_aligned([]byte, size, alignment, arena.block_allocator, loc) or_return
    append(&arena.out_of_band_blocks, new_mem, loc) or_return

    return
}

dynamic_arena_destroy :: proc (arena: ^DynamicArena) {
    for block in arena.blocks {
        delete(block.data, arena.block_allocator)
    }

    for block in arena.out_of_band_blocks {
        delete(block, arena.block_allocator)
    }

    delete(arena.blocks)
    delete(arena.out_of_band_blocks)
}

dynamic_arena_allocator :: proc (arena: ^DynamicArena) -> mem.Allocator {
    return {
        procedure = dynamic_arena_allocator_proc,
        data = arena,
    }
}

dynamic_arena_allocator_proc :: proc(
	allocator_data: rawptr,
	mode:           mem.Allocator_Mode,
	size:           int,
	alignment:      int,
	old_memory:     rawptr,
	old_size:       int,
	loc := #caller_location,
) -> ([]byte, mem.Allocator_Error) {
    dynamic_arena := (^DynamicArena)(allocator_data)
    #no_bounds_check arena := &dynamic_arena.blocks[dynamic_arena.current_block_index]

    switch mode {
    case .Alloc, .Alloc_Non_Zeroed:
        if size >= dynamic_arena.out_of_band_size || size > dynamic_arena.block_size {
            return dynamic_arena_allocate_out_of_band(dynamic_arena, size, alignment, loc)
        } else {
            new_mem, err := mem.arena_allocator_proc(arena, mode, size, alignment, old_memory, old_size, loc)

            if err == .Out_Of_Memory {
                new_arena, err := dynamic_arena_add_block(dynamic_arena, alignment)
                if err != nil { return nil, err }
                return mem.arena_allocator_proc(new_arena, mode, size, alignment, old_memory, old_size, loc)
            } else if err != nil {
                return nil, err
            }

            return new_mem, nil
        }
    case .Resize:
        return dynamic_arena_allocator_resize(dynamic_arena, slice.from_ptr((^byte)(old_memory), old_size), size, alignment, loc)
    case .Resize_Non_Zeroed:
        return dynamic_arena_allocator_resize_non_zeroed(dynamic_arena, slice.from_ptr((^byte)(old_memory), old_size), size, alignment, loc)
    case .Free_All:
        dynamic_arena_allocator_free_all(dynamic_arena)
    case .Query_Info, .Free:
        return nil, .Mode_Not_Implemented
    case .Query_Features:
        set := (^mem.Allocator_Mode_Set)(old_memory)
		if set != nil {
			set^ = { .Alloc, .Alloc_Non_Zeroed, .Resize, .Resize_Non_Zeroed, .Free_All, .Query_Features }
		}
    }

    return nil, nil
}

dynamic_arena_allocator_resize :: proc (arena: ^DynamicArena, old_data: []byte, size, alignment: int, loc:=#caller_location) -> (new_mem: []byte, err: mem.Allocator_Error) {
    new_mem = dynamic_arena_allocator_resize_non_zeroed(arena, old_data, size, alignment, loc) or_return
    if old_data == nil {
        slice.zero(new_mem)
    } else if size > len(old_data) {
        slice.zero(new_mem[len(old_data):])
    }
    return
}

dynamic_arena_allocator_resize_non_zeroed :: proc (arena: ^DynamicArena, old_data: []byte, size, alignment: int, loc:=#caller_location) -> (new_mem: []byte, err: mem.Allocator_Error) {
    if size <= len(old_data) {
        return old_data[:size], nil
    } else if size > len(old_data) {
        new_mem = dynamic_arena_allocator_proc(arena, .Alloc_Non_Zeroed, size, alignment, nil, 0, loc) or_return
        copy(new_mem, old_data)
        return
    }

    panic(fmt.tprintf("Unreachable. Size didn't fall in any range: %d", size), loc)
}

dynamic_arena_allocator_free_all :: proc (arena: ^DynamicArena) {
    if len(arena.blocks) > 1 {
        for block in arena.blocks[1:] {
            delete(block.data, arena.block_allocator)
        }
    }

    for block in arena.out_of_band_blocks {
        delete(block, arena.block_allocator)
    }

    mem.arena_free_all(&arena.blocks[0])

    clear(&arena.out_of_band_blocks)
    resize(&arena.blocks, 1)

    arena.current_block_index = 0
}
