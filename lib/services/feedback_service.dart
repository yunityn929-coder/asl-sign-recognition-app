// Classifies live MLP predictions into a stable feedback state while the
// learner holds a sign. A 5-frame window needs 4/5 agreement before the
// state changes, so one noisy frame doesn't flip the UI.
library;

import '../models/recognition_result.dart';

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
  static const int _envBufferSize = 3; // ~300ms at 10fps
  static const int _envConsensusThreshold = 3;

  final List<String> _buffer = []; // '' sentinel = no hand that frame
  final List<String> _envBuffer = []; // 'dark'/'bright'/'far'/'close'/'none'
  String? _lastTarget;
  FeedbackResult _lastResult = FeedbackResult.initial;

  bool _matchesTarget(String predictedLabel, String targetLetter) {
    return predictedLabel == targetLetter;
  }

  // result.topLabel/topConfidence should be the ungated raw prediction, not
  // the 0.85-gated label/confidence — this needs the full 0.60+ range.
  FeedbackResult evaluate({
    required RecognitionResult result,
    required String targetLetter,
  }) {
    final String topLabel = result.topLabel;
    final double topConfidence = result.topConfidence;
    final bool isTooDark = result.isTooDark;
    final bool isTooBright = result.isTooBright;
    final bool handTooClose = result.handTooClose;
    final bool handTooFar = result.handTooFar;
    final bool noHandTimeout = result.noHandTimeout;

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
    } else if (_matchesTarget(topLabel, targetLetter)) {
      next = topConfidence >= _highConfidence
          ? FeedbackResult(
              FeedbackState.correct,
              "Perfect! That's $targetLetter!",
            )
          : const FeedbackResult(
              FeedbackState.correctHeld,
              'Hold still...',
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

  // Debounces environment flags over a small window so one noisy frame
  // doesn't flicker the message. Null means no condition applies yet, or
  // consensus isn't reached — caller should fall through to sign-correctness.
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

  // Call when leaving learn mode / disposing.
  void reset() {
    _buffer.clear();
    _envBuffer.clear();
    _lastTarget = null;
    _lastResult = FeedbackResult.initial;
  }
}
