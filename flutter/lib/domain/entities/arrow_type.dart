/// Represents the arrow direction on a connector.
enum ArrowType {
  /// No arrows on either end.
  none,

  /// Arrow on the start (source) end only.
  start,

  /// Arrow on the end (target) only.
  end,

  /// Arrows on both ends (bidirectional).
  both,
}
