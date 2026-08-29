/// **Lot P2-D** — puce de matière (`ZSubjectChip`, câblée sur
/// `ZDefaultFolderCard`) et variante « passé » de la tuile d'examen
/// (`ZDefaultExamCard`).
///
/// Les deux capacités sont **additives** : la garde centrale de ce fichier est
/// l'INERTIE — sans matière déclarée, et sans horloge fournie, l'arbre rendu
/// est celui d'avant, à l'identique. Une capacité qui « ne change rien » n'est
/// démontrée que par une égalité, jamais par un `<=`.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart' show Left, Right;
import 'package:zcrud_core/zcrud_core.dart' show ZFailure;
import 'package:zcrud_exam/zcrud_exam.dart' show ZExam;
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZStudySubjectRef;

/// Échec neutre de test — le socle n'en fabrique aucun.
class _TestFailure extends ZFailure {
  const _TestFailure() : super('résolution indisponible');
}

Widget _host(Widget child, {double width = 320}) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: AlignmentDirectional.topStart,
          child: SizedBox(width: width, child: child),
        ),
      ),
    );

/// Signature d'arbre : la suite ORDONNÉE des types de widgets du sous-arbre.
/// Deux rendus « identiques » doivent donner deux listes ÉGALES — pas une
/// inclusion, pas un sur-ensemble.
List<String> _treeSignature(WidgetTester tester, Finder root) => tester
    .allWidgets
    .where(
      (Widget w) =>
          tester.any(find.byWidget(w)) &&
          find.descendant(of: root, matching: find.byWidget(w)).evaluate().isNotEmpty,
    )
    .map((Widget w) => w.runtimeType.toString())
    .toList(growable: false);

Directory _repoRoot() {
  Directory dir = Directory.current;
  while (!File('${dir.path}/melos.yaml').existsSync()) {
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      fail('melos.yaml introuvable en remontant depuis ${Directory.current}');
    }
    dir = parent;
  }
  return dir;
}

void main() {
  group('P2-D — ZSubjectChip : snapshot d\'abord, résolution ensuite', () {
    testWidgets('le libellé EMBARQUÉ s\'affiche SANS aucune résolution',
        (WidgetTester tester) async {
      int calls = 0;
      await tester.pumpWidget(
        _host(
          ZSubjectChip(
            ref: const ZStudySubjectRef(id: 's1', label: 'Droit douanier'),
            resolver: (String id) async {
              calls++;
              return const Right<ZFailure, ZStudySubjectRef>(
                ZStudySubjectRef(id: 's1', label: 'RÉSOLU'),
              );
            },
          ),
        ),
      );

      // AVANT toute résolution : le snapshot est déjà peint.
      expect(find.text('Droit douanier'), findsOneWidget);
      expect(find.text('RÉSOLU'), findsNothing);

      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('RÉSOLU'), findsOneWidget);
      expect(find.text('Droit douanier'), findsNothing);
    });

    testWidgets('sans résolveur : RIEN n\'est appelé, le snapshot fait foi',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const ZSubjectChip(
            ref: ZStudySubjectRef(id: 's1', label: 'Droit douanier'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Droit douanier'), findsOneWidget);
      expect(find.byKey(ZSubjectChip.chipKey), findsOneWidget);
    });

    testWidgets('`Left` ⇒ puce AU SNAPSHOT, aucune levée',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          ZSubjectChip(
            ref: const ZStudySubjectRef(id: 's1', label: 'Snapshot'),
            resolver: (String id) async =>
                const Left<ZFailure, ZStudySubjectRef>(_TestFailure()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Snapshot'), findsOneWidget);
    });

    testWidgets('`Left` SANS snapshot ⇒ puce ABSENTE, aucune levée',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          ZSubjectChip(
            ref: const ZStudySubjectRef(id: 's1'),
            resolver: (String id) async =>
                const Left<ZFailure, ZStudySubjectRef>(_TestFailure()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(ZSubjectChip.chipKey), findsNothing);
      expect(find.byKey(ZSubjectChip.labelKey), findsNothing);
    });

    testWidgets('un résolveur qui LÈVE ne casse pas le rendu (AD-10)',
        (WidgetTester tester) async {
      // MESURÉ pendant la campagne R3 : retirer le `try`/`catch` de la puce
      // fait ÉCHOUER ce test par l'exception qui s'échappe — c'est le rouge
      // attendu, la propriété défendue étant justement « rien ne s'échappe ».
      // Capturer l'erreur via `FlutterError.onError` pour la transformer en
      // `Expected:` a été essayé puis ABANDONNÉ : le harnais PEND alors au
      // lieu d'échouer (mesuré, deux runs à plus de 400 s).
      await tester.pumpWidget(
        _host(
          ZSubjectChip(
            ref: const ZStudySubjectRef(id: 's1', label: 'Snapshot'),
            resolver: (String id) async => throw StateError('port en panne'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Snapshot'), findsOneWidget);
    });

    testWidgets(
        'identifiant VIDE ⇒ aucune résolution tentée (rien à résoudre)',
        (WidgetTester tester) async {
      int calls = 0;
      await tester.pumpWidget(
        _host(
          ZSubjectChip(
            ref: const ZStudySubjectRef(id: '', label: 'Snapshot'),
            resolver: (String id) async {
              calls++;
              return const Right<ZFailure, ZStudySubjectRef>(
                ZStudySubjectRef(id: '', label: 'jamais'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.text('Snapshot'), findsOneWidget);
    });

    testWidgets(
        'la puce ne fabrique JAMAIS un libellé depuis l\'identifiant opaque',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(const ZSubjectChip(ref: ZStudySubjectRef(id: 'subject-42'))),
      );
      await tester.pumpAndSettle();
      expect(find.text('subject-42'), findsNothing);
      expect(find.byKey(ZSubjectChip.chipKey), findsNothing);
    });
  });

  group('P2-D — ZDefaultFolderCard : la puce est OPT-IN', () {
    testWidgets(
      'sans matière NI résolveur ⇒ arbre STRICTEMENT ÉGAL (inertie absolue)',
      (WidgetTester tester) async {
        const Widget marker = SizedBox(key: ValueKey<String>('extra'));

        await tester.pumpWidget(
          _host(
            const ZDefaultFolderCard(
              title: 'Dossier',
              subtitle: 'Matière',
              belowSubtitle: marker,
            ),
          ),
        );
        final List<String> reference =
            _treeSignature(tester, find.byType(ZDefaultFolderCard));

        // Les DEUX paramètres explicitement à `null` : le contrat dit que
        // c'est indistinguable de ne pas les passer.
        await tester.pumpWidget(
          _host(
            const ZDefaultFolderCard(
              title: 'Dossier',
              subtitle: 'Matière',
              belowSubtitle: marker,
              subjectRef: null,
              subjectLabelResolver: null,
            ),
          ),
        );
        final List<String> measured =
            _treeSignature(tester, find.byType(ZDefaultFolderCard));

        expect(measured, equals(reference));
        expect(measured, isNot(contains('ZSubjectChip')));
        expect(find.byType(ZSubjectChip), findsNothing);

        // CONTRE-PREUVE : avec une matière, l'arbre DIFFÈRE — la signature
        // n'est donc pas insensible.
        await tester.pumpWidget(
          _host(
            const ZDefaultFolderCard(
              title: 'Dossier',
              subtitle: 'Matière',
              belowSubtitle: marker,
              subjectRef: ZStudySubjectRef(id: 's1', label: 'Droit'),
            ),
          ),
        );
        final List<String> withSubject =
            _treeSignature(tester, find.byType(ZDefaultFolderCard));
        expect(withSubject, isNot(equals(reference)));
        expect(withSubject, contains('ZSubjectChip'));
      },
    );

    testWidgets('matière déclarée ⇒ snapshot affiché sur la carte',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const ZDefaultFolderCard(
            title: 'Dossier',
            subjectRef: ZStudySubjectRef(id: 's1', label: 'Droit douanier'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Droit douanier'), findsOneWidget);
    });

    testWidgets('résolveur ⇒ le libellé de la carte est MIS À JOUR',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          ZDefaultFolderCard(
            title: 'Dossier',
            subjectRef: const ZStudySubjectRef(id: 's1'),
            subjectLabelResolver: (String id) async =>
                Right<ZFailure, ZStudySubjectRef>(
              ZStudySubjectRef(id: id, label: 'Matière $id'),
            ),
          ),
        ),
      );

      expect(find.text('Matière s1'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('Matière s1'), findsOneWidget);
    });
  });

  group('P2-D — ZDefaultExamCard : variante « passé »', () {
    ZExam exam({DateTime? date}) =>
        ZExam(id: 'e1', folderId: 'f1', title: 'Examen', date: date);

    final DateTime now = DateTime.utc(2026, 6, 10, 9);

    testWidgets(
      'examen FUTUR ⇒ arbre STRICTEMENT ÉGAL à celui sans horloge',
      (WidgetTester tester) async {
        final ZExam future = exam(date: DateTime.utc(2026, 6, 20));

        await tester.pumpWidget(
          _host(ZDefaultExamCard(exam: future, dateLabel: '20/06')),
        );
        final List<String> reference =
            _treeSignature(tester, find.byType(ZDefaultExamCard));

        await tester.pumpWidget(
          _host(
            ZDefaultExamCard(
              exam: future,
              dateLabel: '20/06',
              now: now,
              pastLabel: 'Passé',
            ),
          ),
        );
        final List<String> measured =
            _treeSignature(tester, find.byType(ZDefaultExamCard));

        expect(measured, equals(reference));
        expect(find.byKey(ZDefaultExamCard.pastOverlayKey), findsNothing);
        expect(find.byKey(ZDefaultExamCard.pastChipKey), findsNothing);
        expect(find.text('Passé'), findsNothing);
      },
    );

    testWidgets('horloge ABSENTE ⇒ variante hors service, même sur un échu',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          ZDefaultExamCard(
            exam: exam(date: DateTime.utc(2020, 1, 1)),
            pastLabel: 'Passé',
          ),
        ),
      );
      expect(find.byKey(ZDefaultExamCard.pastOverlayKey), findsNothing);
      expect(find.text('Passé'), findsNothing);
    });

    testWidgets('examen ÉCHU ⇒ atténuation ET libellé injecté (AD-13)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          ZDefaultExamCard(
            exam: exam(date: DateTime.utc(2026, 6, 9)),
            dateLabel: '09/06',
            now: now,
            pastLabel: 'Passé',
          ),
        ),
      );

      expect(find.byKey(ZDefaultExamCard.pastOverlayKey), findsOneWidget);
      expect(
        tester
            .widget<Opacity>(find.byKey(ZDefaultExamCard.pastOverlayKey))
            .opacity,
        kZDefaultExamPastOpacity,
      );
      // L'état est dit EN TEXTE : la couleur/l'opacité n'est jamais seul canal.
      expect(find.byKey(ZDefaultExamCard.pastChipKey), findsOneWidget);
      expect(find.text('Passé'), findsOneWidget);
    });

    testWidgets('échu le JOUR MÊME ⇒ PAS passé (frontière figée)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          ZDefaultExamCard(
            exam: exam(date: DateTime.utc(2026, 6, 10, 23)),
            now: now,
            pastLabel: 'Passé',
          ),
        ),
      );
      expect(find.byKey(ZDefaultExamCard.pastOverlayKey), findsNothing);
      expect(find.text('Passé'), findsNothing);
    });

    testWidgets('échu SANS libellé ⇒ atténuation seule, aucune puce muette',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          ZDefaultExamCard(exam: exam(date: DateTime.utc(2026, 1, 1)), now: now),
        ),
      );
      expect(find.byKey(ZDefaultExamCard.pastOverlayKey), findsOneWidget);
      expect(find.byKey(ZDefaultExamCard.pastChipKey), findsNothing);
    });

    testWidgets('échu + rappels ⇒ les DEUX puces coexistent',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          ZDefaultExamCard(
            exam: ZExam(
              id: 'e1',
              folderId: 'f1',
              title: 'Examen',
              date: DateTime.utc(2026, 1, 1),
              reminderEnabled: true,
            ),
            now: now,
            pastLabel: 'Passé',
            reminderLabel: 'Rappels actifs',
          ),
        ),
      );
      expect(find.text('Passé'), findsOneWidget);
      expect(find.text('Rappels actifs'), findsOneWidget);
    });

    testWidgets('l\'annonce sémantique porte l\'état « passé »',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          ZDefaultExamCard(
            exam: exam(date: DateTime.utc(2026, 1, 1)),
            dateLabel: '01/01',
            now: now,
            pastLabel: 'Passé',
          ),
        ),
      );
      expect(
        find.bySemanticsLabel(RegExp(r'Examen, 01/01, Passé')),
        findsOneWidget,
      );
    });
  });

  group('P2-D — gardes de SOURCE (FR-26 / AD-13)', () {
    for (final String relative in <String>[
      'lib/src/presentation/z_subject_chip.dart',
      'lib/src/presentation/z_default_exam_card.dart',
    ]) {
      test('$relative : aucune couleur en dur, chrome directionnel', () {
        final File source =
            File('${_repoRoot().path}/packages/zcrud_study/$relative');
        expect(source.existsSync(), isTrue, reason: source.path);
        final String body = source
            .readAsStringSync()
            .split('\n')
            .where((String l) => !l.trimLeft().startsWith('///'))
            .join('\n');

        expect(body, isNot(contains('Colors.')));
        expect(body, isNot(contains('Color(0x')));
        expect(body, isNot(contains('EdgeInsets.only(left')));
        expect(body, isNot(contains('EdgeInsets.only(right')));
        expect(body, isNot(contains('Alignment.centerLeft')));
        expect(body, isNot(contains('Alignment.centerRight')));
        expect(body, isNot(contains('TextAlign.left')));
        expect(body, isNot(contains('TextAlign.right')));
        // Aucune horloge implicite : l'instant est TOUJOURS un paramètre.
        expect(body, isNot(contains('DateTime.now')));
      });
    }

    test('la tuile d\'examen DÉLÈGUE la règle de date à `ZExam.isPast`', () {
      final File source = File(
        '${_repoRoot().path}/packages/zcrud_study/lib/src/presentation/'
        'z_default_exam_card.dart',
      );
      final String body = source
          .readAsStringSync()
          .split('\n')
          .where((String l) => !l.trimLeft().startsWith('///'))
          .join('\n');

      expect(body, contains('exam.isPast('));
      // Aucune seconde règle de date écrite ici.
      expect(body, isNot(contains('.difference(')));
      expect(body, isNot(contains('isBefore(')));
      expect(body, isNot(contains('daysUntil(')));
    });
  });
}
