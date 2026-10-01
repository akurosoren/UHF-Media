class IntSize {
  const IntSize(this.width, this.height);
  final int width;
  final int height;

  @override
  bool operator ==(Object other) => other is IntSize && other.width == width && other.height == height;
  @override
  int get hashCode => Object.hash(width, height);
  @override
  String toString() => 'IntSize($width, $height)';
}

class IntRect {
  const IntRect(this.x, this.y, this.width, this.height);
  final int x;
  final int y;
  final int width;
  final int height;

  @override
  bool operator ==(Object other) =>
      other is IntRect && other.x == x && other.y == y && other.width == width && other.height == height;
  @override
  int get hashCode => Object.hash(x, y, width, height);
  @override
  String toString() => 'IntRect($x, $y, $width, $height)';
}

/// A rectangle in logical pixels (viewport space).
class DRect {
  const DRect(this.left, this.top, this.width, this.height);
  final double left;
  final double top;
  final double width;
  final double height;

  @override
  bool operator ==(Object other) =>
      other is DRect && other.left == left && other.top == top && other.width == width && other.height == height;
  @override
  int get hashCode => Object.hash(left, top, width, height);
  @override
  String toString() => 'DRect($left, $top, $width, $height)';
}

/// A rectangle expressed as fractions (0..1) of the displayed picture.
class RatioRect {
  const RatioRect(this.left, this.top, this.width, this.height);
  final double left;
  final double top;
  final double width;
  final double height;

  @override
  bool operator ==(Object other) =>
      other is RatioRect && other.left == left && other.top == top && other.width == width && other.height == height;
  @override
  int get hashCode => Object.hash(left, top, width, height);
  @override
  String toString() => 'RatioRect($left, $top, $width, $height)';
}
