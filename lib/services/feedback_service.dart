/// Classifies live MLP predictions into a stable, user-facing feedback
/// state while the learner is holding a sign in front of the camera.
///
/// Wraps two concerns:
///  1. Thresholding topLabel/topConfidence against the target letter.
///  2. Debouncing — a 5-frame rolling window requires 4/5 agreement on the
///     current frame's topLabel before a new state is emitted, so a single
///     noisy frame doesn't flip the UI. Until consensus is reached, the
///     previously emitted state is held.
library;

enum FeedbackState {
  noHand,
  correctHeld,
  correct,
  wrongClear,
  wrongUnclear,
}

class FeedbackResult {
  final FeedbackState state;
  final String message;

  const FeedbackResult(this.state, this.message);

  static const FeedbackResult initial = FeedbackResult(
    FeedbackState.noHand,
    'Show your hand to the camera',
  );
}

class FeedbackService {
  static const int _bufferSize = 5;
  static const int _consensusThreshold = 4;
  static const double _highConfidence = 0.85; // matches kRecognitionConfidenceThreshold
  static const double _lowConfidence = 0.60;

  final List<String> _buffer = []; // '' sentinel = no hand that frame
  String? _lastTarget;
  FeedbackResult _lastResult = FeedbackResult.initial;

  /// Evaluate one frame's prediction against [targetLetter].
  ///
  /// [topLabel]/[topConfidence] should be the ungated raw prediction
  /// (RecognitionResult.topLabel/topConfidence), not the 0.85-gated
  /// label/confidence — this service needs the full 0.60+ range itself.
  FeedbackResult evaluate({
    required String topLabel,
    required double topConfidence,
    required String secondLabel,
    required String targetLetter,
  }) {
    if (targetLetter != _lastTarget) {
      _buffer.clear();
      _lastTarget = targetLetter;
      _lastResult = FeedbackResult.initial;
    }

    final bool noHand = topLabel.isEmpty || topConfidence == 0;
    final currentLabel = noHand ? '' : topLabel;

    _buffer.add(currentLabel);
    if (_buffer.length > _bufferSize) {
      _buffer.removeAt(0);
    }

    final agreement = _buffer.where((l) => l == currentLabel).length;
    if (agreement < _consensusThreshold) {
      // Not enough consensus yet this window — avoid flicker, hold last state.
      return _lastResult;
    }

    final FeedbackResult next;
    if (noHand) {
      next = FeedbackResult.initial;
    } else if (topConfidence < _lowConfidence) {
      next = const FeedbackResult(
        FeedbackState.wrongUnclear,
        'Adjust your hand position',
      );
    } else if (topLabel == targetLetter) {
      next = topConfidence >= _highConfidence
          ? FeedbackResult(
              FeedbackState.correct,
              "✓ Perfect! That's $targetLetter!",
            )
          : const FeedbackResult(
              FeedbackState.correctHeld,
              'Hold still...',
            );
    } else {
      next = FeedbackResult(
        FeedbackState.wrongClear,
        'This looks like $topLabel, not $targetLetter',
      );
    }

    _lastResult = next;
    return next;
  }

  /// Clears buffered state — call when leaving learn mode / disposing.
  void reset() {
    _buffer.clear();
    _lastTarget = null;
    _lastResult = FeedbackResult.initial;
  }
}
