// Garde de PARITÉ entre les paramètres de `ZMarkdownField.fromContext` et ceux
// que `registerZMarkdownFields` expose ET transmet réellement.
//
// 🔴 MOTIF (CR géo/markdown 2026-08-11, B2) — cette garde naît d'un défaut
// réel : `toolbarConfig` (GAP-9, livré v0.82.0) était accepté par
// `ZMarkdownField` mais ABSENT de `registerZMarkdownFields` — or le registre
// est la SEULE voie de construction pour un hôte (le widget est bâti par le
// `ZWidgetRegistry`). La fonctionnalité livrée était donc inutilisable par une
// app. Règle CR : « ce que `ZMarkdownField` accepte, le registre doit pouvoir
// le passer » — sauf exemption justifiée par écrit ci-dessous.
//
// 🔴 La liste est LUE DANS LA SOURCE, jamais recopiée ici : une liste recopiée
// dériverait avec le fichier qu'elle prétend garder (patron
// `z_scope_notify_parity_test.dart` de zcrud_core).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Remonte jusqu'au dossier portant `melos.yaml` (racine du workspace).
///
/// Ancrage ROBUSTE : `flutter test` se lance depuis le dossier du paquet, et
/// un `../` relatif casserait si l'arborescence bougeait.
Directory _repoRoot() {
  Directory dir = Directory.current;
  while (true) {
    if (File('${dir.path}/melos.yaml').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      fail('racine du workspace introuvable (aucun `melos.yaml` en remontant)');
    }
    dir = parent;
  }
}

/// Lit [path] (relatif à la racine) en RETIRANT les commentaires `//` AVANT
/// toute analyse.
///
/// 🔴 Mesuré sur la garde-patron (2026-08-09) : borner un scan au premier `;`
/// rencontré s'était arrêté DANS un commentaire de prose française — la garde
/// accusait du code correct. Une garde qui lit du code ne doit jamais pouvoir
/// être déviée par ce qu'on écrit autour.
String _sourceSansCommentaires(String path) {
  final File source = File('${_repoRoot().path}/$path');
  expect(source.existsSync(), isTrue, reason: 'source introuvable : $path');
  return source
      .readAsStringSync()
      .split('\n')
      .map((line) {
        final trimmed = line.trimLeft();
        return trimmed.startsWith('//') ? '' : line;
      })
      .join('\n');
}

void main() {
  const String fieldPath =
      'packages/zcrud_markdown/lib/src/presentation/z_markdown_field.dart';
  const String regPath =
      'packages/zcrud_markdown/lib/src/presentation/z_markdown_registration.dart';

  test(
      '🔴 STRUCTURE : chaque paramètre de `ZMarkdownField.fromContext` est '
      'exposé par `registerZMarkdownFields` (ou exempté avec motif écrit)', () {
    final String fieldSrc = _sourceSansCommentaires(fieldPath);
    final String regSrc = _sourceSansCommentaires(regPath);

    // ── 1. Les paramètres ACCEPTÉS, lus dans `fromContext` ──────────────────
    final int ctorStart = fieldSrc.indexOf('ZMarkdownField.fromContext({');
    expect(ctorStart, greaterThan(-1), reason: '`fromContext` introuvable');
    final int ctorEnd = fieldSrc.indexOf('})', ctorStart);
    expect(ctorEnd, greaterThan(ctorStart), reason: '`fromContext` non borné');
    final String ctor = fieldSrc.substring(ctorStart, ctorEnd);

    final Set<String> accepted = RegExp(r'this\.([a-zA-Z0-9_]+)')
        .allMatches(ctor)
        .map((m) => m.group(1)!)
        .toSet();

    // Anti-vacuité : sans cette borne, un constructeur illisible rendrait un
    // ensemble VIDE et la garde passerait en n'observant rien.
    expect(accepted.length, greaterThanOrEqualTo(10),
        reason: 'trop peu de paramètres lus — le parsing a probablement échoué');

    // ── 2. Les paramètres EXPOSÉS, lus dans `registerZMarkdownFields` ───────
    final int regStart = regSrc.indexOf('void registerZMarkdownFields(');
    expect(regStart, greaterThan(-1),
        reason: '`registerZMarkdownFields` introuvable');
    final int regEnd = regSrc.indexOf('})', regStart);
    expect(regEnd, greaterThan(regStart), reason: 'signature non bornée');
    final String regSig = regSrc.substring(regStart, regEnd);

    // Nom = DERNIER identifiant du fragment de paramètre, défaut retiré.
    final Set<String> exposed = regSig
        .substring(regSig.indexOf('(') + 1)
        .split(',')
        .map((p) => p.split('=').first.trim())
        .where((p) => p.isNotEmpty)
        .map((p) => RegExp(r'([a-zA-Z0-9_]+)\s*$').firstMatch(p)?.group(1))
        .whereType<String>()
        .toSet();

    expect(exposed.length, greaterThanOrEqualTo(5),
        reason: 'trop peu de paramètres lus — le parsing a probablement échoué');

    // ── 3. Exemptions JUSTIFIÉES (chacune avec son motif — jamais tacite) ───
    const Set<String> exempt = <String>{
      // Fournis par le dispatch du registre lui-même : `ctx` vient du builder,
      // `mode` est dérivé du `kind` enregistré, `key` est posé par le registre
      // (`ValueKey` stable — AD-2). Non délégables à l'hôte.
      'ctx', 'mode', 'key',
      // Hooks d'instrumentation `@visibleForTesting` : pas une API de prod,
      // n'ont rien à faire au registre.
      'onInit', 'onBuild',
      // Canal PAR-CHAMP déjà servi par `ZFieldSpec.hintText` (résolu l10n) ;
      // le paramètre étant PRIORITAIRE sur `hintText`, un littéral partagé au
      // registre écraserait le placeholder propre de CHAQUE champ — contraire
      // à la sémantique « défaut de registre ».
      'placeholder',
    };

    final Set<String> missing = accepted.difference(exposed).difference(exempt);
    expect(
      missing,
      isEmpty,
      reason: '🔴 ${missing.join(', ')} accepté(s) par '
          '`ZMarkdownField.fromContext` mais NON exposé(s) par '
          '`registerZMarkdownFields` : le registre étant la seule voie de '
          "construction d'un hôte, la fonctionnalité est inutilisable "
          '(défaut B2, CR 2026-08-11). Exposez le paramètre — ou, si '
          "l'omission est délibérée, inscrivez-le dans `exempt` AVEC son "
          'motif écrit.',
    );

    // ── 4. Chaque paramètre exposé est TRANSMIS au widget ───────────────────
    // Déclaré sans être transmis = le même défaut, un cran plus loin (l'hôte
    // le pose, rien ne se passe, rien ne rougit).
    final int callStart = regSrc.indexOf('ZMarkdownField.fromContext(');
    expect(callStart, greaterThan(-1),
        reason: 'appel `fromContext` introuvable dans le registre');
    final int callEnd = regSrc.indexOf(');', callStart);
    expect(callEnd, greaterThan(callStart), reason: 'appel non borné');
    final Set<String> forwarded = RegExp(r'([a-zA-Z0-9_]+):')
        .allMatches(regSrc.substring(callStart, callEnd))
        .map((m) => m.group(1)!)
        .toSet();

    final Set<String> declaredNotForwarded =
        exposed.difference(forwarded).difference(<String>{'registry'});
    expect(
      declaredNotForwarded,
      isEmpty,
      reason: '🔴 ${declaredNotForwarded.join(', ')} exposé(s) par '
          '`registerZMarkdownFields` mais JAMAIS transmis à '
          '`ZMarkdownField.fromContext` — un hôte le poserait sans effet.',
    );
  });
}
