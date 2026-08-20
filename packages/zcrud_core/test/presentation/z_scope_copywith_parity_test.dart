// Garde de PARITÉ entre les seams déclarés de `ZcrudScope` et les paramètres
// de `copyWith` / `derive`.
//
// 🔴 MOTIF — le défaut visé est la « dette du seam suivant » : un hôte qui
// dérive un scope par `copyWith` compte sur le paquet pour hériter TOUS les
// seams non nommés. Le jour où un nouveau seam est déclaré sur le widget sans
// être ajouté à `copyWith`/`derive`, tout scope dérivé le PERD silencieusement
// (paramètres nommés optionnels : pas d'erreur de compilation, pas d'échec de
// test — la couture redevient simplement nulle). Cette garde fait rougir cet
// oubli PAR ASSERTION.
//
// 🔴 La liste des seams est LUE DANS LA SOURCE (constructeur `this.…`), jamais
// recopiée ici : une liste recopiée dériverait avec le fichier qu'elle prétend
// garder (même discipline que `z_scope_notify_parity_test.dart`).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/z_sources.dart' as sources;

/// Remonte jusqu'au dossier portant `melos.yaml` (racine du workspace).
///
/// Ancrage ROBUSTE : `flutter test` se lance depuis le dossier du paquet, et
/// un `../` relatif casserait si l'arborescence bougeait.
Directory _repoRoot() => sources.repoRoot();

/// Source de `zcrud_scope.dart`, STRIPPÉE de ses commentaires (une prose de
/// dartdoc citant un nom de seam ou un `;` ne doit jamais dévier la garde).
String _scopeSource() {
  final File source = File(
    '${_repoRoot().path}/packages/zcrud_core/lib/src/presentation/'
    'zcrud_scope.dart',
  );
  expect(source.existsSync(), isTrue, reason: 'source introuvable');
  return sources.strippedSource(source);
}

/// Les seams DÉCLARÉS, lus dans le constructeur (`this.<nom>`).
Set<String> _declaredSeams(String src) {
  final int ctorStart = src.indexOf('const ZcrudScope({');
  expect(ctorStart, greaterThan(-1), reason: 'constructeur introuvable');
  final int ctorEnd = src.indexOf('});', ctorStart);
  expect(ctorEnd, greaterThan(ctorStart), reason: 'constructeur non borné');
  final String ctor = src.substring(ctorStart, ctorEnd);

  final Set<String> declared = RegExp(r'this\.([a-zA-Z0-9_]+)')
      .allMatches(ctor)
      .map((m) => m.group(1)!)
      .toSet();

  // Anti-vacuité : sans cette borne, un constructeur illisible rendrait un
  // ensemble VIDE et la garde passerait en n'observant rien.
  expect(declared.length, greaterThanOrEqualTo(15),
      reason: 'trop peu de paramètres lus — le parsing a probablement échoué');
  return declared;
}

/// Les noms de paramètres d'une signature `({ ... })` déjà découpée.
///
/// Un paramètre est un identifiant suivi de `,` ou de `= <défaut>,` — jamais
/// un nom de type (toujours suivi d'un autre identifiant ou de `?`), jamais la
/// sentinelle (consommée avec son paramètre par la même correspondance).
Set<String> _paramNames(String paramBlock) =>
    RegExp(r'([a-zA-Z0-9_]+)\s*(?:=\s*[a-zA-Z0-9_]+)?\s*,')
        .allMatches(paramBlock)
        .map((m) => m.group(1)!)
        .toSet();

void main() {
  // `child` et `key` ne sont pas des seams : ce sont les paramètres de widget
  // (sous-arbre enveloppé, identité d'arbre) — présents dans les signatures
  // mais hors du contrat d'héritage.
  const Set<String> nonSeams = <String>{'child', 'key'};

  test('🔴 STRUCTURE : chaque seam de `ZcrudScope` est un paramètre de '
      '`copyWith` ET est hérité par son corps', () {
    final String src = _scopeSource();
    final Set<String> declared = _declaredSeams(src);

    final int start = src.indexOf('ZcrudScope copyWith({');
    expect(start, greaterThan(-1), reason: '`copyWith` introuvable');
    final int paramsEnd = src.indexOf('})', start);
    expect(paramsEnd, greaterThan(start), reason: '`copyWith` non borné');
    final int bodyEnd = src.indexOf(';', paramsEnd);
    expect(bodyEnd, greaterThan(paramsEnd),
        reason: 'corps de `copyWith` non borné');

    final Set<String> params =
        _paramNames(src.substring(start, paramsEnd)).difference(nonSeams);
    final String body = src.substring(paramsEnd, bodyEnd);

    final Set<String> missingParams = declared.difference(params);
    expect(
      missingParams,
      isEmpty,
      reason: '🔴 ${missingParams.join(', ')} déclaré(s) sur `ZcrudScope` mais '
          'ABSENT(s) de la signature de `copyWith` : tout scope dérivé perdrait '
          'ce(s) seam(s) silencieusement (paramètres nommés optionnels — rien '
          'ne compile en rouge). Ajoutez le paramètre à `copyWith` ET à '
          '`derive`, avec héritage de `this.<seam>`.',
    );

    final Set<String> notInherited = declared
        .where((String s) => !body.contains('this.$s'))
        .toSet();
    expect(
      notInherited,
      isEmpty,
      reason: '🔴 ${notInherited.join(', ')} accepté(s) par `copyWith` mais '
          'JAMAIS hérité(s) dans son corps (`this.<seam>` absent) : un '
          'paramètre omis ne préserverait pas la valeur du scope courant.',
    );
  });

  test('🔴 STRUCTURE : chaque seam de `ZcrudScope` est un paramètre de '
      '`derive` ET est transmis à `copyWith`', () {
    final String src = _scopeSource();
    final Set<String> declared = _declaredSeams(src);

    final int start = src.indexOf('static ZcrudScope derive(');
    expect(start, greaterThan(-1), reason: '`derive` introuvable');
    final int paramsEnd = src.indexOf('})', start);
    expect(paramsEnd, greaterThan(start), reason: '`derive` non borné');
    final int bodyEnd = src.indexOf('\n  }', paramsEnd);
    expect(bodyEnd, greaterThan(paramsEnd),
        reason: 'corps de `derive` non borné');

    final Set<String> params =
        _paramNames(src.substring(start, paramsEnd)).difference(nonSeams);
    final String body = src.substring(paramsEnd, bodyEnd);

    final Set<String> missingParams = declared.difference(params);
    expect(
      missingParams,
      isEmpty,
      reason: '🔴 ${missingParams.join(', ')} déclaré(s) sur `ZcrudScope` mais '
          'ABSENT(s) de la signature de `derive` : la voie recommandée de '
          'surcharge par écran ne saurait pas surcharger ce(s) seam(s).',
    );

    final Set<String> notForwarded = declared.where((String s) {
      final String escaped = RegExp.escape(s);
      return !RegExp('\\b$escaped\\s*:\\s*$escaped\\b').hasMatch(body);
    }).toSet();
    expect(
      notForwarded,
      isEmpty,
      reason: '🔴 ${notForwarded.join(', ')} accepté(s) par `derive` mais '
          'JAMAIS transmis à `copyWith` sous la forme `<seam>: <seam>` : la '
          'surcharge passée par l\'hôte serait silencieusement ignorée ou '
          'remplacée par une autre valeur.',
    );
  });
}
