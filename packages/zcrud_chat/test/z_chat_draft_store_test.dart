/// LE BROUILLON PERSISTANT — le port, et ce que le socle en fait.
///
/// Deux choses portent le mot « brouillon » et ne se confondent jamais :
/// le brouillon **transporté** (`ZChatDraft`, la valeur qu'un verbe passe,
/// en mémoire, le temps d'un geste) et le brouillon **persisté** (la même
/// valeur, confiée à `ZChatDraftStore` sous une identité de conversation).
/// Ce fichier mesure le second, et le pont entre les deux.
///
/// * **DRF-I** — INERTIE : sans port, rien ne se passe et rien ne lève.
///   Mesuré en ABSOLU (des valeurs, pas une comparaison d'arbres).
/// * **DRF-S** — ALLER-RETOUR : la saisie quittée est confiée au port, et
///   retrouvée au retour dans la conversation.
/// * 🔴 **DRF-O** — UNE SAISIE EN COURS L'EMPORTE : ni au départ, ni PENDANT
///   la lecture du port, un brouillon enregistré n'écrase ce qu'on tape.
/// * **DRF-E** — ÉDITION : le champ d'une édition active n'est pas écrasé.
/// * **DRF-C** — ENVOI : ce qui a été soumis ne ressuscite pas.
/// * **DRF-X** — PANNE : un `Left` comme une exception laissent la saisie
///   intacte, sans annonce et sans lever (AD-10).
/// * **DRF-N** — L'INDICATEUR : muet à `false` ; à `true`, annoncé, avec une
///   cible ≥ 48 dp qui éteint l'indication SANS toucher au texte.
@TestOn('vm')
library;

import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';

const Color _cursor = Color(0xFF123456);

/// Store dont la LECTURE est suspendue par le test — c'est la fenêtre où
/// l'utilisateur tape pendant que le stockage répond.
class _SlowDraftStore implements ZChatDraftStore {
  _SlowDraftStore(this._stored);

  final Map<String, ZChatDraft> _stored;

  /// Ouvert par le test : tant qu'il n'est pas complété, `read` attend.
  Completer<ZChatDraft?>? gate;

  /// Nombre de LECTURES reçues — un port qu'on n'a pas à consulter ne doit
  /// pas l'être.
  int reads = 0;

  @override
  Future<ZResult<ZChatDraft?>> read(String conversationId) async {
    reads++;
    // La valeur est saisie À L'APPEL, comme le ferait un vrai support : ce
    // qui est écrit pendant que la requête vole ne change pas ce qu'elle
    // rapporte. Sans cela, une écriture concurrente masquerait la course que
    // ce fichier existe pour mesurer.
    final ZChatDraft? snapshot = _stored[conversationId];
    final Completer<ZChatDraft?>? g = gate;
    if (g != null) {
      await g.future;
      gate = null;
    }
    return Right<ZFailure, ZChatDraft?>(snapshot);
  }

  @override
  Future<ZResult<Unit>> write(String conversationId, ZChatDraft draft) async {
    if (draft.text.isEmpty && draft.attachmentIds.isEmpty) {
      _stored.remove(conversationId);
    } else {
      _stored[conversationId] = draft;
    }
    return const Right<ZFailure, Unit>(unit);
  }

  @override
  Future<ZResult<Unit>> clear(String conversationId) async {
    _stored.remove(conversationId);
    return const Right<ZFailure, Unit>(unit);
  }
}

/// Store en PANNE — il rend un `Left` sur les trois membres.
class _FailingDraftStore implements ZChatDraftStore {
  @override
  Future<ZResult<ZChatDraft?>> read(String conversationId) async =>
      Left<ZFailure, ZChatDraft?>(const ZCacheFailure('panne'));

  @override
  Future<ZResult<Unit>> write(String conversationId, ZChatDraft draft) async =>
      Left<ZFailure, Unit>(const ZCacheFailure('panne'));

  @override
  Future<ZResult<Unit>> clear(String conversationId) async =>
      Left<ZFailure, Unit>(const ZCacheFailure('panne'));
}

/// Store FAUTIF — il LÈVE, ce que son contrat interdit. Le socle appelle
/// certains de ses membres sans les attendre : une exception y deviendrait
/// une erreur asynchrone non rattrapée, donc un plantage loin de sa cause.
class _ThrowingDraftStore implements ZChatDraftStore {
  @override
  Future<ZResult<ZChatDraft?>> read(String conversationId) async =>
      throw StateError('boum');

  @override
  Future<ZResult<Unit>> write(String conversationId, ZChatDraft draft) async =>
      throw StateError('boum');

  @override
  Future<ZResult<Unit>> clear(String conversationId) async =>
      throw StateError('boum');
}

void main() {
  group('🔴 DRF-I — INERTIE : aucun port', () {
    test('sans store : rien n\'est annoncé, rien n\'est restitué, rien ne '
        'lève', () async {
      final rig = buildController(conversationId: 'c-a');
      addTearDown(rig.controller.dispose);

      expect(rig.controller.persistsDraft, isFalse,
          reason: '🔴 un hôte qui n\'a déclaré aucun store est traité comme '
              's\'il en avait un : l\'assemblé monterait un rang muet');
      expect(rig.controller.draftRestored.value, isFalse);

      rig.controller.composer.text = 'à moi';
      rig.controller.attach(conversationId: 'c-b');
      await pumpEventQueue();
      rig.controller.attach(conversationId: 'c-a');
      await pumpEventQueue();

      // ABSOLU : le champ est VIDE et l'indicateur est ÉTEINT — pas
      // « comme avant », des valeurs.
      expect(rig.controller.composer.text, '',
          reason: '🔴 le socle a conservé un brouillon LUI-MÊME : la '
              'persistance a cessé d\'être une décision d\'hôte');
      expect(rig.controller.draftRestored.value, isFalse);
      expect(await rig.controller.restoreDraft(), isFalse);
      await rig.controller.saveDraft();
    });
  });

  group('DRF-S — ALLER-RETOUR par le port', () {
    test('la saisie quittée est confiée au port et retrouvée au retour',
        () async {
      final Map<String, ZChatDraft> shelf = <String, ZChatDraft>{};
      final rig = buildController(
        conversationId: 'c-a',
        draftStore: _SlowDraftStore(shelf),
      );
      addTearDown(rig.controller.dispose);

      rig.controller.composer.text = 'brouillon de A';
      rig.controller.attach(conversationId: 'c-b');
      await pumpEventQueue();

      expect(shelf['c-a']?.text, 'brouillon de A',
          reason: '🔴 le changement de conversation a EFFACÉ la saisie au '
              'lieu de la confier au port');
      expect(rig.controller.composer.text, '',
          reason: '🔴 le brouillon de A a suivi dans B');

      rig.controller.attach(conversationId: 'c-a');
      await pumpEventQueue();

      expect(rig.controller.composer.text, 'brouillon de A',
          reason: '🔴 le retour dans la conversation ne restitue rien');
      expect(rig.controller.draftRestored.value, isTrue,
          reason: '🔴 la restitution n\'est PAS annoncée : le texte réapparu '
              'est indiscernable d\'un texte tapé');
    });

    test('saveDraft confie la saisie à la demande', () async {
      final Map<String, ZChatDraft> shelf = <String, ZChatDraft>{};
      final rig = buildController(
        conversationId: 'c-a',
        draftStore: _SlowDraftStore(shelf),
      );
      addTearDown(rig.controller.dispose);

      rig.controller.composer.text = 'à sauver';
      await rig.controller.saveDraft();

      expect(shelf['c-a']?.text, 'à sauver',
          reason: '🔴 `saveDraft` n\'écrit pas : un hôte n\'a aucun moyen de '
              'conserver la saisie à la mise en arrière-plan');
    });
  });

  group('🔴 DRF-O — une SAISIE EN COURS l\'emporte', () {
    test('champ déjà occupé à l\'entrée : le port n\'est même pas consulté',
        () async {
      final _SlowDraftStore store = _SlowDraftStore(<String, ZChatDraft>{
        'c-a': const ZChatDraft(text: 'vieux brouillon'),
      });
      final rig = buildController(conversationId: 'c-a', draftStore: store);
      addTearDown(rig.controller.dispose);

      rig.controller.composer.text = 'ce que je tape';
      expect(await rig.controller.restoreDraft(), isFalse);
      expect(rig.controller.composer.text, 'ce que je tape',
          reason: '🔴 un brouillon enregistré a ÉCRASÉ une saisie en cours');
      expect(rig.controller.draftRestored.value, isFalse);
      // 🔬 Ce que le contrôle d'ENTRÉE apporte, et que le contrôle d'après
      // l'attente ne peut pas donner : la lecture N'A PAS LIEU. Sans cette
      // mesure, les deux contrôles seraient redondants et retirer celui
      // d'entrée laisserait la garde verte.
      expect(store.reads, 0,
          reason: '🔴 le port est interrogé alors que le champ est occupé : '
              'une lecture inutile à chaque geste');
    });

    test('frappe PENDANT la lecture du port : la frappe gagne', () async {
      final _SlowDraftStore store = _SlowDraftStore(<String, ZChatDraft>{
        'c-a': const ZChatDraft(text: 'vieux brouillon'),
      });
      final rig = buildController(
        conversationId: 'c-a',
        draftStore: store,
      );
      addTearDown(rig.controller.dispose);

      // Le champ est LIBRE au moment de l'appel : un contrôle fait seulement
      // à l'entrée laisserait passer ce cas. La frappe survient pendant que
      // le stockage répond — c'est la fenêtre réelle sur un vrai support.
      store.gate = Completer<ZChatDraft?>();
      final Future<bool> restoring = rig.controller.restoreDraft();
      rig.controller.composer.text = 'ce que je tape';
      store.gate!.complete(null);

      expect(await restoring, isFalse);
      expect(rig.controller.composer.text, 'ce que je tape',
          reason: '🔴 le brouillon relu a écrasé une frappe survenue PENDANT '
              'la lecture : le contrôle n\'est fait qu\'à l\'entrée');
      expect(rig.controller.draftRestored.value, isFalse);
    });

    test('changement de conversation PENDANT la lecture : rien n\'est posé '
        'dans la nouvelle', () async {
      final _SlowDraftStore store = _SlowDraftStore(<String, ZChatDraft>{
        'c-a': const ZChatDraft(text: 'brouillon de A'),
      });
      final rig = buildController(conversationId: 'c-a', draftStore: store);
      addTearDown(rig.controller.dispose);

      store.gate = Completer<ZChatDraft?>();
      // La lecture de A part AVANT la bascule : elle rapportera « brouillon
      // de A » alors que le champ affiché est celui de B.
      final Future<bool> restoring = rig.controller.restoreDraft();
      rig.controller.attach(conversationId: 'c-b');
      store.gate!.complete(null);

      expect(await restoring, isFalse);
      await pumpEventQueue();
      expect(rig.controller.composer.text, '',
          reason: '🔴 le brouillon de A a été posé dans le champ de B');
    });
  });

  group('DRF-E — une ÉDITION active n\'est pas écrasée', () {
    test('restoreDraft refuse pendant une édition', () async {
      final rig = buildController(
        conversationId: 'c-a',
        draftStore: _SlowDraftStore(<String, ZChatDraft>{
          'c-a': const ZChatDraft(text: 'vieux brouillon'),
        }),
      );
      addTearDown(rig.controller.dispose);

      rig.controller.startEditing(messageId: 'm1', originalText: 'le message');
      expect(await rig.controller.restoreDraft(), isFalse);
      expect(rig.controller.composer.text, 'le message',
          reason: '🔴 un brouillon a écrasé le message qu\'on modifie');
    });
  });

  group('DRF-C — ce qui a été SOUMIS ne ressuscite pas', () {
    test('après envoi, le port n\'a plus rien pour la conversation', () async {
      final Map<String, ZChatDraft> shelf = <String, ZChatDraft>{
        'c-a': const ZChatDraft(text: 'vieux brouillon'),
      };
      final rig = buildController(
        conversationId: 'c-a',
        draftStore: _SlowDraftStore(shelf),
      );
      addTearDown(rig.controller.dispose);

      rig.controller.composer.text = 'ma question';
      final Future<ZResult<ZChatRequestToken>> sent = rig.controller.send();
      await pumpEventQueue();

      expect(shelf.containsKey('c-a'), isFalse,
          reason: '🔴 le brouillon survit à son envoi : il réapparaîtra sous '
              'le message qu\'il vient de produire');
      expect(rig.controller.draftRestored.value, isFalse);

      rig.port.last.add(done());
      await rig.port.closeAll();
      await sent;
    });
  });

  group('DRF-X — PANNE du stockage', () {
    test('un Left laisse la saisie intacte et n\'annonce rien', () async {
      final rig = buildController(
        conversationId: 'c-a',
        draftStore: _FailingDraftStore(),
      );
      addTearDown(rig.controller.dispose);

      expect(await rig.controller.restoreDraft(), isFalse);
      expect(rig.controller.composer.text, '');
      expect(rig.controller.draftRestored.value, isFalse,
          reason: '🔴 une panne de stockage annonce une restitution qui n\'a '
              'pas eu lieu');
      await rig.controller.saveDraft();
    });

    test('un store qui LÈVE ne fait lever ni le geste, ni le changement de '
        'conversation', () async {
      final rig = buildController(
        conversationId: 'c-a',
        draftStore: _ThrowingDraftStore(),
      );
      addTearDown(rig.controller.dispose);

      expect(await rig.controller.restoreDraft(), isFalse);
      await rig.controller.saveDraft();

      rig.controller.composer.text = 'à moi';
      rig.controller.attach(conversationId: 'c-b');
      await pumpEventQueue();

      expect(rig.controller.composer.text, '',
          reason: '🔴 le changement de conversation a été interrompu par une '
              'exception du store');
    });
  });

  group('🔴 DRF-N — L\'INDICATEUR', () {
    testWidgets('muet tant que rien n\'a été restitué', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<bool> slice = ValueNotifier<bool>(false);
      addTearDown(slice.dispose);

      await tester.pumpWidget(
        harness(
          ZChatComposerDraftNotice(restored: slice, onDismiss: () {}),
        ),
      );

      // ABSOLU : zéro hauteur — c'est ce qu'un rang prend au champ.
      expect(
        tester.getSize(find.byType(ZChatComposerDraftNotice)).height,
        0,
        reason: '🔴 l\'indicateur occupe le cadre alors qu\'il n\'a rien à '
            'annoncer (AD-4)',
      );
      expect(find.text('Brouillon restauré'), findsNothing);
    });

    testWidgets(
      'annoncé, et son geste éteint l\'indication SANS toucher au texte',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        final rig = buildController();
        addTearDown(rig.controller.dispose);
        final ValueNotifier<bool> slice = ValueNotifier<bool>(true);
        addTearDown(slice.dispose);
        rig.controller.composer.text = 'texte restitué';

        await tester.pumpWidget(
          harness(
            ZChatComposer(
              controller: rig.controller,
              cursorColor: _cursor,
              status: (BuildContext context, ZChatComposerSlot slot) =>
                  ZChatComposerDraftNotice(
                    restored: slice,
                    onDismiss: () {
                      slice.value = false;
                      rig.controller.dismissRestoredDraft();
                    },
                  ),
            ),
          ),
        );

        expect(
          findSemantics(
            tester,
            (SemanticsNode n) =>
                n.label == 'Brouillon restauré' &&
                n.flagsCollection.isLiveRegion,
          ),
          isNotNull,
          reason: '🔴 la restitution n\'est que VISIBLE : un lecteur d\'écran '
              'ne l\'annonce pas (AD-13)',
        );

        final Size target = tester.getSize(
          find
              .ancestor(
                of: find.text('Masquer l\'indication'),
                matching: find.byType(GestureDetector),
              )
              .first,
        );
        expect(target.height, greaterThanOrEqualTo(48 - 0.5),
            reason: '🔴 cible sous le plancher tactile de 48 dp (AD-13)');

        await tester.tap(find.text('Masquer l\'indication'));
        await tester.pump();

        expect(find.text('Brouillon restauré'), findsNothing);
        expect(rig.controller.composer.text, 'texte restitué',
            reason: '🔴 le geste « j\'ai vu » a EFFACÉ la saisie qu\'il '
                'venait d\'annoncer');
        handle.dispose();
      },
    );
  });
}
