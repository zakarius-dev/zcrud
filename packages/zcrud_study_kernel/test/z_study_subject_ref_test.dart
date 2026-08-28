import 'dart:convert';

import 'package:test/test.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

void main() {
  test('round-trip Map JSON strict, snake_case et optionnels null omis', () {
    const subject = ZStudySubjectRef(
      id: 'subject-1',
      label: 'Mathématiques',
      colorKey: 'indigo',
    );

    final map = subject.toMap();
    expect(
      map,
      equals(<String, dynamic>{
        'id': 'subject-1',
        'label': 'Mathématiques',
        'color_key': 'indigo',
      }),
    );

    final jsonMap = jsonDecode(jsonEncode(map)) as Map<String, dynamic>;
    expect(ZStudySubjectRef.fromMap(jsonMap), equals(subject));
    expect(
      const ZStudySubjectRef(id: 'subject-2').toMap(),
      equals(<String, dynamic>{'id': 'subject-2'}),
    );
  });

  test('décodage défensif des types invalides sans exception', () {
    final subject = ZStudySubjectRef.fromMap(<String, dynamic>{
      'id': 42,
      'label': true,
      'color_key': <String>['indigo'],
    });

    expect(subject.id, isEmpty);
    expect(subject.label, isNull);
    expect(subject.colorKey, isNull);
    expect(subject.toMap(), equals(<String, dynamic>{'id': ''}));
  });

  test(
    'égalité structurelle, hashCode cohérent et différence discriminante',
    () {
      const first = ZStudySubjectRef(
        id: 'subject-1',
        label: 'Mathématiques',
        colorKey: 'indigo',
      );
      const same = ZStudySubjectRef(
        id: 'subject-1',
        label: 'Mathématiques',
        colorKey: 'indigo',
      );
      const different = ZStudySubjectRef(
        id: 'subject-1',
        label: 'Mathématiques',
        colorKey: 'amber',
      );

      expect(first, equals(same));
      expect(first.hashCode, equals(same.hashCode));
      expect(first, isNot(equals(different)));
    },
  );
}
