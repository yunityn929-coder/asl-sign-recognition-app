import 'package:flutter_test/flutter_test.dart';
import 'package:hiasl/controllers/recognition_controller.dart';

void main() {
  test('computeEngineeredFeatures matches hand-computed values for colinear landmarks', () {
    // 21 landmarks placed at (i, 0, 0) for landmark index i = 0..20, so every
    // finger's joint-to-joint vectors are parallel (curl angle = 0), and
    // fingertip/palm-center distances reduce to simple 1-D differences we
    // can verify by hand.
    final landmarks = List<double>.generate(63, (i) {
      final landmarkIndex = i ~/ 3;
      final axis = i % 3;
      return axis == 0 ? landmarkIndex.toDouble() : 0.0;
    });

    final features = computeEngineeredFeatures(landmarks);

    expect(features.length, 17);

    // 10 curl angles (2 joint-angle pairs x 5 fingers) — all colinear, so
    // ~0. Not exactly 0: _angleBetween adds a 1e-8 epsilon to the
    // denominator before acos(), so perfectly parallel unit vectors give
    // acos(1/(1+1e-8)) ≈ 1.4142e-4 rad, not 0. Tolerance covers that.
    for (var i = 0; i < 10; i++) {
      expect(features[i], closeTo(0.0, 2e-4));
    }

    // Palm center = average of landmarks 5, 9, 13, 17 = (11, 0, 0).
    // Fingertip distances from palm center for tips 4, 8, 12, 16, 20:
    // |4-11|=7, |8-11|=3, |12-11|=1, |16-11|=5, |20-11|=9.
    expect(features.sublist(10, 15), [7.0, 3.0, 1.0, 5.0, 9.0]);

    // Thumb tip (4) to index tip (8) = 4; thumb tip (4) to middle tip (12) = 8.
    expect(features[15], 4.0);
    expect(features[16], 8.0);
  });
}
