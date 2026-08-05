// Lot β — le **porteur de réglages** neutre, sur la requête ET sur la
// régénération.
//
// 🔴 DEUX PROPRIÉTÉS, PAS UNE PRÉSENCE
//
// (1) `ZChatLengthBias` — défini dans `z_chat_enums.dart:116` comme le « biais
//     d'une RÉGÉNÉRATION » — devient atteignable sur son propre cas d'usage.
//     Avant ce lot, `ZChatRegenerateAction` ne portait que `{messageId}` : le
//     réglage était **structurellement inexprimable** (étude CR-IFFD-72, § 4.3).
// (2) Un réglage demandé n'est **jamais jeté en silence**. C'est le défaut
//     mesuré chez IFFD (§ 1.1) : six drapeaux transmis par le contrôleur puis
//     jetés par le repository, sans qu'aucun appelant puisse s'en apercevoir.
//     Ici, un executeur qui ne sait pas les honorer produit un `Left` typé.
//
// Et une contrainte : **aucun enum réinventé**. Le porteur COMPOSE
// `ZChatResponseLength`, `ZChatLengthBias` et `ZChatComputeEffort` ; la
// dernière section le prouve sur les sources.
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'support/z_repo_sources.dart';

/// Executeur MINIMAL — la forme que TOUT hôte a déjà : il implémente le port
/// historique, et **rien de plus**.
class _ExecutorHistorique implements ZChatActionExecutor {
  final List<String> vus = <String>[];

  @override
  Future<ZResult<ZChatActionImpact>> estimateImpact(ZChatAction action) async =>
      Right<ZFailure, ZChatActionImpact>(
        const ZChatActionImpact(affectedMessageCount: 1),
      );

  @override
  Future<ZResult<List<String>>> regenerate({required String messageId}) async {
    vus.add('regenerate:$messageId');
    return Right<ZFailure, List<String>>(<String>[messageId]);
  }

  @override
  Future<ZResult<List<String>>> editAndResend({
    required String messageId,
    required String newText,
  }) async =>
      Right<ZFailure, List<String>>(<String>[messageId]);

  @override
  Future<ZResult<List<String>>> softDeleteMessages({
    required String messageId,
    required bool cascadeToPair,
  }) async =>
      Right<ZFailure, List<String>>(<String>[messageId]);

  @override
  Future<ZResult<Unit>> cancelRequest(String requestId) async =>
      Right<ZFailure, Unit>(unit);

  @override
  Future<ZResult<String>> renderForCopy({
    required String messageId,
    required ZChatCopyFormat format,
  }) async =>
      Right<ZFailure, String>('rendu');

  @override
  Future<ZResult<List<String>>> executeCustom(ZChatCustomAction action) async =>
      Right<ZFailure, List<String>>(const <String>[]);
}

/// Hôte qui **opte** pour la forme riche (lot β).
class _ExecutorAvecReglages extends _ExecutorHistorique
    implements ZChatSettingsAwareActionExecutor {
  ZChatRegenerateAction? recue;

  @override
  Future<ZResult<List<String>>> regenerateWithSettings(
    ZChatRegenerateAction action,
  ) async {
    recue = action;
    vus.add('regenerateWithSettings:${action.messageId}');
    return Right<ZFailure, List<String>>(<String>[action.messageId]);
  }
}

/// Exécute une action de bout en bout par le répartiteur UNIQUE.
Future<ZResult<ZChatActionOutcome>> _executer(
  ZChatActionExecutor executor,
  ZChatAction action,
) async {
  final ZChatActionDispatcher dispatcher = ZChatActionDispatcher(executor);
  final ZChatActionPlan plan = (await dispatcher.prepare(action)).fold(
    (ZFailure f) => throw StateError('prepare a échoué : $f'),
    (ZChatActionPlan p) => p,
  );
  final ZChatConfirmedAction? jeton = plan.requiresConfirmation
      ? plan.confirmedByUser()
      : plan.proceedWithoutConfirmation();
  return dispatcher.execute(jeton!);
}

void main() {
  group('🔴 Le défaut ③ est FERMÉ — `ZChatLengthBias` atteint son cas d\'usage',
      () {
    test('une régénération PORTE son biais de longueur, et il ARRIVE à l\'hôte',
        () async {
      final _ExecutorAvecReglages executor = _ExecutorAvecReglages();
      final ZChatRegenerateAction action = ZChatRegenerateAction(
        messageId: 'm1',
        settings: const ZChatGenerationSettings(
          lengthBias: ZChatLengthBias.shorter,
        ),
      );

      final ZResult<ZChatActionOutcome> issue =
          await _executer(executor, action);

      expect(issue.isRight(), isTrue);
      expect(executor.recue, isNotNull,
          reason: '🔴 les réglages n\'ont pas atteint l\'hôte : le répartiteur '
              'est repassé par le chemin sans réglages, et le biais est mort '
              'en route — le défaut IFFD à la lettre.');
      expect(executor.recue!.settings!.lengthBias, ZChatLengthBias.shorter);
      expect(executor.vus, <String>['regenerateWithSettings:m1']);
    });

    test('🔴 un réglage demandé n\'est JAMAIS jeté en silence', () async {
      final _ExecutorHistorique executor = _ExecutorHistorique();
      final ZChatRegenerateAction action = ZChatRegenerateAction(
        messageId: 'm1',
        settings: const ZChatGenerationSettings(
          lengthBias: ZChatLengthBias.longer,
        ),
      );

      final ZResult<ZChatActionOutcome> issue =
          await _executer(executor, action);

      final ZFailure? echec =
          issue.fold((ZFailure f) => f, (ZChatActionOutcome _) => null);
      expect(echec, isA<ZUnsupportedOperationFailure>(),
          reason: '🔴 REPLI MUET : l\'hôte ne sait pas honorer les réglages et '
              'le socle a régénéré quand même, sans les réglages. L\'appelant '
              'CROIT avoir demandé « plus long ». C\'est exactement le défaut '
              'mesuré chez IFFD (§ 1.1 de l\'étude).');
      expect(
        (echec! as ZUnsupportedOperationFailure).operation,
        'regenerateWithSettings',
        reason: 'l\'hôte doit pouvoir MASQUER l\'option sans parser de texte',
      );
      expect(executor.vus, isEmpty,
          reason: '🔴 le refus doit PRÉCÉDER l\'effet : rien ne doit avoir été '
              'régénéré.');
    });

    test('rétro-compat — une régénération SANS réglages emprunte le chemin '
        'HISTORIQUE, inchangé', () async {
      final _ExecutorHistorique executor = _ExecutorHistorique();
      const ZChatRegenerateAction action =
          ZChatRegenerateAction(messageId: 'm1');

      expect(action.overridesRequest, isFalse);
      final ZResult<ZChatActionOutcome> issue =
          await _executer(executor, action);

      expect(issue.isRight(), isTrue);
      expect(executor.vus, <String>['regenerate:m1'],
          reason: '🔴 un hôte qui n\'a rien changé doit voir EXACTEMENT le '
              'même appel qu\'avant le lot.');
      expect(action.settings, isNull);
      expect(action.corpusScope, isNull);
      // La valeur reste comparable à l'ancienne écriture, au champ près.
      expect(action, const ZChatRegenerateAction(messageId: 'm1'));
      expect(action.verb, 'regenerate');
      expect(action.isDestructive, isFalse);
      expect(action.cascades, isFalse);
      expect(action.preservesDraft, isFalse);
    });

    test('une portée de corpus SEULE suffit à exiger la forme riche', () async {
      final _ExecutorHistorique executor = _ExecutorHistorique();
      final ZChatRegenerateAction action = ZChatRegenerateAction(
        messageId: 'm1',
        corpusScope: ZChatCorpusScope.ofKeys(<String>['corpus-alpha']),
      );
      expect(action.overridesRequest, isTrue);
      final ZResult<ZChatActionOutcome> issue =
          await _executer(executor, action);
      expect(issue.isLeft(), isTrue,
          reason: '🔴 une restriction de corpus jetée en silence est PIRE '
              'qu\'une absence de restriction : elle fait croire à une '
              'garantie.');
      expect(executor.vus, isEmpty);
    });

    test('deux régénérations aux réglages différents ne sont pas ÉGALES', () {
      const ZChatRegenerateAction courte = ZChatRegenerateAction(
        messageId: 'm1',
        settings: ZChatGenerationSettings(lengthBias: ZChatLengthBias.shorter),
      );
      const ZChatRegenerateAction longue = ZChatRegenerateAction(
        messageId: 'm1',
        settings: ZChatGenerationSettings(lengthBias: ZChatLengthBias.longer),
      );
      expect(courte == longue, isFalse,
          reason: '🔴 `==` ignore les réglages : deux demandes distinctes '
              'seraient confondues par tout cache ou toute déduplication.');
      expect(courte.hashCode == longue.hashCode, isFalse);
      expect(
        courte,
        const ZChatRegenerateAction(
          messageId: 'm1',
          settings:
              ZChatGenerationSettings(lengthBias: ZChatLengthBias.shorter),
        ),
      );
    });
  });

  group('Porteur ↔ requête — une PROJECTION fidèle, jamais un doublon', () {
    test('l\'aller-retour est une BIJECTION : `r.withSettings(r.settings) == r`',
        () {
      final ZChatGenerationRequest requete = ZChatGenerationRequest(
        style: ZChatGenerationStyle('answer'),
        notes: 'n',
        responseLength: ZChatResponseLength.detailed,
        lengthBias: ZChatLengthBias.longer,
        computeEffort: ZChatComputeEffort(4),
        revealThinkingSteps: true,
      );

      final ZChatGenerationSettings vue = requete.settings;
      expect(vue.responseLength, ZChatResponseLength.detailed);
      expect(vue.lengthBias, ZChatLengthBias.longer);
      expect(vue.computeEffort, ZChatComputeEffort(4));
      expect(vue.revealThinkingSteps, isTrue);

      expect(requete.withSettings(vue), requete,
          reason: '🔴 la projection PERD un réglage : un hôte qui lit puis '
              'réécrit les réglages en efface un sans le savoir.');
    });

    test('chaque réglage compte INDIVIDUELLEMENT dans l\'aller-retour', () {
      // 🔴 Une bijection testée sur un seul objet « tout renseigné » passerait
      // même si deux champs étaient intervertis. On varie donc UN réglage à la
      // fois, et on exige que la requête en sorte DIFFÉRENTE.
      final ZChatGenerationRequest base = ZChatGenerationRequest(
        style: ZChatGenerationStyle('answer'),
        notes: 'n',
      );
      final List<ZChatGenerationSettings> variantes =
          <ZChatGenerationSettings>[
        const ZChatGenerationSettings(
          responseLength: ZChatResponseLength.concise,
        ),
        const ZChatGenerationSettings(lengthBias: ZChatLengthBias.shorter),
        ZChatGenerationSettings(computeEffort: ZChatComputeEffort(5)),
        const ZChatGenerationSettings(revealThinkingSteps: true),
      ];
      for (final ZChatGenerationSettings v in variantes) {
        final ZChatGenerationRequest r = base.withSettings(v);
        expect(r == base, isFalse, reason: '🔴 réglage INERTE : $v');
        expect(r.settings, v,
            reason: '🔴 le réglage $v n\'est pas relu à l\'identique');
        // Les autres champs de la requête, eux, n'ont pas bougé.
        expect(r.notes, base.notes);
        expect(r.style, base.style);
        expect(r.attachmentIds, base.attachmentIds);
      }
    });

    test('les deux AXES restent séparés : régler la verbosité ne touche pas la '
        'portée, et réciproquement', () {
      final ZChatCorpusScope portee =
          ZChatCorpusScope.ofKeys(<String>['corpus-alpha']);
      final ZChatGenerationRequest requete = ZChatGenerationRequest(
        style: ZChatGenerationStyle('answer'),
        corpusScope: portee,
      );

      final ZChatGenerationRequest reglee = requete.withSettings(
        const ZChatGenerationSettings(
          responseLength: ZChatResponseLength.concise,
        ),
      );
      expect(reglee.corpusScope, portee,
          reason: '🔴 régler la verbosité a ÉLARGI ou effacé la portée : un '
              'effet de bord entre deux axes indépendants.');

      final ZChatGenerationRequest sansPortee = reglee.withCorpusScope(null);
      expect(sansPortee.corpusScope, isNull);
      expect(sansPortee.responseLength, ZChatResponseLength.concise,
          reason: '🔴 retirer la portée a effacé un réglage');
    });

    test('`withSettings(null)` rend la requête TELLE QUELLE', () {
      final ZChatGenerationRequest requete = ZChatGenerationRequest(
        style: ZChatGenerationStyle('answer'),
        responseLength: ZChatResponseLength.detailed,
      );
      expect(identical(requete.withSettings(null), requete), isTrue,
          reason: 'un hôte qui ne règle rien ne doit RIEN payer — pas même une '
              'allocation, ni un chemin d\'exécution différent.');
    });

    test('un porteur VIDE remet les réglages à « l\'hôte décide »', () {
      final ZChatGenerationRequest requete = ZChatGenerationRequest(
        style: ZChatGenerationStyle('answer'),
        responseLength: ZChatResponseLength.detailed,
        computeEffort: ZChatComputeEffort(5),
      );
      const ZChatGenerationSettings vide = ZChatGenerationSettings();
      expect(vide.isEmpty, isTrue);
      final ZChatGenerationRequest nettoyee = requete.withSettings(vide);
      expect(nettoyee.responseLength, isNull);
      expect(nettoyee.computeEffort, isNull,
          reason: 'une feuille de réglages qui RETIRE un réglage doit pouvoir '
              'le retirer — c\'est un remplacement, jamais une fusion.');
    });
  });

  group('Porteur — valeur et (dé)sérialisation défensive (AD-10)', () {
    test('un réglage ABSENT reste absent : aucun défaut inventé au décodage',
        () {
      // 🔴 `ZChatResponseLength.fromJson` et `ZChatLengthBias.fromJson` sont
      // des parses TOTAUX (repli `standard` / `asIs`). Les appliquer à une clé
      // ABSENTE transformerait « non réglé » en « réglé au défaut » — et un
      // hôte se verrait imposer une longueur qu'il n'a jamais demandée.
      final ZChatGenerationSettings? vide =
          ZChatGenerationSettings.fromJson(<String, dynamic>{});
      expect(vide, isNotNull);
      expect(vide!.isEmpty, isTrue,
          reason: '🔴 un DÉFAUT a été inventé au décodage d\'une charge vide : '
              '${vide.toJson()}');

      final ZChatGenerationSettings? partiel =
          ZChatGenerationSettings.fromJson(<String, dynamic>{
        'length_bias': 'shorter',
      });
      expect(partiel!.lengthBias, ZChatLengthBias.shorter);
      expect(partiel.responseLength, isNull);
      expect(partiel.computeEffort, isNull);
    });

    test('aller-retour JSON sans perte, valeurs illisibles absorbées', () {
      final ZChatGenerationSettings reglages = ZChatGenerationSettings(
        responseLength: ZChatResponseLength.concise,
        lengthBias: ZChatLengthBias.longer,
        computeEffort: ZChatComputeEffort(2),
        revealThinkingSteps: false,
      );
      expect(ZChatGenerationSettings.fromJson(reglages.toJson()), reglages);

      expect(ZChatGenerationSettings.fromJson('pas une map'), isNull);
      final ZChatGenerationSettings? bruit =
          ZChatGenerationSettings.fromJson(<String, dynamic>{
        'compute_effort': 'nawak',
        'reveal_thinking_steps': 'peut-être',
      });
      expect(bruit, isNotNull);
      expect(bruit!.isEmpty, isTrue, reason: 'AD-10 : jamais de throw, jamais '
          'de valeur inventée');
    });

    test('`copyWith` conserve les réglages omis', () {
      const ZChatGenerationSettings base = ZChatGenerationSettings(
        responseLength: ZChatResponseLength.concise,
        revealThinkingSteps: true,
      );
      final ZChatGenerationSettings modifie =
          base.copyWith(lengthBias: ZChatLengthBias.longer);
      expect(modifie.responseLength, ZChatResponseLength.concise);
      expect(modifie.revealThinkingSteps, isTrue);
      expect(modifie.lengthBias, ZChatLengthBias.longer);
      expect(base.lengthBias, isNull, reason: 'la valeur d\'origine est '
          'IMMUABLE');
    });
  });

  group('🔴 ANTI-RÉINVENTION — le porteur COMPOSE, il ne redéclare rien', () {
    test('aucun `enum` ni aucune classe de réglage n\'est déclaré par le lot',
        () {
      final File f = File(
        '${repoRoot().path}/packages/zcrud_chat_kernel/lib/src/domain/ai/'
        'z_chat_generation_settings.dart',
      );
      expect(f.existsSync(), isTrue, reason: 'garde VACUELLE');
      final List<String> lignes = strippedLines(f);
      final String code = lignes.join('\n');

      final List<String> declarations = <String>[
        for (final String l in lignes)
          if (RegExp(r'^(enum|class|abstract|extension|typedef|mixin)\b')
              .hasMatch(l))
            l.trim(),
      ];
      expect(declarations, hasLength(1),
          reason: '🔴 Le risque n°1 nommé par la revue était « reconstruire la '
              'moitié de zcrud_chat_kernel ». Ce fichier ne doit déclarer QUE '
              '`ZChatGenerationSettings` ; tout enum de réglage y serait un '
              'DOUBLON de `z_chat_enums.dart`. Vu : $declarations');
      expect(declarations.single, startsWith('class ZChatGenerationSettings'));

      // Volet NON-VACUITÉ : les types EXISTANTS sont bien ceux qui sont portés.
      for (final String existant in <String>[
        'ZChatResponseLength? responseLength;',
        'ZChatLengthBias? lengthBias;',
        'ZChatComputeEffort? computeEffort;',
      ]) {
        expect(code, contains(existant),
            reason: '🔴 `$existant` a disparu du porteur : soit le réglage est '
                'perdu, soit il a été RE-typé — donc redéclaré.');
      }
    });

    test('le porteur n\'a AUCUNE valeur de réglage en dur', () {
      final File f = File(
        '${repoRoot().path}/packages/zcrud_chat_kernel/lib/src/domain/ai/'
        'z_chat_generation_settings.dart',
      );
      final String code = strippedLines(f).join('\n');
      // Les paliers appartiennent aux enums existants : les recopier en
      // littéraux ici rouvrirait la porte au faux-ami que G16 combat.
      for (final String palier in <String>[
        "'concise'",
        "'detailed'",
        "'standard'",
        "'shorter'",
        "'longer'",
        "'asIs'",
      ]) {
        expect(code.contains(palier), isFalse,
            reason: '🔴 palier $palier recopié dans le porteur : la valeur doit '
                'venir de `jsonValue`, sinon les deux orthographes divergeront.');
      }
    });
  });
}
