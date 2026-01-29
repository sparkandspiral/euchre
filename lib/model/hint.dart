class HintSuggestion {
  final String message;
  final String? detail;

  /// Optional visual anchors used to highlight a move path.
  /// Keys are looked up by the game when drawing the overlay.
  final String? fromTarget;
  final String? toTarget;
  final List<String> highlightTargets;

  /// How long the visual hint should stay on screen.
  final Duration displayDuration;

  const HintSuggestion({
    required this.message,
    this.detail,
    this.fromTarget,
    this.toTarget,
    this.highlightTargets = const [],
    this.displayDuration = const Duration(seconds: 2),
  });
}

const int defaultHintCount = 10;
const int hintRewardAmount = 10;
