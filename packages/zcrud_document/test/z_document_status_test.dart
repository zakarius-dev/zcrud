/// AC3 — `ZDocumentStatus` : défensif, **ordre normatif** (D5), dégradation
/// legacy IFFD **ÉPINGLÉE** (D7 / DW-ES21-1).
library;

import 'package:test/test.dart';
import 'package:zcrud_document/zcrud_document.dart';

void main() {
  group('ZDocumentStatus — D5 : l\'ORDRE DE DÉCLARATION est NORMATIF', () {
    test('la 1ʳᵉ constante EST `uploading` (= le repli défensif du codegen)', () {
      // 🔴 Le générateur décode un enum par NOM et, pour un champ non-nullable
      // sans `defaultValue`, son repli est littéralement `T.values.first`
      // (`_fallback`, zcrud_model_generator.dart). Réordonner cet enum changerait
      // SILENCIEUSEMENT le comportement AD-10 de `ZStudyDocument.status`.
      // Ce test est le VERROU de cet ordre.
      expect(ZDocumentStatus.values.first, ZDocumentStatus.uploading);
      expect(
        ZDocumentStatus.values.map((s) => s.name).toList(),
        <String>['uploading', 'validating', 'ready', 'rejected'],
        reason: 'l\'ordre des constantes est NORMATIF (D5) — le modifier change '
            'le défaut défensif d\'un status corrompu.',
      );
    });

    test('isProcessing ne couvre que uploading/validating', () {
      expect(ZDocumentStatus.uploading.isProcessing, isTrue);
      expect(ZDocumentStatus.validating.isProcessing, isTrue);
      expect(ZDocumentStatus.ready.isProcessing, isFalse);
      expect(ZDocumentStatus.rejected.isProcessing, isFalse);
    });
  });

  group('AC3 — décodage DÉFENSIF du status (AD-10 : jamais de throw)', () {
    ZDocumentStatus decode(Object? raw) =>
        ZStudyDocument.fromMap(<String, dynamic>{'status': raw}).status;

    test('valeur connue conservée', () {
      expect(decode('ready'), ZDocumentStatus.ready);
      expect(decode('validating'), ZDocumentStatus.validating);
      expect(decode('rejected'), ZDocumentStatus.rejected);
      expect(decode('uploading'), ZDocumentStatus.uploading);
    });

    test('absent / null / non-String / inconnu ⇒ uploading (1ʳᵉ constante)', () {
      expect(
        ZStudyDocument.fromMap(const <String, dynamic>{}).status,
        ZDocumentStatus.uploading,
        reason: 'clé absente',
      );
      expect(decode(null), ZDocumentStatus.uploading);
      expect(decode(42), ZDocumentStatus.uploading);
      expect(decode(<String, dynamic>{'x': 1}), ZDocumentStatus.uploading);
      expect(decode('READY'), ZDocumentStatus.uploading, reason: 'casse ≠');
      expect(decode('zz_inconnu'), ZDocumentStatus.uploading);
    });

    test('aucune entrée ne fait THROW (AD-10)', () {
      for (final raw in <Object?>[
        null,
        42,
        -1,
        3.14,
        true,
        'zz',
        <String>['ready'],
        <String, dynamic>{},
      ]) {
        expect(() => decode(raw), returnsNormally, reason: 'raw = $raw');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 🟠 DW-ES21-1 — DETTE OUVERTE, ÉPINGLÉE PAR MACHINE (D7).
  //
  // `FolderDocumentStatus` (IFFD) a **6** états ; le canonique (lex) en a **4**.
  // Il n'y a PAS de bijection. Avec le repli défensif D5, un document IFFD RÉEL
  // portant `status: 'embedded'` (donc PRÊT, `readyForChat`) se décode sur
  // `uploading` ⇒ il s'affichera « Traitement… » POUR TOUJOURS.
  //
  // C'est une DÉGRADATION RÉELLE ET CONNUE. Elle n'est PAS corrigée ici : AD-27
  // est explicite — le mapping legacy (casse, clés historiques, statuts 6→4)
  // appartient au CODEC de l'adapter `zcrud_firestore` (ES-3.5 / ES-11.2),
  // JAMAIS au domaine.
  //
  // MAPPING CIBLE À IMPLÉMENTER DANS L'ADAPTER (déterministe, connu) :
  //   uploading              → uploading
  //   converting | embedding → validating
  //   uploaded | converted | embedded → ready
  //
  // ⛔ INTERDIT : « élargir » le canonique aux 6 états IFFD. Le cycle de vie
  //    conversion/embedding IA est un concern APP-SPÉCIFIQUE (comme
  //    `assistantFileId`, `cloudUrl`, `content`) : il passe par `extra`/
  //    `ZExtension` (AD-4), pas par le schéma partagé.
  //
  // Ce test ÉPINGLE le comportement actuel : il n'affirme pas que c'est bien —
  // il rend la dette VISIBLE EN MACHINE (motif central de la rétro ES-1 : « un
  // artefact déclaré sûr sur la base de sa PROSE »). Quand ES-3.5/ES-11.2
  // câbleront le codec, ce test restera VRAI (le domaine, lui, ne change pas) :
  // c'est le codec qui devra traduire AVANT d'appeler `fromMap`.
  // ═══════════════════════════════════════════════════════════════════════════
  group('DW-ES21-1 — dégradation legacy IFFD (6 états → 4), ÉPINGLÉE', () {
    /// Les 6 états d'IFFD (`FolderDocumentStatus`) → ce que le DOMAINE en fait
    /// AUJOURD'HUI, sans codec d'adapter.
    const iffdStates = <String, ZDocumentStatus>{
      'uploading': ZDocumentStatus.uploading, // seul nom commun
      'uploaded': ZDocumentStatus.uploading, // ⛔ dégradé (cible : ready)
      'converting': ZDocumentStatus.uploading, // ⛔ dégradé (cible : validating)
      'converted': ZDocumentStatus.uploading, // ⛔ dégradé (cible : ready)
      'embedding': ZDocumentStatus.uploading, // ⛔ dégradé (cible : validating)
      'embedded': ZDocumentStatus.uploading, // ⛔ dégradé (cible : ready)
    };

    iffdStates.forEach((raw, expected) {
      test('IFFD `$raw` ⇒ ${expected.name} (état ACTUEL du domaine)', () {
        expect(
          ZStudyDocument.fromMap(<String, dynamic>{'status': raw}).status,
          expected,
        );
      });
    });

    test('⛔ `embedded` (document PRÊT côté IFFD) se lit `uploading` — la dette',
        () {
      // LE cas emblématique : un document IFFD réellement PRÊT (indexé, chat
      // disponible) est affiché « Traitement… » indéfiniment tant que le codec
      // d'adapter (ES-3.5/ES-11.2) n'existe pas.
      final doc = ZStudyDocument.fromMap(<String, dynamic>{
        'id': 'd1',
        'file_name': 'cours.pdf',
        'status': 'embedded',
      });
      expect(
        doc.status,
        ZDocumentStatus.uploading,
        reason: 'DW-ES21-1 : dégradation CONNUE et ASSUMÉE. Si ce test rougit, '
            'c\'est que quelqu\'un a mis du mapping legacy DANS LE DOMAINE — '
            'AD-27 l\'interdit (il appartient au codec `zcrud_firestore`). '
            'Vérifier AVANT de « réparer ».',
      );
      expect(doc.status.isProcessing, isTrue);
    });

    test('le canonique reste à 4 états — aucun état IFFD n\'y a été ajouté', () {
      expect(
        ZDocumentStatus.values.length,
        4,
        reason: 'DW-ES21-1 : élargir le canonique aux 6 états IFFD est INTERDIT '
            '(le cycle conversion/embedding IA est app-spécifique ⇒ `extra`/'
            '`ZExtension`, AD-4).',
      );
    });
  });
}
