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
  tooDark,
  tooBright,
  tooFar,
  tooClose,
  noHandTimeout,
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
  static const double _secondPlaceFloor = 0.15;
  static const int _envBufferSize = 3; // ~300ms at 10fps
  static const int _envConsensusThreshold = 3;

  final List<String> _buffer = []; // '' sentinel = no hand that frame
  final List<String> _envBuffer = []; // 'dark'/'bright'/'far'/'close'/'none'
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
    required double secondConfidence,
    required String targetLetter,
    bool isTooDark = false,
    bool isTooBright = false,
    bool handTooClose = false,
    bool handTooFar = false,
    bool noHandTimeout = false,
  }) {
    if (targetLetter != _lastTarget) {
      _buffer.clear();
      _envBuffer.clear();
      _lastTarget = targetLetter;
      _lastResult = FeedbackResult.initial;
    }

    final bool noHand = topLabel.isEmpty || topConfidence == 0;

    // Environment checks run independent of (and before) the sign-label
    // consensus gate below — bad lighting/distance is exactly what causes
    // topLabel to bounce frame to frame, so gating on sign consensus first
    // would make this feature unreachable in the conditions it targets.
    if (!noHand) {
      final envResult = _evaluateEnvironment(isTooDark, isTooBright, handTooClose, handTooFar);
      if (envResult != null) {
        _lastResult = envResult;
        return envResult;
      }
    } else {
      _envBuffer.clear();
    }

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
      next = noHandTimeout
          ? const FeedbackResult(
              FeedbackState.noHandTimeout,
              'Show your hand to the camera',
            )
          : _lastResult;
    } else if (topLabel == targetLetter) {
      next = topConfidence >= _highConfidence
          ? FeedbackResult(
              FeedbackState.correct,
              "Perfect! That's $targetLetter!",
            )
          : const FeedbackResult(
              FeedbackState.correctHeld,
              'Hold still...',
            );
    } else if (secondLabel == targetLetter && secondConfidence >= _secondPlaceFloor) {
      next = FeedbackResult(
        FeedbackState.correct,
        "That's $targetLetter!",
      );
    } else if (topConfidence < _lowConfidence) {
      next = const FeedbackResult(
        FeedbackState.wrongUnclear,
        'Adjust your hand position',
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

  /// Debounces environment-condition flags over a small frame window so a
  /// single noisy frame doesn't flicker the message. Returns null when no
  /// condition applies or consensus hasn't been reached yet (caller should
  /// fall through to sign-correctness logic in that case).
  FeedbackResult? _evaluateEnvironment(
    bool isTooDark,
    bool isTooBright,
    bool handTooClose,
    bool handTooFar,
  ) {
    final candidate = isTooDark
        ? 'dark'
        : isTooBright
            ? 'bright'
            : handTooClose
                ? 'close'
                : handTooFar
                    ? 'far'
                    : 'none';

    _envBuffer.add(candidate);
    if (_envBuffer.length > _envBufferSize) _envBuffer.removeAt(0);
    if (_envBuffer.length < _envBufferSize ||
        _envBuffer.where((c) => c == candidate).length < _envConsensusThreshold) {
      return null;
    }

    switch (candidate) {
      case 'dark':
        return const FeedbackResult(FeedbackState.tooDark, "It's too dark, find better lighting");
      case 'bright':
        return const FeedbackResult(FeedbackState.tooBright, 'Too bright, reduce glare');
      case 'close':
        return const FeedbackResult(FeedbackState.tooClose, 'Move your hand a bit farther');
      case 'far':
        return const FeedbackResult(FeedbackState.tooFar, 'Move your hand closer');
      default:
        return null;
    }
  }

  /// Clears buffered state — call when leaving learn mode / disposing.
  void reset() {
    _buffer.clear();
    _envBuffer.clear();
    _lastTarget = null;
    _lastResult = FeedbackResult.initial;
  }
}
