/// Direction where the sheet anchors from the screen edge.
enum SheetDirection {
  left,
  right,
  top,
  bottom,
}

extension SheetDirectionX on SheetDirection {
  bool get isHorizontal => this == SheetDirection.left || this == SheetDirection.right;
  bool get isVertical => this == SheetDirection.top || this == SheetDirection.bottom;
}