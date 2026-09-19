import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

void main() {
  ZSessionState fresh() => ZSessionState.initial(
    'abcdef'
        .split('')
        .map((id) => ZSessionItem(flashcardId: id, folderId: 'f'))
        .toList(),
    mode: ZReviewMode.learn,
  );
  String order(ZSessionState state) =>
      state.queue.map((i) => i.flashcardId).join();
  final policy = ZQueuePolicy(reinsertOffsetFor: (q) => q <= 1 ? 3 : 5);
  test('apprentissage réinsère les réussites sans créer de lapse SRS', () {
    expect(
      order(reduceGrade(fresh(), 1, passThreshold: 3, queuePolicy: policy)),
      'bcadef',
    );
    for (final q in [2, 3, 4]) {
      final state = reduceGrade(
        fresh(),
        q,
        passThreshold: 3,
        queuePolicy: policy,
      );
      expect(order(state), 'bcdeaf');
      expect(state.lapses, q < 3 ? 1 : 0);
      expect(state.reviewed, 0);
    }
    final complete = reduceGrade(
      fresh(),
      5,
      passThreshold: 3,
      queuePolicy: policy,
    );
    expect(order(complete), 'bcdef');
    expect(complete.reviewed, 1);
  });
  test('politique absente conserve les positions historiques', () {
    expect(order(reduceGrade(fresh(), 1, passThreshold: 3)), 'bacdef');
    expect(order(reduceGrade(fresh(), 2, passThreshold: 3)), 'bcdaef');
    expect(order(reduceGrade(fresh(), 3, passThreshold: 3)), 'bcdef');
  });
  test('offsets hors bornes restent dans la file', () {
    expect(
      order(
        reduceGrade(
          fresh(),
          1,
          passThreshold: 3,
          queuePolicy: ZQueuePolicy(reinsertOffsetFor: (_) => -20),
        ),
      ),
      'abcdef',
    );
    expect(
      order(
        reduceGrade(
          fresh(),
          1,
          passThreshold: 3,
          queuePolicy: ZQueuePolicy(reinsertOffsetFor: (_) => 200),
        ),
      ),
      'bcdefa',
    );
  });
}
