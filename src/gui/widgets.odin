// Widget primitives
package gui

import cl "loom:clay"
import "core:log"

LabelType :: enum {
    Title,
    Subtitle,
    Normal,
}

FontID :: enum u16 {
    Default,
    Title,
}

Flag :: enum {
    GrowX,
    GrowY,
    CenterX,
    CenterY,
    CenterChildX,
    CenterChildY,
}

CenterChild :: bit_set[Flag]{ .CenterChildX, .CenterChildY }
Center :: bit_set[Flag]{ .CenterX, .CenterY }
Grow :: bit_set[Flag]{ .GrowX, .GrowY }
Flags :: bit_set[Flag]

@(deferred_none = cl._CloseElement)
container :: proc (direction: cl.LayoutDirection, flags:=Flags{}, id:=cl.ElementId{}) -> bool {
    cl._OpenElement()

    cfg := cl.ElementDeclaration{
        id=id,
        layout = {
            layoutDirection = direction,
        },
        backgroundColor = COLOR_BACKGROUND,
    }

    if .GrowX in flags {
        cfg.layout.sizing.width = cl.SizingGrow({})
    }

    if .GrowY in flags {
        cfg.layout.sizing.height = cl.SizingGrow({})
    }

    if .CenterX in flags {
        cfg.layout.childAlignment.x = .Center
    }

    if .CenterY in flags {
        cfg.layout.childAlignment.y = .Center
    }

    cl.ConfigureOpenElement(cfg)

	return true
}

label :: proc {
    label_static,
    label_dynamic,
}

label_static :: proc ($text: string, type: LabelType) {
    cl.Text(text, cl.TextConfig(get_text_config_for_type(type)))
}

label_dynamic :: proc (text: string, type: LabelType) {
    cl.TextDynamic(text, cl.TextConfig(get_text_config_for_type(type)))
}

@(private)
get_text_config_for_type :: proc (type: LabelType) -> (cfg: cl.TextElementConfig) {
    cfg.textColor = COLOR_MAIN_TEXT

    switch type {
    case .Title:
        cfg.fontId = auto_cast FontID.Title
        cfg.fontSize = FONTSIZE_48
    case .Subtitle, .Normal:
        cfg.fontId = auto_cast FontID.Default
        cfg.fontSize = FONTSIZE_16
    }

    return
}

spacer :: proc (direction: cl.LayoutDirection, id:=cl.ElementId{}) {
    if cl.UI()({
        id=id,
        layout = {
            sizing = {
                width = direction == .LeftToRight ? cl.SizingGrow({}) : {},
                height = direction == .TopToBottom ? cl.SizingGrow({}) : {},
            },
            layoutDirection = direction,
        },
        backgroundColor = COLOR_BACKGROUND,
    }) {}
}

grid :: proc (elements: []$T, tile_size: cl.Dimensions, tile_layout: proc (element: ^T, index: u32), id: cl.ElementId, gap:=[2]f32{}) {
    if cl.UI()({
        id = id,
        layout = {
            sizing = {
                width = cl.SizingGrow({}),
                height = cl.SizingGrow({}),
            },
            childAlignment = {
                x = .Center,
                y = .Center,
            },
            childGap = u16(gap.y),
            layoutDirection = .TopToBottom,
        },
        clip = {
            vertical = true,
            childOffset = cl.GetScrollOffset(),
        },
    }) {
        grid_bb := cl.GetElementData(id).boundingBox
        available_w := int(grid_bb.width) - 1

        row_height: f32 = gap.y + tile_size.height
        start_row: int = int(abs(cl.GetScrollOffset().y) / row_height)
        visible_rows: int = int(grid_bb.height / row_height) + 2
        end_row := start_row + visible_rows

        n := int(max(f32(available_w + int(gap.x)) / (tile_size.width + gap.x), 1))
        total := len(elements)
        if n > total {
            n = total
        }
        rows := (total + n - 1) / n

        if grid_bb.height == 0 {
            start_row = 0
            end_row = rows
        }


        // 3 extra rows are added on each side to give time for covers
        // to load and stuff like that
        end_row_capped := min(rows, end_row + 3)
        start_row_capped := max(0, start_row - 3)

        if cl.UI()({
            layout = {
                sizing = {
                    width = cl.SizingFixed(f32(n * int(tile_size.width) + int(gap.x) * (n - 1))),
                    height = cl.SizingFixed(row_height * f32(start_row_capped)),
                }
            },
        }) {}

        for i in start_row_capped..<end_row_capped {
            if cl.UI()({
                layout = {
                    childGap = u16(gap.x),
                    sizing = {
                        width = cl.SizingFixed(f32(n * int(tile_size.width) + int(gap.x) * (n - 1))),
                    },
                },
            }) {
                for j in 0..<n {
                    index := i * n + j
                    if index >= total {
                        break
                    }

                    if cl.UI()({
                        layout = {
                            sizing = {
                                width = cl.SizingFixed(tile_size.width),
                                height = cl.SizingFixed(tile_size.height),
                            }
                        },
                    }) {
                        tile_layout(&elements[index], u32(index))
                    }
                }
            }
        }

        if cl.UI()({
            layout = {
                sizing = {
                    width = cl.SizingFixed(f32(n * int(tile_size.width) + int(gap.x) * (n - 1))),
                    height = cl.SizingFixed(row_height * f32(rows - end_row_capped)),
                }
            },
        }) {}
    }
}
