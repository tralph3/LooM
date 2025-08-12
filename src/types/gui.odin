package types

UIAction :: enum {
    Ok,
    Cancel,
    Back,
    Left,
    Right,
    Up,
    Down,
    Next,
    Previous,
}

GUIInputState :: bit_set[UIAction]
