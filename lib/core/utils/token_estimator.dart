class TokenEstimator {
  // Rough heuristic only when provider does not return usage/context metrics.
  // ~4 chars/token for mixed text/code; not exact.
  static int estimate(String text) =>
      text.isEmpty ? 0 : estimateLength(text.length);

  /// Same heuristic without materialising/joining the text, which keeps the
  /// token meter cheap while the user types.
  static int estimateLength(int length) =>
      length <= 0 ? 0 : (length / 4).ceil();
}
