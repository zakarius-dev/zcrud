// Verrou de SOURCE FR-26 — aucun nom de jour de semaine n'est écrit en dur
// dans `z_exam_editor.dart`. Les libellés de jour viennent soit du labeler
// INJECTÉ (`ZExamWeekdayLabeler`), soit du repli LOCALISÉ
// `MaterialLocalizations.narrowWeekdays` — jamais d'un littéral du paquet.
//
// Le scan porte sur les LITTÉRAUX DE CHAÎNE, pas sur le texte brut : c'est la
// propriété exacte. `DateTime.sunday` / `DateTime.tuesday` sont des CONSTANTES
// SYMBOLIQUES de la plateforme et doivent rester permises — un scan naïf du
// texte les confondrait avec un libellé et forcerait à écrire des `1`/`7` nus,
// moins lisibles et plus faciles à inverser.
//
// Les commentaires sont DÉPOUILLÉS avant le scan : la dartdoc de ce widget
// écrit littéralement « 1 = lundi … 7 = dimanche » pour documenter la
// convention ISO, et doit pouvoir continuer de le faire.
//
// Injection R3 attendue : remplacer le repli localisé par une table de noms
// en dur ⇒ RC=1 par assertion.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/z_sources.dart';

/// Fichier sous verrou.
const String _editorPath = 'lib/src/presentation/z_exam_editor.dart';

/// Noms de jour BANNIS comme littéraux (français + anglais, casse ignorée).
final RegExp _weekdayName = RegExp(
  r'\b(lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche|'
  r'monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
  caseSensitive: false,
);

/// Littéraux de chaîne simples (`'…'` / `"…"`), échappements `\'` tolérés.
///
/// Suffisant ici : ce fichier n'utilise ni chaîne brute `r'…'` ni triple
/// guillemet. Le test de POUVOIR ci-dessous le vérifie plutôt que de le
/// supposer.
final RegExp _stringLiteral = RegExp(
  r"'((?:\\.|[^'\\])*)'" r'|"((?:\\.|[^"\\])*)"',
);

Iterable<String> _literalsOf(String strippedSource) sync* {
  for (final m in _stringLiteral.allMatches(strippedSource)) {
    yield m.group(1) ?? m.group(2) ?? '';
  }
}

void main() {
  group('FR-26 — aucun nom de jour en dur dans l\'éditeur d\'examen', () {
    test('les littéraux de `z_exam_editor.dart` ne nomment aucun jour', () {
      final src = strippedOf(_editorPath);
      final coupables = <String>[
        for (final lit in _literalsOf(src))
          if (_weekdayName.hasMatch(lit)) lit,
      ];
      expect(
        coupables,
        isEmpty,
        reason: 'FR-26 : les libellés de jour viennent de '
            '`ZExamWeekdayLabeler` ou de `MaterialLocalizations.narrowWeekdays`. '
            'Littéraux fautifs : $coupables',
      );
    });

    test('le fichier sous verrou existe et a bien été scanné (jamais vacant)',
        () {
      // 🔴 Un verrou qui scanne un chemin disparu est VERT et VIDE. On mesure
      // donc que le scan a vu du contenu, et du contenu de CE widget.
      expect(File(_editorPath).existsSync(), isTrue);
      final src = strippedOf(_editorPath);
      expect(src, contains('class ZExamEditor'));
      expect(src, contains('narrowWeekdays'));
      expect(_literalsOf(src).length, greaterThan(10));
    });

    test('R2 — le filet a du POUVOIR (mord sur interdit, épargne autorisé)',
        () {
      // Mord sur un libellé en dur, dans les deux langues.
      expect(
        _literalsOf("const d = 'Mardi';").any(_weekdayName.hasMatch),
        isTrue,
      );
      expect(
        _literalsOf('const d = "Tuesday";').any(_weekdayName.hasMatch),
        isTrue,
      );
      // ÉPARGNE la constante symbolique de la plateforme : elle n'est pas
      // dans un littéral, donc elle n'est jamais soumise au motif.
      expect(
        _literalsOf('final iso = DateTime.sunday;').any(_weekdayName.hasMatch),
        isFalse,
      );
      // ÉPARGNE un libellé de section légitime.
      expect(
        _literalsOf("this.weeklyRemindersLabel = 'Rappels hebdomadaires',")
            .any(_weekdayName.hasMatch),
        isFalse,
      );
      // L'extracteur voit bien le CONTENU, pas les guillemets.
      expect(_literalsOf("a('x', \"y\")").toList(), <String>['x', 'y']);
    });
  });
}
