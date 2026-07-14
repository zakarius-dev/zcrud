/// AC4 / AC11 — `ZDocumentViewerPrefs` : value object NON-`ZExtensible`,
/// enums pur-Dart défensifs, **invariant de zoom gardé** (R-H).
library;

import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_document/zcrud_document.dart';
// M2 : l'extension générée n'étant plus exportée par le BARREL, l'import DIRECT
// (interne au package) est le seul moyen d'y toucher — c'est précisément ce que
// le `hide` garantit : elle est INATTEIGNABLE depuis l'API publique.
// ignore: implementation_imports
import 'package:zcrud_document/src/domain/z_document_viewer_prefs.dart';

void main() {
  group('AC4 — value object NON-`ZExtensible` (patron ZChoice)', () {
    test('n\'est PAS `ZExtensible` (aucun slot extra/extension à perdre)', () {
      // C'est ce qui justifie sa présence dans `kNonExtensibleKinds` du harnais
      // du gate : (a)/(b)/(e) ne s'y appliquent PAS — et le saut est DÉCLARÉ.
      //
      // ⚠️ Ce n'est PLUS ce qui justifierait d'exporter son extension générée
      // (M2, code-review ES-2.1) : dès lors que l'entité porte un INVARIANT DE
      // VALEUR (zoom fini, > 0, clampé), son `copyWith` généré a quelque chose à
      // DÉTRUIRE. L'extension est désormais `hide` du barrel — cf. le groupe M2.
      expect(const ZDocumentViewerPrefs(), isNot(isA<ZExtensible>()));
    });

    test('défauts : zoom 1.0, vertical, continuous', () {
      const p = ZDocumentViewerPrefs();
      expect(p.zoomLevel, kDefaultZoomLevel);
      expect(p.scrollDirection, ZDocumentScrollDirection.vertical);
      expect(p.pageLayout, ZDocumentPageLayout.continuous);
    });

    test('round-trip stable (toMap → fromMap → toMap)', () {
      const p = ZDocumentViewerPrefs(
        zoomLevel: 2.5,
        scrollDirection: ZDocumentScrollDirection.horizontal,
        pageLayout: ZDocumentPageLayout.single,
      );
      // M2 : `toMap()` est désormais une MÉTHODE D'INSTANCE (l'extension générée
      // est `hide` du barrel). La surface publique de (dé)sérialisation est
      // préservée ; seule la porte du `copyWith` généré est fermée.
      final m1 = p.toMap();
      final relu = ZDocumentViewerPrefs.fromMap(m1);
      expect(relu, p);
      expect(relu.toMap(), equals(m1));
      expect(m1['zoom_level'], 2.5);
      expect(m1['scroll_direction'], 'horizontal');
      expect(m1['page_layout'], 'single');
    });
  });

  group('AC4/AC11 — enums : D5, repli sur la 1ʳᵉ constante', () {
    test('l\'ORDRE des constantes est NORMATIF (verrou)', () {
      expect(ZDocumentScrollDirection.values.first,
          ZDocumentScrollDirection.vertical);
      expect(ZDocumentPageLayout.values.first, ZDocumentPageLayout.continuous);
    });

    test('GARDE : valeur connue conservée', () {
      final p = ZDocumentViewerPrefs.fromMap(<String, dynamic>{
        'scroll_direction': 'horizontal',
        'page_layout': 'single',
      });
      expect(p.scrollDirection, ZDocumentScrollDirection.horizontal);
      expect(p.pageLayout, ZDocumentPageLayout.single);
    });

    test('CORROMPU : inconnu / null / non-String ⇒ 1ʳᵉ constante, jamais de throw',
        () {
      for (final raw in <Object?>[null, 'zz', 42, true, <String>[]]) {
        final p = ZDocumentViewerPrefs.fromMap(<String, dynamic>{
          'scroll_direction': raw,
          'page_layout': raw,
        });
        expect(p.scrollDirection, ZDocumentScrollDirection.vertical,
            reason: 'raw = $raw');
        expect(p.pageLayout, ZDocumentPageLayout.continuous, reason: 'raw = $raw');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AC4 / AC11 / R-H — INVARIANT DE ZOOM : il NAÎT AVEC SA GARDE.
  //
  // 🔵 Décision de story ASSUMÉE, ABSENTE de lex : lex ne borne PAS `zoomLevel`.
  // Un `zoom_level: -5` / `NaN` / `1e9` persisté (corruption, bug d'app) casse le
  // viewer au chargement. R-H/R1 : « chaque invariant de valeur naît avec son
  // test de garde ET son cas de désérialisation corrompue ».
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC11 — zoomLevel : fini, > 0, clampé [kMin, kMax]', () {
    double zoom(Object? raw) =>
        ZDocumentViewerPrefs.fromMap(<String, dynamic>{'zoom_level': raw})
            .zoomLevel;

    test('les bornes sont des CONSTANTES PUBLIQUES nommées et cohérentes', () {
      expect(kMinZoomLevel, 0.25);
      expect(kMaxZoomLevel, 10.0);
      expect(kDefaultZoomLevel, 1.0);
      expect(kMinZoomLevel, lessThan(kDefaultZoomLevel));
      expect(kDefaultZoomLevel, lessThan(kMaxZoomLevel));
    });

    test('GARDE : une valeur légale est CONSERVÉE à l\'identique', () {
      expect(zoom(1.5), 1.5);
      expect(zoom(1.0), 1.0);
      expect(zoom(kMinZoomLevel), kMinZoomLevel);
      expect(zoom(kMaxZoomLevel), kMaxZoomLevel);
      expect(zoom(3), 3.0, reason: 'un `int` persisté est un zoom valide');
    });

    test('CORROMPU : non fini (NaN / ±Infinity) ⇒ 1.0', () {
      expect(zoom(double.nan), kDefaultZoomLevel);
      expect(zoom(double.infinity), kDefaultZoomLevel);
      expect(zoom(double.negativeInfinity), kDefaultZoomLevel);
    });

    test('CORROMPU : <= 0 ⇒ 1.0 (un zoom nul ou négatif n\'a aucun sens)', () {
      expect(zoom(-5), kDefaultZoomLevel);
      expect(zoom(0), kDefaultZoomLevel);
      expect(zoom(-0.001), kDefaultZoomLevel);
    });

    test('CORROMPU : non numérique / absent ⇒ 1.0', () {
      expect(zoom('x'), kDefaultZoomLevel);
      expect(zoom(null), kDefaultZoomLevel);
      expect(zoom(<String, dynamic>{}), kDefaultZoomLevel);
      expect(zoom(true), kDefaultZoomLevel);
      expect(
        ZDocumentViewerPrefs.fromMap(const <String, dynamic>{}).zoomLevel,
        kDefaultZoomLevel,
      );
    });

    test('HORS BORNES (mais fini > 0) ⇒ CLAMPÉ, pas remis à 1.0', () {
      expect(zoom(1e9), kMaxZoomLevel, reason: '1e9 ⇒ borne haute');
      expect(zoom(42), kMaxZoomLevel);
      expect(zoom(0.001), kMinZoomLevel, reason: '0.001 ⇒ borne basse');
      expect(zoom(0.1), kMinZoomLevel);
    });

    test('aucune entrée ne fait THROW (AD-10)', () {
      for (final raw in <Object?>[
        null,
        double.nan,
        double.infinity,
        -5,
        0,
        1e9,
        'x',
        true,
        <String>[],
        <String, dynamic>{},
      ]) {
        expect(() => zoom(raw), returnsNormally, reason: 'raw = $raw');
      }
    });

    test('`copyWith` d\'INSTANCE sanitise AUSSI (l\'invariant ne se rouvre pas)',
        () {
      // Le `copyWith` GÉNÉRÉ accepterait `-5` sans broncher ; le `copyWith`
      // d'instance le MASQUE (un membre d'instance gagne sur un membre
      // d'extension) — c'est ce qui ferme le trou.
      const p = ZDocumentViewerPrefs();
      expect(p.copyWith(zoomLevel: -5.0).zoomLevel, kDefaultZoomLevel);
      expect(p.copyWith(zoomLevel: double.nan).zoomLevel, kDefaultZoomLevel);
      expect(p.copyWith(zoomLevel: 1e9).zoomLevel, kMaxZoomLevel);
      expect(p.copyWith(zoomLevel: 2.0).zoomLevel, 2.0);
      // Champs omis ⇒ conservés.
      expect(
        p
            .copyWith(scrollDirection: ZDocumentScrollDirection.horizontal)
            .zoomLevel,
        kDefaultZoomLevel,
      );
    });

    test('`sanitizeZoomLevel` est PUBLIQUE (une seule définition de la borne)',
        () {
      expect(ZDocumentViewerPrefs.sanitizeZoomLevel(-1), kDefaultZoomLevel);
      expect(ZDocumentViewerPrefs.sanitizeZoomLevel(100), kMaxZoomLevel);
      expect(ZDocumentViewerPrefs.sanitizeZoomLevel(1.5), 1.5);
    });
  });

  group('AC4 — égalité / hashCode', () {
    test('== et hashCode couvrent les 3 champs', () {
      const a = ZDocumentViewerPrefs(zoomLevel: 2.0);
      const b = ZDocumentViewerPrefs(zoomLevel: 2.0);
      const c = ZDocumentViewerPrefs(zoomLevel: 2.0, pageLayout: ZDocumentPageLayout.single);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  // =========================================================================
  // 🟠 M1 (code-review ES-2.1) — AC9 / R-C sur la 3ᵉ entité ENREGISTRÉE.
  //
  // AC9 exige l'assertion « `$XxxFieldSpecs ∩ ZSyncMeta.reservedKeys == {}` »
  // pour CHACUNE des 3 entités, entité par entité — la rétro (R-C) précise que
  // « le gate ne le couvre PAS directement ». Elle existait pour `ZStudyDocument`
  // et `ZDocumentReadingState`… et MANQUAIT ici, pour une entité pourtant
  // ENREGISTRÉE (kind `document_viewer_prefs`), donc persistable top-level.
  // =========================================================================
  group('ZDocumentViewerPrefs — AD-19 / R-C : clés de sync hors-entité (AC9)', () {
    test(r'(R-C) `$ZDocumentViewerPrefsFieldSpecs` ∩ ZSyncMeta.reservedKeys == {}',
        () {
      final specNames =
          $ZDocumentViewerPrefsFieldSpecs.map((s) => s.name).toSet();
      expect(specNames, equals(<String>{
        'zoom_level',
        'scroll_direction',
        'page_layout',
      }));
      expect(
        specNames.intersection(ZSyncMeta.reservedKeys),
        isEmpty,
        reason: 'un champ persisté sous `updated_at`/`is_deleted` serait ÉCRASÉ '
            'par le store à chaque `put` (il écrit sa méta APRÈS le corps) — '
            'perte de valeur métier SILENCIEUSE (AD-19.1.a). Le geste NATUREL que '
            'R-C décrit (« dernière préférence modifiée » ⇒ `updated_at`) est '
            'exactement celui qu\'il faut empêcher.',
      );
    });

    test('(AD-19.1.b) aucun `persistAs: timestamp` sur une clé réservée', () {
      expect(
        $ZDocumentViewerPrefsTimestampFields.intersection(
          ZSyncMeta.reservedKeys,
        ),
        isEmpty,
      );
    });

    test('`toMap()` ne réémet NI `updated_at` NI `is_deleted`', () {
      const p = ZDocumentViewerPrefs(zoomLevel: 2.0);
      final m = p.toMap();
      expect(m.keys.toSet().intersection(ZSyncMeta.reservedKeys), isEmpty);
    });
  });

  // =========================================================================
  // 🟠 M2 (code-review ES-2.1) — l'extension générée est `hide` du BARREL.
  //
  // LE TROU : `ZDocumentViewerPrefsZcrud` était EXPORTÉE. Le `copyWith`
  // d'instance ne masque le `copyWith` généré que sur l'appel IMPLICITE ; l'appel
  // EXPLICITE d'extension restait ouvert **depuis l'API publique** et
  // CONTOURNAIT `sanitizeZoomLevel` :
  //     ZDocumentViewerPrefsZcrud(p).copyWith(zoomLevel: -5)  ⇒  -5.0
  // La justification d'AC1 (« pas `ZExtensible` ⇒ rien à perdre ») est devenue
  // FAUSSE dès que l'entité a reçu un INVARIANT DE VALEUR (défaut de la STORY —
  // R-G, pas du dev).
  // =========================================================================
  group('M2 — `ZDocumentViewerPrefsZcrud` n\'est plus exportée (barrel `hide`)',
      () {
    test('le trou EXISTAIT : le `copyWith` GÉNÉRÉ contourne bel et bien la garde',
        () {
      // Reproduction du finding, par l'import DIRECT (interne). C'est un test de
      // NON-RÉGRESSION DE LA MOTIVATION : si un jour ce `copyWith` sanitisait, le
      // `hide` pourrait être rediscuté — mais tant qu'il ne le fait pas, exporter
      // l'extension rouvrirait l'invariant depuis l'API PUBLIQUE.
      const p = ZDocumentViewerPrefs();
      expect(
        ZDocumentViewerPrefsZcrud(p).copyWith(zoomLevel: -5.0).zoomLevel,
        -5.0,
        reason: 'le `copyWith` GÉNÉRÉ ne sanitise RIEN — voilà pourquoi son '
            'extension DOIT être `hide` du barrel public.',
      );
    });

    test('la voie PUBLIQUE, elle, SANITISE (copyWith d\'instance)', () {
      const p = ZDocumentViewerPrefs();
      expect(p.copyWith(zoomLevel: -5.0).zoomLevel, kDefaultZoomLevel);
      expect(p.copyWith(zoomLevel: double.nan).zoomLevel, kDefaultZoomLevel);
      expect(p.copyWith(zoomLevel: 1e9).zoomLevel, kMaxZoomLevel);
      expect(p.copyWith(zoomLevel: 0.01).zoomLevel, kMinZoomLevel);
      expect(p.copyWith(zoomLevel: 2.5).zoomLevel, 2.5);
    });

    test('`toMap()` d\'INSTANCE : la surface publique est PRÉSERVÉE', () {
      // Le `hide` ne coûte AUCUNE surface : `toMap()` est promu en méthode
      // d'instance (aligné sur ses deux sœurs, qui en ont une).
      const p = ZDocumentViewerPrefs(
        zoomLevel: 2.5,
        scrollDirection: ZDocumentScrollDirection.horizontal,
      );
      expect(p.toMap(), equals(ZDocumentViewerPrefsZcrud(p).toMap()));
      expect(p.toMap()['zoom_level'], 2.5);
    });
  });
}
