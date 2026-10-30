import 'package:birdnet_live/features/inference/ort_session_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildOrtSessionOptions', () {
    test('always disables the KleidiAI kernels', () {
      final map = buildOrtSessionOptions().toMap();
      expect(map['sessionConfigs'], {'mlas.disable_kleidiai': '1'});
    });

    test('leaves threading and arena at runtime defaults when unset', () {
      final map = buildOrtSessionOptions().toMap();
      expect(map.keys, ['sessionConfigs']);
    });

    test('pins inter-op threads and arena when intra-op threads are set', () {
      final map = buildOrtSessionOptions(intraOpNumThreads: 3).toMap();
      expect(map['intraOpNumThreads'], 3);
      expect(map['interOpNumThreads'], 1);
      expect(map['useArena'], isTrue);
      expect(map['sessionConfigs'], {'mlas.disable_kleidiai': '1'});
    });
  });
}
