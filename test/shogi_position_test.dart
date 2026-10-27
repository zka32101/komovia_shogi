import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/src/logic.dart';
import 'package:komovia_shogi/src/shogi_position.dart';

void main() {
  group('ShogiPosition.copyWith', () {
    ShogiPosition basePosition({Side? resignedBy}) {
      return ShogiPosition(
        board: GL.initialBoard(),
        p1Hand: const {},
        p2Hand: const {},
        sideToMove: Side.first,
        resignedBy: resignedBy,
      );
    }

    test('an explicit resignedBy: null clears a previously-set resignation',
        () {
      final resigned = basePosition(resignedBy: Side.first);

      final cleared = resigned.copyWith(resignedBy: null);

      expect(cleared.resignedBy, isNull);
    });

    test('omitting resignedBy preserves the existing value unchanged', () {
      final resigned = basePosition(resignedBy: Side.second);

      final copy = resigned.copyWith(sideToMove: Side.first);

      expect(copy.resignedBy, Side.second);
    });

    test('passing a non-null resignedBy sets it, regardless of the prior '
        'value', () {
      final position = basePosition();

      final resigned = position.copyWith(resignedBy: Side.first);

      expect(resigned.resignedBy, Side.first);
    });
  });
}
