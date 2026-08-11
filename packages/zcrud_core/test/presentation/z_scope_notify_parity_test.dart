// Garde de PARITÉ entre les paramètres déclarés de `ZcrudScope` et ceux que
// `updateShouldNotify` compare réellement.
//
// 🔴 MOTIF (2026-08-09) — cette garde naît d'un défaut réel, pas d'une
// précaution. `richTextRenderer`, introduit en v0.66.0, était déclaré, propagé
// et consommé, mais ABSENT d'`updateShouldNotify` : un hôte qui changeait de
// moteur de rendu à chaud ne voyait aucun dépendant se reconstruire. Rien ne
// levait, rien ne rougissait — le rendu restait simplement périmé. Mesuré : 21
// paramètres déclarés, 20 comparés.
//
// Le dépôt avait déjà une garde de ce genre pour la RE-POSE du scope dans une
// feuille (`zcrud_study`, CR-IFFD-41), et elle a mordu deux jours de suite sur
// deux ports différents. Mais personne ne surveillait la COMPARAISON. C'est le
// même angle mort, décalé d'un cran.
//
// 🔴 La liste est LUE DANS LA SOURCE, jamais recopiée ici : une liste recopiée
// dériverait avec le fichier qu'elle prétend garder, et cette garde deviendrait
// verte pour la mauvaise raison.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/z_sources.dart' as sources;

/// Remonte jusqu'au dossier portant `melos.yaml` (racine du workspace).
///
/// Ancrage ROBUSTE : `flutter test` se lance depuis le dossier du paquet, et
/// un `../` relatif casserait si l'arborescence bougeait.
Directory _repoRoot() => sources.repoRoot();

void main() {
  test('🔴 STRUCTURE : chaque paramètre de `ZcrudScope` est comparé par '
      '`updateShouldNotify`', () {
    final File source = File(
      '${_repoRoot().path}/packages/zcrud_core/lib/src/presentation/'
      'zcrud_scope.dart',
    );
    expect(source.existsSync(), isTrue, reason: 'source introuvable');

    // 🔴 Les COMMENTAIRES sont retirés AVANT toute analyse. Mesuré le
    // 2026-08-09 : la première version de cette garde bornait la zone lue au
    // premier `;` rencontré, et un point-virgule écrit dans un commentaire de
    // prose française l'a fait s'arrêter AVANT les deux dernières
    // comparaisons — elle a donc accusé du code correct. C'est le pendant
    // d'un incident inverse du même jour (une garde qui rougissait sur sa
    // propre prose parce qu'elle scannait ses commentaires). Une garde qui lit
    // du code ne doit jamais pouvoir être déviée par ce qu'on écrit autour.
    //
    // 🔴 Dépouillement PARTAGÉ (`support/z_sources.dart`) : la première passe
    // ne retirait que les commentaires PLEINE LIGNE — un commentaire de FIN de
    // ligne portant un `;` (ou un `oldWidget.…`) dans `updateShouldNotify`
    // aurait reproduit exactement le défaut ci-dessus. Le chantier
    // documentation rend ce cas probable.
    final String src = sources.strippedSource(source);

    // ── 1. Les paramètres DÉCLARÉS, lus dans le constructeur ────────────────
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

    // ── 2. Les paramètres COMPARÉS, lus dans `updateShouldNotify` ───────────
    final int notifyStart = src.indexOf('bool updateShouldNotify');
    expect(notifyStart, greaterThan(-1),
        reason: '`updateShouldNotify` introuvable');
    final int notifyEnd = src.indexOf(';', notifyStart);
    expect(notifyEnd, greaterThan(notifyStart),
        reason: 'corps de `updateShouldNotify` non borné');
    final String notify = src.substring(notifyStart, notifyEnd);

    final Set<String> compared = RegExp(r'oldWidget\.([a-zA-Z0-9_]+)')
        .allMatches(notify)
        .map((m) => m.group(1)!)
        .toSet();

    // ── 3. `child` et `theme` sont légitimement hors comparaison ────────────
    // `child` : un `InheritedWidget` reconstruit ses enfants par l'arbre, pas
    // par la notification. `theme` : comparé à part s'il l'est — on ne l'exige
    // que s'il figure dans la comparaison, pour ne pas fabriquer une exigence.
    const Set<String> exempt = <String>{'child'};

    final Set<String> missing = declared.difference(compared).difference(exempt);

    expect(
      missing,
      isEmpty,
      reason: '🔴 ${missing.join(', ')} déclaré(s) mais NON comparé(s) par '
          '`updateShouldNotify` : un hôte qui en change à chaud ne verrait '
          'aucun dépendant se reconstruire, et rien ne le signalerait. '
          'Ajoutez `!identical(<param>, oldWidget.<param>) ||` — ou, si '
          "l'omission est délibérée, inscrivez le paramètre dans `exempt` "
          'AVEC son motif écrit.',
    );
  });
}
