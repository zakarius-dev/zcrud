// CHAT-0b — `ZChatAction` (famille SCELLÉE), `ZChatActionPlan`,
// `ZChatConfirmedAction`, `ZChatActionOutcome`, `ZChatActionNotConfirmedFailure`.
//
// 🔴 Ce que ces tests DÉFENDENT :
// * le **scellement** — un verbe ajouté sans être traité doit être DÉTECTÉ (ici
//   au compilateur : le `switch` exhaustif de ce fichier ne compile plus) ;
// * la **table des quatre déclarations** — chaque verbe se prononce sur sa
//   destructivité, sa cascade et sa préservation de saisie. IFFD n'avait AUCUNE
//   de ces déclarations : chaque écran décidait dans son coin, et les décisions
//   divergeaient ;
// * la **dérivation** de `requiresConfirmation` sur ses TROIS branches — ne
//   garder que `isDestructive` laisserait passer la cascade Q+R non annoncée ;
// * l'**infalsifiabilité** du jeton.
//
// ⚠️ Aucune (dé)sérialisation n'est testée ici : le contrat d'action de CHAT-0b
// n'en porte AUCUNE (aucun `toMap`/`fromMap`, aucun `toJson`/`fromJson` dans
// `lib/src/domain/action/`). Un plan et une issue sont des valeurs de session,
// jamais persistées : leur « round-trip » est celui de leur ÉGALITÉ DE VALEUR,
// testée ci-dessous. Le jour où CHAT-1 les persistera, c'est là que le corpus
// `serialization-compat` s'étendra.
library;

import 'package:test/test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

/// 🔴 **Le SEUL moyen d'obtenir un plan** depuis CHAT-0b corrigé : le
/// constructeur de `ZChatActionPlan` est **privé**, et sa seule fabrique est
/// `ZChatActionDispatcher.prepare`, qui `await` `estimateImpact`.
///
/// Ces tests empruntaient l'ancien constructeur public — la forme même du
/// contournement que la correction ferme (un plan fabriqué de toutes pièces,
/// donc un jeton obtenu sans qu'aucun impact n'ait été chiffré). Ils passent
/// donc désormais par le protocole réel. **Aucune garde n'est affaiblie** : les
/// propriétés assertées (identité de valeur, dérivation de
/// `requiresConfirmation`, infalsifiabilité du jeton) sont inchangées ; seule
/// leur MISE EN PLACE emprunte le chemin légitime.
class _ImpactExecutor implements ZChatActionExecutor {
  const _ImpactExecutor(this.impact);

  final ZChatActionImpact impact;

  @override
  Future<ZResult<ZChatActionImpact>> estimateImpact(ZChatAction action) async =>
      Right<ZFailure, ZChatActionImpact>(impact);

  @override
  Future<ZResult<List<String>>> editAndResend({
    required String messageId,
    required String newText,
  }) async => throw UnimplementedError();

  @override
  Future<ZResult<List<String>>> regenerate({required String messageId}) async =>
      throw UnimplementedError();

  @override
  Future<ZResult<List<String>>> softDeleteMessages({
    required String messageId,
    required bool cascadeToPair,
  }) async => throw UnimplementedError();

  @override
  Future<ZResult<Unit>> cancelRequest(String requestId) async =>
      throw UnimplementedError();

  @override
  Future<ZResult<String>> renderForCopy({
    required String messageId,
    required ZChatCopyFormat format,
  }) async => throw UnimplementedError();

  @override
  Future<ZResult<List<String>>> executeCustom(ZChatCustomAction action) async =>
      throw UnimplementedError();
}

/// Bâtit un plan **par le protocole** (impact chiffré par un executor).
Future<ZChatActionPlan> planFor(ZChatAction a, [ZChatActionImpact? i]) async =>
    (await ZChatActionDispatcher(_ImpactExecutor(i ?? const ZChatActionImpact()))
            .prepare(a))
        .fold(
      (ZFailure f) => fail('prepare a échoué : $f'),
      (ZChatActionPlan p) => p,
    );

/// Les SIX variants de la famille scellée, un de chaque.
const List<ZChatAction> _tousLesVerbes = <ZChatAction>[
  ZChatEditAction(messageId: 'm', newText: 'n'),
  ZChatRegenerateAction(messageId: 'm'),
  ZChatDeleteAction(messageId: 'm'),
  ZChatCancelAction(requestId: 'r'),
  ZChatCopyAction(messageId: 'm'),
  ZChatCustomAction(verb: 'pin', isDestructive: false, cascades: false),
];

/// 🔴 LE SCELLEMENT, EXPRIMÉ COMME UNE CONTRAINTE DE COMPILATION.
///
/// `switch` **exhaustif sans fourre-tout** sur une famille `sealed` : ajouter un
/// variant à `ZChatAction` sans le traiter ici rend ce fichier NON COMPILABLE.
/// C'est la détection demandée — elle arrive avant même l'exécution, et elle est
/// impossible à contourner par distraction (contrairement à une liste de noms
/// qu'on oublie de mettre à jour).
String _etiquette(ZChatAction a) => switch (a) {
      ZChatEditAction() => 'edit',
      ZChatRegenerateAction() => 'regenerate',
      ZChatDeleteAction() => 'delete',
      ZChatCancelAction() => 'cancel',
      ZChatCopyAction() => 'copy',
      ZChatCustomAction() => 'custom',
    };

void main() {
  group('🔴 scellement de la famille `ZChatAction`', () {
    test('les SIX variants sont couverts, sans doublon ni fourre-tout', () {
      expect(_tousLesVerbes.map(_etiquette).toList(), <String>[
        'edit',
        'regenerate',
        'delete',
        'cancel',
        'copy',
        'custom',
      ]);
      expect(_tousLesVerbes.map(_etiquette).toSet(), hasLength(6),
          reason: 'deux variants qui retombent sur la même étiquette = un '
              'verbe qui en masque un autre');
    });

    test('les verbes techniques sont STABLES (jamais des libellés)', () {
      expect(_tousLesVerbes.map((ZChatAction a) => a.verb).toList(), <String>[
        'edit',
        'regenerate',
        'delete',
        'cancel',
        'copy',
        'pin',
      ]);
      for (final ZChatAction a in _tousLesVerbes) {
        expect(a.verb, matches(RegExp(r'^[a-z][a-zA-Z]*$')),
            reason: '🔴 un verbe est un discriminant TECHNIQUE en camelCase, '
                'jamais un libellé traduisible (AD-13/FR-26).');
      }
    });

    test('CHAQUE variant se prononce sur les QUATRE déclarations', () {
      // (verbe, destructif, cascade, préserve la saisie)
      const List<List<Object>> table = <List<Object>>[
        <Object>['edit', true, true, true],
        <Object>['regenerate', false, false, false],
        <Object>['delete', true, true, false],
        <Object>['cancel', false, false, true],
        <Object>['copy', false, false, false],
        <Object>['pin', false, false, false],
      ];
      for (int i = 0; i < _tousLesVerbes.length; i++) {
        final ZChatAction a = _tousLesVerbes[i];
        expect(<Object>[a.verb, a.isDestructive, a.cascades, a.preservesDraft],
            table[i],
            reason: '🔴 verbe `${a.verb}` : c\'est l\'ABSENCE de ces quatre '
                'déclarations qui laissait chaque écran d\'IFFD décider dans '
                'son coin — et diverger.');
      }
    });

    test('`delete` : la cascade SUIT `cascadeToPair`, elle n\'est pas '
        'présumée', () {
      expect(const ZChatDeleteAction(messageId: 'm').cascades, isTrue);
      expect(
        const ZChatDeleteAction(messageId: 'm', cascadeToPair: false).cascades,
        isFalse,
        reason: '🔴 défaut IFFD n°1 : la cascade question+réponse était '
            'SILENCIEUSE. Ici elle est déclarée par l\'action et chiffrée par '
            'le plan.',
      );
    });

    test('le variant OUVERT n\'a AUCUN défaut permissif (AD-4)', () {
      // `isDestructive` et `cascades` sont REQUIS : un hôte ne peut pas ajouter
      // un verbe « sans avis » sur sa destructivité.
      const ZChatCustomAction destructeur = ZChatCustomAction(
        verb: 'archiveAll',
        isDestructive: true,
        cascades: true,
        payload: <String, dynamic>{'scope': 'thread'},
      );
      expect(destructeur.isDestructive, isTrue);
      expect(destructeur.cascades, isTrue);
      expect(destructeur.preservesDraft, isFalse,
          reason: 'seul `preservesDraft` a un défaut, et il est PRUDENT');
      expect(
        destructeur,
        const ZChatCustomAction(
          verb: 'archiveAll',
          isDestructive: true,
          cascades: true,
          payload: <String, dynamic>{'scope': 'thread'},
        ),
        reason: 'égalité de valeur, payload compris (`zJsonEquals`)',
      );
      expect(
        destructeur ==
            const ZChatCustomAction(
              verb: 'archiveAll',
              isDestructive: true,
              cascades: true,
              payload: <String, dynamic>{'scope': 'message'},
            ),
        isFalse,
      );
    });
  });

  group('égalité de valeur — le « round-trip » d\'un contrat non persisté', () {
    test('`ZChatDraft` : texte ET pièces jointes entrent dans l\'identité', () {
      const ZChatDraft a =
          ZChatDraft(text: 'salut', attachmentIds: <String>['x', 'y']);
      expect(a, const ZChatDraft(text: 'salut', attachmentIds: <String>['x', 'y']));
      expect(a.hashCode,
          const ZChatDraft(text: 'salut', attachmentIds: <String>['x', 'y']).hashCode);
      expect(a == const ZChatDraft(text: 'salut', attachmentIds: <String>['y', 'x']),
          isFalse, reason: 'l\'ORDRE des pièces jointes fait partie de la saisie');
      expect(a == const ZChatDraft(text: 'salut'), isFalse);
      expect(const ZChatDraft(), const ZChatDraft(text: ''));
      expect(a.toString(), isNot(contains('salut')),
          reason: '🔴 la saisie de l\'utilisateur ne doit pas fuir dans un log '
              '(le `toString` ne rend que des tailles).');
    });

    test('chaque variant a une identité qui inclut TOUS ses champs', () {
      expect(const ZChatEditAction(messageId: 'm', newText: 'a'),
          const ZChatEditAction(messageId: 'm', newText: 'a'));
      expect(
          const ZChatEditAction(messageId: 'm', newText: 'a') ==
              const ZChatEditAction(messageId: 'm', newText: 'b'),
          isFalse);
      expect(
          const ZChatEditAction(messageId: 'm', newText: 'a') ==
              const ZChatEditAction(
                  messageId: 'm', newText: 'a', draft: ZChatDraft(text: 'z')),
          isFalse,
          reason: 'la saisie transportée fait partie de l\'action');
      expect(
          const ZChatCancelAction(requestId: 'r1') ==
              const ZChatCancelAction(requestId: 'r2'),
          isFalse,
          reason: '🔴 l\'identité de la REQUÊTE distingue deux annulations : '
              'c\'est ce qui remplace le `CancelToken` d\'instance partagé.');
      expect(
          const ZChatCopyAction(messageId: 'm') ==
              const ZChatCopyAction(
                  messageId: 'm', format: ZChatCopyFormat.markdown),
          isFalse);
      expect(
          const ZChatDeleteAction(messageId: 'm') ==
              const ZChatDeleteAction(messageId: 'm', cascadeToPair: false),
          isFalse,
          reason: 'deux suppressions de cascades différentes ne sont PAS la '
              'même action');
      // Deux verbes distincts portant le même identifiant ne se confondent pas.
      expect(
          const ZChatRegenerateAction(messageId: 'm') ==
              const ZChatDeleteAction(messageId: 'm'),
          isFalse);
    });

    test('`ZChatActionImpact` : identité et `toString` diagnostiquable', () {
      const ZChatActionImpact i = ZChatActionImpact(
        affectedMessageCount: 3,
        posteriorMessageCount: 2,
        cascadesToRequestAndResponse: true,
      );
      expect(i, const ZChatActionImpact(
        affectedMessageCount: 3,
        posteriorMessageCount: 2,
        cascadesToRequestAndResponse: true,
      ));
      expect(i.hashCode, isNot(const ZChatActionImpact().hashCode));
      expect(const ZChatActionImpact().affectedMessageCount, 0);
      expect(i.toString(), allOf(contains('3'), contains('2'), contains('true')));
    });

    test('`ZChatActionPlan` : identité = action + impact', () async {
      final ZChatActionPlan p = await planFor(
        const ZChatDeleteAction(messageId: 'm'),
        const ZChatActionImpact(affectedMessageCount: 2),
      );
      expect(p, await planFor(
        const ZChatDeleteAction(messageId: 'm'),
        const ZChatActionImpact(affectedMessageCount: 2),
      ));
      expect(p.hashCode, (await planFor(
        const ZChatDeleteAction(messageId: 'm'),
        const ZChatActionImpact(affectedMessageCount: 2),
      )).hashCode);
      expect(
          p ==
              await planFor(
                const ZChatDeleteAction(messageId: 'm'),
                const ZChatActionImpact(),
              ),
          isFalse,
          reason: '🔴 deux plans de MÊME action mais d\'impact différent ne '
              'sont pas interchangeables : l\'impact est ce qui décide de la '
              'confirmation.');
      expect(p.toString(), contains('requiresConfirmation: true'));
    });
  });

  group('🔴 `requiresConfirmation` est DÉRIVÉ — ses trois branches', () {
    Future<ZChatActionPlan> plan(ZChatAction a, [ZChatActionImpact? i]) =>
        planFor(a, i);

    test('branche 1 — destructif', () async {
      final ZChatActionPlan p = await plan(
          const ZChatDeleteAction(messageId: 'm', cascadeToPair: false));
      expect(p.action.isDestructive, isTrue);
      expect(p.action.cascades, isFalse);
      expect(p.impact.affectedMessageCount, 0);
      expect(p.requiresConfirmation, isTrue);
    });

    test('branche 2 — cascade, même NON destructive', () async {
      const ZChatCustomAction cascadante = ZChatCustomAction(
        verb: 'foldThread',
        isDestructive: false,
        cascades: true,
      );
      final ZChatActionPlan p = await plan(cascadante);
      expect(p.action.isDestructive, isFalse);
      expect(p.requiresConfirmation, isTrue,
          reason: '🔴 ne garder que `isDestructive` laisserait passer la '
              'cascade Q+R non annoncée d\'IFFD (défaut n°1).');
    });

    test('branche 3 — plus d\'UN message touché', () async {
      expect(
        (await plan(const ZChatRegenerateAction(messageId: 'm'),
                const ZChatActionImpact(affectedMessageCount: 2)))
            .requiresConfirmation,
        isTrue,
      );
      expect(
        (await plan(const ZChatRegenerateAction(messageId: 'm'),
                const ZChatActionImpact(affectedMessageCount: 1)))
            .requiresConfirmation,
        isFalse,
        reason: 'toucher SA cible n\'est pas une cascade — sinon le contrat '
            'ferait confirmer chaque geste, et l\'hôte apprendrait à cliquer '
            'sans lire (la confirmation deviendrait décorative).',
      );
    });

    test('aucune branche — le seul cas SANS confirmation', () async {
      for (final ZChatAction a in <ZChatAction>[
        const ZChatRegenerateAction(messageId: 'm'),
        const ZChatCancelAction(requestId: 'r'),
        const ZChatCopyAction(messageId: 'm'),
      ]) {
        expect((await plan(a)).requiresConfirmation, isFalse, reason: a.verb);
        expect((await plan(a)).proceedWithoutConfirmation(), isNotNull,
            reason: a.verb);
      }
      // 🔴 `cancel` en fait partie, et c'est VOULU : annuler n'est pas
      // destructeur (D3). IFFD confondait les deux et supprimait la question.
      expect(
        (await plan(const ZChatCancelAction(requestId: 'r')))
            .requiresConfirmation,
        isFalse,
      );
    });

    test('les verbes destructeurs exigent TOUS la confirmation', () async {
      for (final ZChatAction a in <ZChatAction>[
        const ZChatEditAction(messageId: 'm', newText: 'n'),
        const ZChatDeleteAction(messageId: 'm'),
      ]) {
        expect((await plan(a)).requiresConfirmation, isTrue, reason: a.verb);
        expect((await plan(a)).proceedWithoutConfirmation(), isNull,
            reason: a.verb);
      }
    });
  });

  group('🔴 le jeton est INFALSIFIABLE', () {
    test('`proceedWithoutConfirmation` rend un jeton NON confirmé, et rien '
        'de plus', () async {
      final ZChatActionPlan p = await planFor(
        const ZChatCopyAction(messageId: 'm5'),
      );
      final ZChatConfirmedAction jeton = p.proceedWithoutConfirmation()!;
      expect(jeton.userConfirmed, isFalse);
      expect(jeton.plan, same(p));
      expect(jeton.action, const ZChatCopyAction(messageId: 'm5'),
          reason: 'le jeton PORTE son plan : `execute` peut donc re-contrôler '
              'l\'exigence de confirmation au dernier moment.');
      expect(jeton.toString(), allOf(contains('copy'), contains('false')));
    });

    test('`confirmedByUser` est le SEUL chemin vers un jeton confirmé',
        () async {
      final ZChatActionPlan p = await planFor(
        const ZChatDeleteAction(messageId: 'm'),
        const ZChatActionImpact(affectedMessageCount: 2),
      );
      expect(p.proceedWithoutConfirmation(), isNull);
      final ZChatConfirmedAction jeton = p.confirmedByUser();
      expect(jeton.userConfirmed, isTrue);
      expect(jeton.plan, same(p));
      // ⚠️ Limite ASSUMÉE et documentée (D2) : un hôte qui appelle
      // `confirmedByUser()` sans avoir montré de dialogue MENT au contrat. Ce
      // que le socle garantit, c'est que le mensonge est LOCALISÉ et greppable
      // en un seul appel nommé — pas dissous dans 5153 lignes d'écran.
      expect(jeton.action, same(p.action));
    });

    test('deux jetons du même plan restent des VALEURS distinctes', () async {
      final ZChatActionPlan p = await planFor(
        const ZChatCopyAction(messageId: 'm'),
      );
      final ZChatConfirmedAction a = p.confirmedByUser();
      final ZChatConfirmedAction b = p.proceedWithoutConfirmation()!;
      expect(a.userConfirmed, isTrue);
      expect(b.userConfirmed, isFalse);
      expect(identical(a, b), isFalse,
          reason: '🔴 aucun jeton n\'est mis en cache : un « oui » ne peut pas '
              'être rejoué pour une autre exécution.');
    });
  });

  group('`ZChatActionOutcome` — aucun texte libre où une exception pourrait '
      'se déguiser en réponse', () {
    test('les défauts sont NEUTRES', () {
      const ZChatActionOutcome o = ZChatActionOutcome(verb: 'regenerate');
      expect(o.affectedMessageIds, isEmpty);
      expect(o.softDeleted, isFalse);
      expect(o.preservedDraft, isNull);
      expect(o.copyPayload, isNull,
          reason: '🔴 le SEUL texte libre du type reste nul par défaut : rien '
              'ne peut y être glissé « au passage » (défaut IFFD n°4).');
    });

    test('le `toString` ne divulgue NI la saisie NI le rendu copié', () {
      const ZChatActionOutcome o = ZChatActionOutcome(
        verb: 'copy',
        affectedMessageIds: <String>['m1'],
        preservedDraft: ZChatDraft(text: 'secret de l\'utilisateur'),
        copyPayload: 'contenu intégral du message',
      );
      expect(o.toString(), isNot(contains('secret')));
      expect(o.toString(), isNot(contains('contenu intégral')));
      expect(o.toString(), allOf(contains('copy'), contains('draft: true')));
    });
  });

  group('`ZChatActionNotConfirmedFailure` — D9, une SEULE failure du lot', () {
    test('elle NOMME le verbe et ne force aucun parsing de texte', () {
      const ZChatActionNotConfirmedFailure f =
          ZChatActionNotConfirmedFailure(verb: 'delete');
      expect(f, isA<ZFailure>());
      expect(f.verb, 'delete');
      expect(f.message, isNotEmpty);
      expect(f, const ZChatActionNotConfirmedFailure(verb: 'delete'));
      expect(f.hashCode,
          const ZChatActionNotConfirmedFailure(verb: 'delete').hashCode);
      expect(f == const ZChatActionNotConfirmedFailure(verb: 'edit'), isFalse,
          reason: '🔴 le verbe entre dans l\'identité : deux refus de verbes '
              'différents ne se confondent pas.');
      expect(f.toString(), contains('delete'));
    });

    test('elle ne se confond pas avec les failures RÉUTILISÉES (D9)', () {
      const ZChatActionNotConfirmedFailure f =
          ZChatActionNotConfirmedFailure(verb: 'delete');
      expect(f, isNot(isA<ZUnsupportedOperationFailure>()));
      expect(f == ZDomainFailure(f.message), isFalse,
          reason: '🔴 « refusé faute de confirmation » et « échec pour une '
              'panne » appellent DEUX réactions opposées — rouvrir le dialogue '
              'vs remonter l\'erreur. Les aplatir forcerait l\'hôte à parser '
              'du texte.');
    });
  });
}
