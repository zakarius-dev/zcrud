// CR-MANAGE-VISIBILITY-ROLE — `DynamicEdition.didUpdateWidget` comparait
// `controller`, `fields` et `conditionContext`, mais LISAIT seulement
// `manageVisibility` (`widget.manageVisibility && …`) sans jamais le comparer à
// son ancienne valeur.
//
// ## Le scénario EST atteignable — mesuré, pas supposé
//
// Dans `ZStepperEdition`, la bascule de mode est masquée : la zone d'étape reçoit
// `fields: _stepSpecs(index)`, une liste NEUVE à chaque appel, donc
// `!identical(oldWidget.fields, widget.fields)` est toujours vrai et la voie de
// rebind complet passe. Mais `manageVisibility` est un **paramètre public** de
// `DynamicEdition` : tout hôte direct qui le bascule sur un catalogue `const`
// (identité stable) atteint le défaut. C'est ce que montent ces gardes.
//
// ## Les deux moitiés du défaut
//
//  - `true → false` : les listeners de garde restaient ABONNÉS et
//    `_onGuardChanged`/`_onReseed` appellent `_recomputeVisibility()` **sans**
//    consulter `manageVisibility` ⇒ la zone continuait d'ÉCRIRE `visibleFields`
//    en mode passif. **Deux écrivains** — ce que l'architecture interdit ;
//  - `false → true` : aucun abonnement n'était posé et aucun recalcul n'avait
//    lieu ⇒ la zone se déclarait pilote sans jamais piloter (fenêtre inerte).
//
// ## Structurel vs visuel (règle v0.68.0, appliquée ici)
//
// `manageVisibility` est **STRUCTUREL** : il décide si cette zone est un
// ÉCRIVAIN de `visibleFields` et quel jeu de `Listenable` est abonné. Il est
// donc invalidant. Ce qui reste **VISUEL** (padding, physics, gutter, …) ne
// réabonne rien et ne republie rien — garde V5.
//
// Le correctif est **discriminant** : sur un simple changement de rôle il
// réabonne les DEUX canaux qui en dépendent (`_bindGuards`, `_bindReseed`) et
// recalcule si la zone devient pilote — mais il NE recrée PAS le
// `ZDerivationEngine` (`_bindDerivations`, qui ne dépend que de `fields`) et ne
// reconstruit pas les index.
//
// ## Les six gardes
//
//  - V1 : `true → false` ⇒ ZÉRO écriture (une seule zone pilote) ;
//  - V2 : `false → true` ⇒ recalcul à la bascule PUIS réactivité aux gardes ;
//  - V3 : passage de témoin entre deux zones ⇒ exactement UNE publication ;
//  - V4 : aller-retour de rôle ⇒ ZÉRO doublon d'abonnement (compte de PASSES) ;
//  - V5 : canal VISUEL ⇒ zéro recalcul (SM-1) ;
//  - V6 : 100 frappes sur un champ non-garde ⇒ zéro recalcul (SM-1).
//
// 🔴 V1 et V3 gardent l'invariant single-writer par « une seule zone pilote »
// ET « zéro doublon » (V4), pas par « la fenêtre est correcte » — une fenêtre
// juste peut l'être par hasard, le COMPTE ne peut pas.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

// ── Catalogue `const` : l'identité de la liste NE CHANGE PAS entre deux builds.
// 🔴 C'est la condition même du défaut ; une liste reconstruite le masquerait.
const _fieldsA = <ZFieldSpec>[
  ZFieldSpec(name: 'g', type: EditionFieldType.text, label: 'Garde'),
  ZFieldSpec(name: 'a1', type: EditionFieldType.text, label: 'A1'),
  ZFieldSpec(
    name: 'aX',
    type: EditionFieldType.text,
    label: 'AX',
    condition: ZCondition.equals('g', 'yes'),
  ),
];

const _fieldsB = <ZFieldSpec>[
  ZFieldSpec(name: 'b1', type: EditionFieldType.text, label: 'B1'),
  ZFieldSpec(
    name: 'bX',
    type: EditionFieldType.text,
    label: 'BX',
    condition: ZCondition.equals('g', 'yes'),
  ),
];

/// Sentinelle écrite par « l'autre écrivain » (le racine, dans la vraie vie) :
/// si la zone passive republie, la sentinelle DISPARAÎT.
const _sentinel = <String>['g', 'a1', 'aX', 'sentinelle-du-racine'];

/// Controller INSTRUMENTÉ : compte les lectures de tranche faites par
/// `evaluateZCondition`, donc le nombre de PASSES de `_recomputeVisibility`.
///
/// 🔴 Pourquoi ce compteur existe — c'est MESURÉ, pas décoratif : une garde qui
/// se contentait de compter les publications de `visibleFields` restait VERTE
/// sous une injection rendant le rebind NON discriminant (recalcul sur tout
/// changement de widget). Cause : `setVisibleFields` est **no-op si l'ensemble
/// est inchangé** — le repli rendait la valeur attendue par hasard. Le travail
/// doit donc être mesuré à la source, pas à sa sortie.
class _CountingController extends ZFormController {
  _CountingController()
      : super(
          initialValues: const <String, Object?>{'g': 'no', 'a1': '', 'aX': ''},
          visibleFields: const <String>['g', 'a1', 'aX'],
        );

  int reads = 0;

  @override
  Object? valueOf(String name) {
    reads++;
    return super.valueOf(name);
  }
}

_CountingController _controller() => _CountingController();

Widget _oneZone({
  required ZFormController controller,
  required bool manage,
  EdgeInsetsGeometry? padding,
}) =>
    MaterialApp(
      home: Scaffold(
        body: ZcrudScope(
          child: DynamicEdition(
            controller: controller,
            fields: _fieldsA,
            manageVisibility: manage,
            padding: padding,
          ),
        ),
      ),
    );

Widget _twoZones({
  required ZFormController controller,
  required bool manageA,
  required bool manageB,
}) =>
    MaterialApp(
      home: Scaffold(
        body: ZcrudScope(
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                DynamicEdition(
                  key: const ValueKey<String>('zoneA'),
                  controller: controller,
                  fields: _fieldsA,
                  manageVisibility: manageA,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                ),
                DynamicEdition(
                  key: const ValueKey<String>('zoneB'),
                  controller: controller,
                  fields: _fieldsB,
                  manageVisibility: manageB,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                ),
              ],
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets(
      'V1 — `true → false` : la zone CESSE d\'écrire `visibleFields` '
      '(single-writer : zéro écriture en mode passif)', (tester) async {
    final c = _controller();
    addTearDown(c.dispose);

    await tester.pumpWidget(_oneZone(controller: c, manage: true));
    await tester.pump();

    // La zone bascule PASSIVE — même controller, MÊME identité de `fields`.
    await tester.pumpWidget(_oneZone(controller: c, manage: false));
    await tester.pump();

    // « L'autre écrivain » (racine) publie sa fenêtre.
    c.setVisibleFields(_sentinel);
    var writes = 0;
    void count() => writes++;
    c.visibleFields.addListener(count);
    addTearDown(() => c.visibleFields.removeListener(count));

    // Un champ de GARDE change : une zone passive ne doit RIEN republier.
    c.setValue('g', 'yes');
    await tester.pump();

    expect(writes, 0, reason: 'une zone passive ne doit pas écrire la fenêtre');
    expect(c.visibleFields.value, _sentinel);
  });

  testWidgets(
      'V2 — `false → true` : la zone DEVIENT pilote (recalcul à la bascule, '
      'puis réactivité aux gardes)', (tester) async {
    final c = _controller();
    addTearDown(c.dispose);

    await tester.pumpWidget(_oneZone(controller: c, manage: false));
    await tester.pump();
    // Zone passive : la fenêtre initiale de l'hôte est intacte (`aX` visible
    // alors que sa condition est fausse — personne ne l'a filtrée).
    expect(c.visibleFields.value, <String>['g', 'a1', 'aX']);

    // Bascule ACTIVE, sans changement de controller ni de `fields`.
    await tester.pumpWidget(_oneZone(controller: c, manage: true));
    await tester.pump();

    // Recalcul immédiat : `aX` est masqué (condition fausse).
    expect(c.visibleFields.value, <String>['g', 'a1']);

    // …et la zone est bien ABONNÉE : un changement de garde la fait réagir.
    c.setValue('g', 'yes');
    await tester.pump();
    expect(c.visibleFields.value, <String>['g', 'a1', 'aX']);
  });

  testWidgets(
      'V3 — passage de témoin entre DEUX zones : UN SEUL écrivain, '
      'ZÉRO doublon (exactement une écriture par changement de garde)',
      (tester) async {
    final c = _controller();
    addTearDown(c.dispose);

    // A pilote, B passif.
    await tester
        .pumpWidget(_twoZones(controller: c, manageA: true, manageB: false));
    await tester.pump();
    expect(c.visibleFields.value, <String>['g', 'a1']);

    // Passage de témoin : A devient passif, B devient pilote.
    await tester
        .pumpWidget(_twoZones(controller: c, manageA: false, manageB: true));
    await tester.pump();

    var writes = 0;
    void count() => writes++;
    c.visibleFields.addListener(count);
    addTearDown(() => c.visibleFields.removeListener(count));

    c.setValue('g', 'yes');
    await tester.pump();

    // 🔴 Le COMPTE est l'invariant, pas la valeur : deux écrivains produiraient
    // deux publications successives (A puis B) et la fenêtre finale pourrait
    // être « juste par hasard ». Un seul écrivain ⇒ exactement une.
    expect(writes, 1, reason: 'un seul écrivain doit publier la fenêtre');
    expect(c.visibleFields.value, <String>['b1', 'bX']);
  });

  testWidgets(
      'V4 — aller-retour `true → false → true` : ZÉRO doublon d\'abonnement '
      '(le nombre de PASSES de recalcul est celui d\'une zone jamais basculée)',
      (tester) async {
    // ── Référence : une zone montée ACTIVE et jamais basculée. On mesure le
    // coût d'UNE passe de recalcul déclenchée par un changement de garde.
    final ref = _controller();
    addTearDown(ref.dispose);
    await tester.pumpWidget(_oneZone(controller: ref, manage: true));
    await tester.pump();
    final refBefore = ref.reads;
    ref.setValue('g', 'yes');
    await tester.pump();
    final perPass = ref.reads - refBefore;
    // Sanity : la référence mesure bien QUELQUE CHOSE (sinon la comparaison
    // ci-dessous serait `0 == 0`, une tautologie).
    expect(perPass, greaterThan(0));

    // ── Sujet : la MÊME zone après un aller-retour de rôle.
    final c = _controller();
    addTearDown(c.dispose);
    await tester.pumpWidget(_oneZone(controller: c, manage: true));
    await tester.pump();
    await tester.pumpWidget(_oneZone(controller: c, manage: false));
    await tester.pump();
    await tester.pumpWidget(_oneZone(controller: c, manage: true));
    await tester.pump();

    var writes = 0;
    void count() => writes++;
    c.visibleFields.addListener(count);
    addTearDown(() => c.visibleFields.removeListener(count));
    final before = c.reads;

    c.setValue('g', 'yes');
    await tester.pump();

    // 🔴 ZÉRO DOUBLON : un abonnement resté en place derrière la bascule ferait
    // recalculer DEUX fois. Le compte de publications ne le verrait PAS
    // (`setVisibleFields` est no-op au 2ᵉ passage) — mesuré sous injection.
    expect(c.reads - before, perPass,
        reason: 'un seul abonnement de garde doit subsister');
    expect(writes, 1);
    expect(c.visibleFields.value, <String>['g', 'a1', 'aX']);
  });

  testWidgets(
      'V5 — SM-1 : un changement purement VISUEL ne republie RIEN et ne '
      'reconstruit aucun champ non concerné', (tester) async {
    final c = _controller();
    addTearDown(c.dispose);

    await tester.pumpWidget(_oneZone(controller: c, manage: true));
    await tester.pump();

    var writes = 0;
    void count() => writes++;
    c.visibleFields.addListener(count);
    addTearDown(() => c.visibleFields.removeListener(count));
    final readsBefore = c.reads;

    // Seul `padding` change : même controller, mêmes `fields`, MÊME rôle.
    await tester.pumpWidget(
      _oneZone(controller: c, manage: true, padding: const EdgeInsets.all(4)),
    );
    await tester.pump();

    // 🔴 L'assertion PORTANTE est celle du TRAVAIL (`reads`), pas celle de la
    // sortie (`writes`) : `setVisibleFields` étant no-op à ensemble inchangé,
    // un recalcul à l'aveugle laisserait `writes` à 0 tout en refaisant tout.
    expect(c.reads - readsBefore, 0,
        reason: 'un canal visuel ne doit RIEN recalculer');
    expect(writes, 0, reason: 'un canal visuel n\'invalide pas la fenêtre');
  });

  testWidgets(
      'V6 — SM-1 : sous un rôle INCHANGÉ, 100 frappes ne reconstruisent que le '
      'champ courant et ne republient jamais la fenêtre', (tester) async {
    final c = _controller();
    addTearDown(c.dispose);

    final builds = <String, int>{};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ZcrudScope(
            child: DynamicEdition(
              controller: c,
              fields: _fieldsA,
              fieldBuilder: (context, ctrl, field) {
                builds[field.name] = (builds[field.name] ?? 0) + 1;
                return ZFieldWidget(controller: ctrl, field: field);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    var writes = 0;
    void count() => writes++;
    c.visibleFields.addListener(count);
    addTearDown(() => c.visibleFields.removeListener(count));

    builds.clear();
    final readsBefore = c.reads;
    for (var i = 0; i < 100; i++) {
      c.setValue('a1', 'x' * (i + 1));
    }
    await tester.pump();

    // Objectif produit n°1 : 100 frappes sur un champ NON garde ne déclenchent
    // AUCUNE passe de recalcul (mesuré à la source, cf. `_CountingController`).
    expect(c.reads - readsBefore, 0,
        reason: 'une frappe ne doit déclencher aucun recalcul de visibilité');
    expect(writes, 0, reason: 'une frappe ne republie jamais la fenêtre');
    expect(builds['g'] ?? 0, 0, reason: 'aucun rebuild du champ voisin');
    expect(builds['aX'] ?? 0, 0, reason: 'aucun rebuild du champ conditionnel');
  });
}
