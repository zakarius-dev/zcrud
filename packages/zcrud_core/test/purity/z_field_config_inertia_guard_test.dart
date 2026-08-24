// CR-IFFD-99 — GARDE D'INERTIE des configurations de champ.
//
// Le défaut visé : une option publique, documentée, INERTE (déclarée dans une
// `Z*Config` de `z_field_config.dart` mais lue par AUCUN site de
// `presentation/`). L'hôte la pose, la croit active, et rien ne rougit — c'est
// exactement l'histoire de `keyboardType` (CR-93) et de `minValueKey`/
// `maxValueKey` (CR-98). Cette garde fait rougir l'AJOUT d'une option morte.
//
// Règle : chaque propriété `final` publique de chaque config est
// - lue par au moins un site de `lib/src/presentation/` (motif `.<nom>`), OU
// - inscrite dans la liste nominative « domaine pur » ci-dessous, chaque
//   entrée étant JUSTIFIÉE par un commentaire « Domaine pur » au point de
//   déclaration (vérifié par la garde).
//
// 🔴 Les listes sont LUES DANS LA SOURCE, jamais recopiées ; le code est
// STRIPPÉ de ses commentaires avant analyse (discipline des gardes du dépôt).
//
// Limite assumée : le motif `.<nom>` est textuel — un nom très générique
// (`min`, `style`) peut être « vivant » par homonymie. La garde vise l'option
// morte AJOUTÉE (nom neuf, donc discriminant), pas un audit d'usage exhaustif.
import 'package:flutter_test/flutter_test.dart';

import '../support/z_sources.dart' as sources;

/// Liste nominative « domaine pur » : propriétés dont l'absence de lecture par
/// `presentation/` est un CHOIX, justifié au point de déclaration.
///
/// Après CR-93/CR-98, chaque entrée restante est un choix, pas un oubli — la
/// garde exige le commentaire « Domaine pur » à la déclaration ET borne la
/// taille de cette liste (une liste qui s'allonge est le symptôme même que la
/// garde combat).
const Map<String, String> _domainPure = <String, String>{
  // Prédicat unique `showsStateLabel` : la présentation ne lit jamais le
  // drapeau brut, elle lit le prédicat qui le combine aux libellés.
  'ZBooleanConfig.showStateLabel': 'lue au travers de showsStateLabel',
  // Contrat du seam `ZFilePicker` : la config est transmise INTÉGRALEMENT au
  // picker hôte, qui applique ces contraintes (le cœur n'acquiert rien).
  'FileFieldConfig.acceptedExtensions': 'contrat du seam ZFilePicker',
  'FileFieldConfig.acceptedMimeTypes': 'contrat du seam ZFilePicker',
  'FileFieldConfig.maxSizeBytes': 'contrat du seam ZFilePicker',
  'FileFieldConfig.allowedDocumentTypes':
      'consommée via effectiveExtensions (contrat ZFilePicker)',
  // Amplitudes de plage : la présentation ne lit que les dérivés qui portent
  // la règle d'ignorance des valeurs invalides.
  'ZDateConfig.maxDays': 'lue au travers de effectiveMaxDays/checkSpanDays',
  'ZDateConfig.minDays': 'lue au travers de effectiveMinDays/checkSpanDays',
};

void main() {
  test('🔴 INERTIE : toute propriété publique d\'une `Z*Config` est lue par '
      '`presentation/`, ou nominativement « domaine pur » justifiée', () {
    final file = sources.libFile('domain/edition/z_field_config.dart');
    final String raw = file.readAsStringSync();
    final String stripped = sources.strippedSource(file);

    // ── 1. Les classes de config et leurs propriétés `final` publiques ──────
    final classMatches =
        RegExp(r'class (\w+) extends ZFieldConfig').allMatches(stripped).toList();
    expect(classMatches.length, greaterThanOrEqualTo(8),
        reason: 'trop peu de configs trouvées — parsing probablement cassé');

    final props = <String>[]; // 'Classe.prop'
    for (var i = 0; i < classMatches.length; i++) {
      final name = classMatches[i].group(1)!;
      final start = classMatches[i].start;
      final end = i + 1 < classMatches.length
          ? classMatches[i + 1].start
          : stripped.length;
      final body = stripped.substring(start, end);
      for (final m in RegExp(r'^\s{2}final\s+.+?\s(\w+);', multiLine: true)
          .allMatches(body)) {
        final prop = m.group(1)!;
        if (!prop.startsWith('_')) props.add('$name.$prop');
      }
    }
    expect(props.length, greaterThanOrEqualTo(30),
        reason: 'trop peu de propriétés lues — parsing probablement cassé');

    // ── 2. Le corpus `presentation/` strippé ────────────────────────────────
    final presentation = sources
        .libDartFiles()
        .where((f) => f.path.replaceAll(r'\', '/').contains('/presentation/'))
        .map(sources.strippedSource)
        .join('\n');
    expect(presentation.length, greaterThan(10000),
        reason: 'corpus presentation vide — garde VACUELLE');

    // ── 3. Verdict ──────────────────────────────────────────────────────────
    final dead = <String>[];
    for (final qualified in props) {
      final prop = qualified.split('.').last;
      final alive = RegExp('\\.$prop\\b').hasMatch(presentation);
      if (alive) continue;
      if (_domainPure.containsKey(qualified)) continue;
      dead.add(qualified);
    }
    expect(
      dead,
      isEmpty,
      reason: '🔴 OPTION(S) MORTE(S) : $dead — déclarée(s) dans une config '
          'publique mais lue(s) par AUCUN site de presentation/. Câblez la '
          'lecture, ou inscrivez l\'entrée dans la liste « domaine pur » de '
          'cette garde AVEC un commentaire « Domaine pur : … » au point de '
          'déclaration.',
    );

    // ── 4. Chaque exemption existe encore ET porte sa justification ─────────
    for (final entry in _domainPure.entries) {
      final prop = entry.key.split('.').last;
      final decl = RegExp('final[^;\\n]*\\b$prop;').firstMatch(raw);
      expect(decl, isNotNull,
          reason: 'exemption périmée : ${entry.key} n\'existe plus — '
              'retirez-la de la liste');
      final before =
          raw.substring(decl!.start < 500 ? 0 : decl.start - 500, decl.start);
      expect(before.contains('Domaine pur'), isTrue,
          reason: '${entry.key} est exemptée mais sa déclaration ne porte pas '
              'le commentaire « Domaine pur : … » — la justification doit '
              'vivre AU POINT DE DÉCLARATION');
    }

    // ── 5. La liste d'exemptions reste COURTE ───────────────────────────────
    expect(_domainPure.length, lessThanOrEqualTo(8),
        reason: 'la liste « domaine pur » s\'allonge — c\'est le symptôme que '
            'cette garde combat : câblez les lectures au lieu d\'exempter');
  });
}
