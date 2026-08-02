// ─────────────────────────────────────────────────────────────────────────────
// CR-IFFD-38 — gardes du patron « état d'affichage pilotable ».
//
// 🔴 Chaque garde MONTE un arbre et mesure un COMPORTEMENT rendu. Aucune ne
// compte des occurrences de texte : l'hôte a livré une garde qui comptait
// `flipCardController:` sur tout `lib/`, **déclarations comprises** — elle
// serait restée verte avec ZÉRO passage réel. On ne mesure donc jamais la
// présence d'un identifiant : on mesure que la commande AGIT.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Composant de référence : il détient un état booléen, l'affiche, le bascule
/// au tap, notifie — et accepte un contrôleur OPTIONNEL.
///
/// C'est le patron appliqué à l'os : ce que la carte de révision fait, sans le
/// reste de la carte.
class _Revealable extends StatefulWidget {
  const _Revealable({this.controller, this.onChanged});

  final ZToggleController? controller;
  final ValueChanged<bool>? onChanged;

  @override
  State<_Revealable> createState() => _RevealableState();
}

class _RevealableState extends State<_Revealable> {
  late final ZDisplayStateBinding<bool> _reveal;

  /// Nombre de builds du composant ENTIER — sert à prouver la granularité.
  int builds = 0;

  @override
  void initState() {
    super.initState();
    _reveal = ZDisplayStateBinding<bool>(consumer: this, initialValue: false)
      ..bind(widget.controller);
    _reveal.listenable.addListener(_notify);
  }

  void _notify() => widget.onChanged?.call(_reveal.value);

  @override
  void didUpdateWidget(covariant _Revealable oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reveal.bind(widget.controller);
  }

  @override
  void dispose() {
    _reveal.listenable.removeListener(_notify);
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    builds++;
    return GestureDetector(
      onTap: () => _reveal.value = !_reveal.value,
      child: ValueListenableBuilder<bool>(
        valueListenable: _reveal.listenable,
        builder: (BuildContext context, bool revealed, Widget? _) =>
            Text(revealed ? 'REPONSE' : 'QUESTION',
                textDirection: TextDirection.ltr),
      ),
    );
  }
}

/// Hôte qui possède le contrôleur DANS UN CHAMP — l'usage légal.
class _LegalHost extends StatefulWidget {
  const _LegalHost({this.onChanged, this.consume = true});

  final ValueChanged<bool>? onChanged;

  /// Si `false`, le contrôleur est créé et **jamais passé** : c'est le cas mort
  /// que la clause 5 doit rendre détectable.
  final bool consume;

  @override
  State<_LegalHost> createState() => _LegalHostState();
}

class _LegalHostState extends State<_LegalHost> with ZDisplayStateOwnerMixin {
  /// Déclencheur de rebuild pour les tests.
  ///
  /// `setState` est `@protected` : l'appeler depuis l'extérieur produit un
  /// `invalid_use_of_protected_member` qui fait **échouer `dart analyze`**
  /// (donc le gate repo-wide). Le rebuild se demande d'ici, pas de dehors.
  void rebuildForTest() => setState(() {});

  late final ZToggleController reveal =
      ZToggleController(owner: this, debugLabel: 'reveal');

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          TextButton(
            onPressed: reveal.toggle,
            child: const Text('COMMANDE'),
          ),
          _Revealable(
            controller: widget.consume ? reveal : null,
            onChanged: widget.onChanged,
          ),
        ],
      );
}

/// Hôte FAUTIF : le contrôleur est créé DANS `build`.
class _BuildHost extends StatefulWidget {
  const _BuildHost();

  @override
  State<_BuildHost> createState() => _BuildHostState();
}

class _BuildHostState extends State<_BuildHost> with ZDisplayStateOwnerMixin {
  /// Déclencheur de rebuild pour les tests.
  ///
  /// `setState` est `@protected` : l'appeler depuis l'extérieur produit un
  /// `invalid_use_of_protected_member` qui fait **échouer `dart analyze`**
  /// (donc le gate repo-wide). Le rebuild se demande d'ici, pas de dehors.
  void rebuildForTest() => setState(() {});

  @override
  Widget build(BuildContext context) {
    // 🔴 LE BUG DE L'HÔTE, reproduit tel quel : une nouvelle instance à chaque
    // build, donc une commande écrasée au rebuild suivant.
    final ZToggleController controller =
        ZToggleController(owner: this, debugLabel: 'dansBuild');
    return _Revealable(controller: controller);
  }
}

Widget _wrap(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Material(child: child),
      ),
    );

void main() {
  group('Clause 1 — SANS contrôleur, comportement STRICTEMENT inchangé', () {
    testWidgets('le composant se gouverne seul au tap', (WidgetTester t) async {
      final List<bool> seen = <bool>[];
      await t.pumpWidget(_wrap(_Revealable(onChanged: seen.add)));

      expect(find.text('QUESTION'), findsOneWidget);
      await t.tap(find.byType(_Revealable));
      await t.pump();

      expect(find.text('REPONSE'), findsOneWidget,
          reason: 'le défaut interne doit rester le comportement actuel');
      expect(seen, <bool>[true],
          reason: 'la notification sortante est CONSERVÉE sans contrôleur');
    });

    testWidgets('sans contrôleur, l\'hôte n\'est PAS déclaré pilote',
        (WidgetTester t) async {
      await t.pumpWidget(_wrap(const _Revealable()));
      final _RevealableState card =
          t.state<_RevealableState>(find.byType(_Revealable));
      expect(card._reveal.isHostControlled, isFalse);
      expect(card._reveal.controller, isNull);
      // Et l'état interne est bien la source lue.
      card._reveal.value = true;
      await t.pump();
      expect(find.text('REPONSE'), findsOneWidget);
    });
  });

  group('Clause 2 — AVEC contrôleur, l\'hôte COMMANDE réellement', () {
    testWidgets('🔴 la commande de l\'hôte change ce qui est RENDU',
        (WidgetTester t) async {
      await t.pumpWidget(_wrap(const _LegalHost()));
      expect(find.text('QUESTION'), findsOneWidget);

      // Mesuré sur l'ARBRE, pas sur une propriété : c'est exactement ce que le
      // bouton « Voir la réponse » de l'hôte doit obtenir.
      await t.tap(find.text('COMMANDE'));
      await t.pump();

      expect(find.text('REPONSE'), findsOneWidget,
          reason: 'commande morte : le bouton de l\'hôte ne fait rien');
      expect(find.text('QUESTION'), findsNothing);
    });

    testWidgets('la commande fonctionne AUSSI en sens inverse (masquer)',
        (WidgetTester t) async {
      // Le 4e site de l'hôte est un bouton « Masquer la réponse » posé par le
      // PARENT sur la face arrière : le retour doit être commandable lui aussi.
      await t.pumpWidget(_wrap(const _LegalHost()));
      await t.tap(find.text('COMMANDE'));
      await t.pump();
      expect(find.text('REPONSE'), findsOneWidget);

      await t.tap(find.text('COMMANDE'));
      await t.pump();
      expect(find.text('QUESTION'), findsOneWidget,
          reason: 'le masquage commandé est le 4e site vif de l\'hôte');
    });
  });

  group('Clause 2bis — le contrôleur est LA SOURCE DE VÉRITÉ', () {
    testWidgets('🔴 aucune divergence après une commande INTERNE',
        (WidgetTester t) async {
      await t.pumpWidget(_wrap(const _LegalHost()));
      final _LegalHostState host =
          t.state<_LegalHostState>(find.byType(_LegalHost));

      // Le geste sur le COMPOSANT doit remonter dans le contrôleur de l'hôte :
      // un miroir interne laisserait `reveal.value == false` alors que la
      // réponse est affichée — la divergence exacte que le contrat interdit.
      await t.tap(find.byType(_Revealable));
      await t.pump();

      expect(find.text('REPONSE'), findsOneWidget);
      expect(host.reveal.value, isTrue,
          reason: 'l\'état du composant a divergé de sa source de vérité');
    });

    testWidgets('🔴 aucune divergence après une commande EXTERNE',
        (WidgetTester t) async {
      await t.pumpWidget(_wrap(const _LegalHost()));
      final _LegalHostState host =
          t.state<_LegalHostState>(find.byType(_LegalHost));

      host.reveal.value = true;
      await t.pump();
      expect(find.text('REPONSE'), findsOneWidget);
      expect(host.reveal.value, isTrue);

      host.reveal.value = false;
      await t.pump();
      expect(find.text('QUESTION'), findsOneWidget);
      expect(host.reveal.value, isFalse);
    });

    testWidgets('un rebuild du composant ne REMET PAS l\'état à sa valeur '
        'initiale', (WidgetTester t) async {
      await t.pumpWidget(_wrap(const _LegalHost()));
      final _LegalHostState host =
          t.state<_LegalHostState>(find.byType(_LegalHost));
      host.reveal.value = true;
      await t.pump();

      // Un rebuild de l'hôte reconstruit `_Revealable` : si le composant
      // copiait la valeur au montage, l'état sauterait ici.
      host.rebuildForTest();
      await t.pump();
      expect(find.text('REPONSE'), findsOneWidget);
    });
  });

  group('Clause 3 — la notification sortante est CONSERVÉE', () {
    testWidgets('🔴 une commande EXTERNE notifie aussi l\'hôte',
        (WidgetTester t) async {
      final List<bool> seen = <bool>[];
      await t.pumpWidget(_wrap(_LegalHost(onChanged: seen.add)));
      final _LegalHostState host =
          t.state<_LegalHostState>(find.byType(_LegalHost));

      host.reveal.value = true;
      await t.pump();
      await t.tap(find.byType(_Revealable));
      await t.pump();

      expect(seen, <bool>[true, false],
          reason: 'la notification ne doit pas être perdue quand l\'hôte '
              'commande : un consommateur tiers (su-4) s\'y fie');
    });
  });

  group('Clause 4 — la POSSESSION HORS `build` est IMPOSÉE', () {
    testWidgets('🔴 un contrôleur créé dans `build` est REFUSÉ au 1er rebuild',
        (WidgetTester t) async {
      await t.pumpWidget(_wrap(const _BuildHost()));
      // Le premier build est toléré (il est indiscernable d'un initState au
      // moment où il se produit) ; c'est le REBUILD qui trahit la création
      // dans `build` — et il arrive toujours.
      t.state<_BuildHostState>(find.byType(_BuildHost)).rebuildForTest();

      await t.pump();
      final Object? error = t.takeException();
      expect(error, isFlutterError,
          reason: 'sans cette garde, on INDUSTRIALISE le bug de l\'hôte : '
              'trois de ses contrôleurs sont créés dans `build`');
      expect('$error', contains('dansBuild'));
      expect('$error', contains('build'));
    });

    testWidgets('la création LÉGALE (champ du State) ne lève rien',
        (WidgetTester t) async {
      await t.pumpWidget(_wrap(const _LegalHost()));
      t.state<_LegalHostState>(find.byType(_LegalHost)).rebuildForTest();
      await t.pump();
      expect(t.takeException(), isNull,
          reason: 'CONTRE-PREUVE : la garde de la clause 4 doit distinguer '
              'possession et création dans `build`, pas tout refuser');
    });
  });

  group('Clause 5 — un contrôleur JAMAIS CONSOMMÉ est détectable', () {
    testWidgets('🔴 possédé mais jamais passé ⇒ signalé au dispose',
        (WidgetTester t) async {
      await t.pumpWidget(_wrap(const _LegalHost(consume: false)));
      final _LegalHostState host =
          t.state<_LegalHostState>(find.byType(_LegalHost));
      expect(host.reveal.wasEverConsumed, isFalse,
          reason: 'c\'est le cas mort mesuré chez l\'hôte : un widget DÉCLARE '
              '`flipCardController` et ne l\'utilise jamais');

      await t.pumpWidget(_wrap(const SizedBox()));
      expect(t.takeException(), isAssertionError,
          reason: 'un contrôleur mort doit se signaler, sinon on ne distingue '
              'plus « bouton inerte » de « bouton non branché »');
    });

    testWidgets('CONTRE-PREUVE — consommé ⇒ rien n\'est signalé',
        (WidgetTester t) async {
      await t.pumpWidget(_wrap(const _LegalHost()));
      final _LegalHostState host =
          t.state<_LegalHostState>(find.byType(_LegalHost));
      expect(host.reveal.wasEverConsumed, isTrue);
      expect(host.reveal.consumerCount, 1);

      await t.pumpWidget(_wrap(const SizedBox()));
      expect(t.takeException(), isNull);
    });
  });

  group('AD-2/SM-1 — la commande ne reconstruit QUE la tranche', () {
    testWidgets('🔴 une commande externe ne rebuild pas le composant entier',
        (WidgetTester t) async {
      await t.pumpWidget(_wrap(const _LegalHost()));
      final _RevealableState card =
          t.state<_RevealableState>(find.byType(_Revealable));
      final int before = card.builds;

      card._reveal.value = true;
      await t.pump();

      expect(find.text('REPONSE'), findsOneWidget);
      expect(card.builds, before,
          reason: 'un `setState` d\'échelle composant est interdit (AD-2) : '
              'seule la tranche du ValueListenableBuilder se reconstruit');
    });
  });

  group('Bascule de contrôleur — pas de fuite, pas de saut d\'état', () {
    testWidgets('débrancher le contrôleur CONSERVE la valeur affichée',
        (WidgetTester t) async {
      final ZToggleController external = ZToggleController(
        owner: _ManualOwner(),
        initialValue: true,
        debugLabel: 'externe',
      );
      addTearDown(external.dispose);

      await t.pumpWidget(_wrap(_Revealable(controller: external)));
      expect(find.text('REPONSE'), findsOneWidget);

      await t.pumpWidget(_wrap(const _Revealable()));
      expect(find.text('REPONSE'), findsOneWidget,
          reason: 'le repli interne doit REPRENDRE la dernière valeur rendue, '
              'jamais rejouer sa valeur initiale');
      expect(external.consumerCount, 0,
          reason: 'le composant doit se débrancher, sinon il fuit');
    });

    testWidgets('le composant ne dispose JAMAIS le contrôleur de l\'hôte',
        (WidgetTester t) async {
      final ZToggleController external =
          ZToggleController(owner: _ManualOwner(), debugLabel: 'externe');
      addTearDown(external.dispose);

      await t.pumpWidget(_wrap(_Revealable(controller: external)));
      await t.pumpWidget(_wrap(const SizedBox()));

      expect(external.isDisposed, isFalse);
      // S'il avait été disposé, cette écriture lèverait.
      external.value = true;
      expect(external.value, isTrue);
    });
  });

  group('ZIndexController — les 3 familles indexées du motif', () {
    test('next/previous bornent l\'index', () {
      final ZIndexController c = ZIndexController(owner: _ManualOwner());
      addTearDown(c.dispose);

      c.previous();
      expect(c.value, 0, reason: 'jamais sous zéro');
      c.next(max: 1);
      expect(c.value, 1);
      c.next(max: 1);
      expect(c.value, 1, reason: 'la borne haute doit tenir');
      c.previous();
      expect(c.value, 0);
    });

    test('ne notifie que sur CHANGEMENT', () {
      final ZIndexController c = ZIndexController(owner: _ManualOwner());
      addTearDown(c.dispose);
      int n = 0;
      c.addListener(() => n++);
      c.value = 3;
      c.value = 3;
      expect(n, 1);
    });
  });
}

/// Propriétaire nu pour les tests d'unité (hors arbre) — il n'applique aucune
/// borne temporelle, et n'est donc PAS un modèle d'usage pour un hôte.
class _ManualOwner implements ZDisplayStateOwner {
  @override
  void zRegisterDisplayState(ZDisplayStateController<Object?> controller) {}
}
