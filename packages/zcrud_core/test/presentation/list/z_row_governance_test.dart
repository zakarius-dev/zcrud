// Gouvernance PAR LIGNE : `ZRowAclResolver` / `ZRowPermissions` /
// `ZRowAction.enabledFor`.
//
// 🔴 GARDE CENTRALE — RESTREINDRE, JAMAIS ÉLARGIR. Un résolveur de ligne est
// du code métier de l'application : s'il pouvait rouvrir un geste que l'ACL
// refuse, il deviendrait une voie de contournement des droits. La composition
// DOIT être une intersection. Toutes les autres garanties de ce fichier n'ont
// de valeur que si celle-là tient.
//
// Les besoins historiques du moteur remplacé (ACL par item, `readOnly` par
// item, `canBeDeleted` par item, `toBeValidated` par item) sont ici réécrits
// avec le SEUL résolveur, un test par besoin.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsProperties;
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

class _Piece extends ZEntity {
  const _Piece(
    this._id,
    this.name, {
    this.closed = false,
    this.validated = false,
    this.protected = false,
  });
  final String _id;
  final String name;

  /// Exercice clôturé : la ligne ne s'écrit plus (`readOnly` par item).
  final bool closed;

  /// Déjà validée : « valider » n'a plus de sens (`toBeValidated` par item).
  final bool validated;

  /// Pièce protégée : la suppression lui est refusée (`canBeDeleted`).
  final bool protected;

  @override
  String? get id => _id;
}

/// ACL d'écran refusant les actions de [denied] ; autorise le reste.
class _DenyAcl implements ZAcl {
  const _DenyAcl(this.denied);
  final Set<ZCrudAction> denied;
  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) =>
      !denied.contains(action);
}

const _fields = <ZFieldSpec>[
  ZFieldSpec(name: 'name', type: EditionFieldType.text),
];

const _pieces = <_Piece>[
  _Piece('1', 'Alice'),
  _Piece('2', 'Bob', closed: true, validated: true, protected: true),
];

final List<ZListRow> _rows = <ZListRow>[
  for (final _Piece p in _pieces)
    ZListRow(id: p.id!, cells: <String, Object?>{'name': p.name}),
];

_Piece? _entityFor(ZListRow row) {
  for (final _Piece p in _pieces) {
    if (p.id == row.id) return p;
  }
  return null;
}

Widget _harness({
  required ZAcl acl,
  required List<ZRowAction<_Piece>> actions,
  ZRowAclResolver<_Piece>? rowAcl,
  ZActionAclMode mode = ZActionAclMode.hide,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ZcrudScope(
        acl: acl,
        child: DynamicList<_Piece>.rows(
          _fields,
          _rows,
          layout: ZListBuilderLayout(
            itemBuilder: (BuildContext context, ZListRow row,
                    List<ZListColumn> columns) =>
                Text('cell-${row.cells['name']}'),
          ),
          rowActions: actions,
          entityFor: _entityFor,
          rowAcl: rowAcl,
          actionAclMode: mode,
        ),
      ),
    ),
  );
}

/// Propriétés sémantiques du bouton d'action portant [text], pour la ligne
/// d'index [index] (les lignes sont rendues dans l'ordre de `_pieces`).
///
/// Le noeud visé est celui que POSE le socle (`Semantics(button: true,
/// label: …)`) — pas ceux que le bouton Material crée pour lui-même, qui ne
/// portent pas de libellé.
SemanticsProperties _actionSemantics(
  WidgetTester tester,
  String text,
  int index,
) {
  final Finder finder = find.byWidgetPredicate(
    (Widget w) =>
        w is Semantics &&
        w.properties.button == true &&
        w.properties.label == text,
  );
  return tester.widgetList<Semantics>(finder).elementAt(index).properties;
}

void main() {
  // ── 🔴 La garde qui tient tout le reste ─────────────────────────────────
  group('intersection, jamais union', () {
    testWidgets(
        'résolveur TOTALEMENT permissif + ACL refusant delete ⇒ suppression '
        'RESTE refusée', (WidgetTester tester) async {
      var invoked = 0;
      await tester.pumpWidget(
        _harness(
          acl: const _DenyAcl(<ZCrudAction>{ZCrudAction.delete}),
          // Le résolveur le plus permissif exprimable : il ne retire RIEN.
          rowAcl: (_Piece piece) => const ZRowPermissions.unrestricted(),
          mode: ZActionAclMode.disable,
          actions: <ZRowAction<_Piece>>[
            ZRowAction<_Piece>(
              id: 'delete',
              labelKey: 'delete',
              requiredPermission: ZCrudAction.delete,
              onInvoke: (BuildContext context, _Piece piece) => invoked++,
            ),
          ],
        ),
      );
      // Rendue (mode `disable`) mais INERTE, sur les deux lignes.
      expect(find.text('Delete'), findsNWidgets(2));
      expect(_actionSemantics(tester, 'Delete', 0).enabled, isFalse);
      await tester.tap(find.text('Delete').first);
      await tester.pump();
      expect(invoked, 0, reason: 'un droit refusé en amont ne se rouvre pas');
    });

    testWidgets(
        'résolveur permissif + ACL refusant delete, mode hide ⇒ action ABSENTE',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _harness(
          acl: const _DenyAcl(<ZCrudAction>{ZCrudAction.delete}),
          rowAcl: (_Piece piece) => const ZRowPermissions.unrestricted(),
          actions: <ZRowAction<_Piece>>[
            ZRowAction<_Piece>(
              id: 'delete',
              labelKey: 'delete',
              requiredPermission: ZCrudAction.delete,
              onInvoke: (BuildContext context, _Piece piece) {},
            ),
          ],
        ),
      );
      expect(find.text('Delete'), findsNothing);
    });

    test('le vocabulaire de ZRowPermissions ne peut pas ACCORDER un droit', () {
      // Toute instance, quelle qu'elle soit, ne fait que retirer : la valeur
      // la plus permissive est la neutre.
      const ZRowPermissions neutre = ZRowPermissions.unrestricted();
      expect(neutre.restrictsNothing, isTrue);
      for (final ZCrudAction action in ZCrudAction.values) {
        expect(neutre.admits(action), isTrue);
        // Une restriction ne s'annule jamais d'elle-même.
        expect(
          ZRowPermissions.denying(<ZCrudAction>{action}).admits(action),
          isFalse,
        );
      }
    });
  });

  // ── Rendu d'une action inéligible ───────────────────────────────────────
  group('action inéligible : rendue, inerte, motivée', () {
    testWidgets('enabledFor faux ⇒ présente, Semantics(enabled: false), et '
        'AUCUN appel du handler', (WidgetTester tester) async {
      var invoked = 0;
      await tester.pumpWidget(
        _harness(
          acl: const ZAllowAllAcl(),
          actions: <ZRowAction<_Piece>>[
            ZRowAction<_Piece>(
              id: 'validate',
              labelKey: 'validate',
              requiredPermission: ZCrudAction.validate,
              onInvoke: (BuildContext context, _Piece piece) => invoked++,
              // Ligne 2 déjà validée : l'action ne s'y applique pas.
              enabledFor: (_Piece piece) => !piece.validated,
            ),
          ],
        ),
      );
      // Rendue sur les DEUX lignes : l'inéligibilité ne masque jamais.
      expect(find.text('validate'), findsNWidgets(2));
      expect(_actionSemantics(tester, 'validate', 0).enabled, isTrue);
      expect(_actionSemantics(tester, 'validate', 1).enabled, isFalse);
      await tester.tap(find.text('validate').at(1));
      await tester.pump();
      expect(invoked, 0, reason: 'une action inerte n\'invoque RIEN');
      // La ligne éligible, elle, invoque bien.
      await tester.tap(find.text('validate').first);
      await tester.pump();
      expect(invoked, 1);
    });

    testWidgets('le motif déclaré est annoncé en indice sémantique',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _harness(
          acl: const ZAllowAllAcl(),
          actions: <ZRowAction<_Piece>>[
            ZRowAction<_Piece>(
              id: 'validate',
              labelKey: 'validate',
              requiredPermission: ZCrudAction.validate,
              onInvoke: (BuildContext context, _Piece piece) {},
              enabledFor: (_Piece piece) => !piece.validated,
              ineligibleReasonKey: 'Pièce déjà validée',
            ),
          ],
        ),
      );
      expect(
        _actionSemantics(tester, 'validate', 1).hint,
        'Pièce déjà validée',
      );
      expect(_actionSemantics(tester, 'validate', 0).hint, isNull);
    });

    testWidgets('sans motif déclaré, l\'indice reste renseigné et générique',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _harness(
          acl: const ZAllowAllAcl(),
          actions: <ZRowAction<_Piece>>[
            ZRowAction<_Piece>(
              id: 'validate',
              labelKey: 'validate',
              requiredPermission: ZCrudAction.validate,
              onInvoke: (BuildContext context, _Piece piece) {},
              enabledFor: (_Piece piece) => !piece.validated,
            ),
          ],
        ),
      );
      expect(
        _actionSemantics(tester, 'validate', 1).hint,
        'This action does not apply to this item',
      );
    });
  });

  // ── Les quatre besoins historiques, un seul concept ─────────────────────
  group('les besoins du moteur remplacé s\'écrivent avec le seul résolveur',
      () {
    testWidgets('ACL par item : la ligne protégée perd la suppression, sa '
        'voisine la garde', (WidgetTester tester) async {
      await tester.pumpWidget(
        _harness(
          acl: const ZAllowAllAcl(),
          rowAcl: (_Piece piece) => piece.protected
              ? const ZRowPermissions.denying(<ZCrudAction>{ZCrudAction.delete})
              : const ZRowPermissions.unrestricted(),
          actions: <ZRowAction<_Piece>>[
            ZRowAction<_Piece>(
              id: 'delete',
              labelKey: 'delete',
              requiredPermission: ZCrudAction.delete,
              onInvoke: (BuildContext context, _Piece piece) {},
            ),
          ],
        ),
      );
      // Ligne 1 seulement : la ligne 2 (protégée) a perdu l'action.
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('lecture seule par item : toutes les écritures tombent, la '
        'consultation reste', (WidgetTester tester) async {
      await tester.pumpWidget(
        _harness(
          acl: const ZAllowAllAcl(),
          rowAcl: (_Piece piece) => piece.closed
              ? const ZRowPermissions.locked()
              : const ZRowPermissions.unrestricted(),
          actions: <ZRowAction<_Piece>>[
            ZRowAction<_Piece>(
              id: 'edit',
              labelKey: 'edit',
              requiredPermission: ZCrudAction.update,
              onInvoke: (BuildContext context, _Piece piece) {},
            ),
            ZRowAction<_Piece>(
              id: 'delete',
              labelKey: 'delete',
              requiredPermission: ZCrudAction.delete,
              onInvoke: (BuildContext context, _Piece piece) {},
            ),
            ZRowAction<_Piece>(
              id: 'history',
              labelKey: 'history',
              requiredPermission: ZCrudAction.history,
              onInvoke: (BuildContext context, _Piece piece) {},
            ),
          ],
        ),
      );
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      // Lecture : offerte sur les DEUX lignes, y compris la clôturée.
      expect(find.text('history'), findsNWidgets(2));
    });

    testWidgets('suppression conditionnelle par item (canBeDeleted)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _harness(
          acl: const ZAllowAllAcl(),
          mode: ZActionAclMode.disable,
          rowAcl: (_Piece piece) => piece.protected
              ? const ZRowPermissions.denying(
                  <ZCrudAction>{ZCrudAction.delete},
                  reasonKey: 'Pièce protégée',
                )
              : const ZRowPermissions.unrestricted(),
          actions: <ZRowAction<_Piece>>[
            ZRowAction<_Piece>(
              id: 'delete',
              labelKey: 'delete',
              requiredPermission: ZCrudAction.delete,
              onInvoke: (BuildContext context, _Piece piece) {},
            ),
          ],
        ),
      );
      expect(_actionSemantics(tester, 'Delete', 0).enabled, isTrue);
      expect(_actionSemantics(tester, 'Delete', 1).enabled, isFalse);
      expect(_actionSemantics(tester, 'Delete', 1).hint, 'Pièce protégée');
    });

    testWidgets('validation conditionnelle par item (toBeValidated)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _harness(
          acl: const ZAllowAllAcl(),
          rowAcl: (_Piece piece) => piece.validated
              ? const ZRowPermissions.denying(
                  <ZCrudAction>{ZCrudAction.validate},
                )
              : const ZRowPermissions.unrestricted(),
          actions: <ZRowAction<_Piece>>[
            ZRowAction<_Piece>(
              id: 'validate',
              labelKey: 'validate',
              requiredPermission: ZCrudAction.validate,
              onInvoke: (BuildContext context, _Piece piece) {},
            ),
          ],
        ),
      );
      expect(find.text('validate'), findsOneWidget);
    });
  });

  // ── Contre-témoin : rien de déclaré, rien de changé ─────────────────────
  group('sans gouvernance déclarée, comportement strictement inchangé', () {
    testWidgets('aucun résolveur, aucun enabledFor ⇒ toutes les actions '
        'offertes et invocables', (WidgetTester tester) async {
      var invoked = 0;
      await tester.pumpWidget(
        _harness(
          acl: const ZAllowAllAcl(),
          actions: <ZRowAction<_Piece>>[
            ZRowAction<_Piece>(
              id: 'delete',
              labelKey: 'delete',
              requiredPermission: ZCrudAction.delete,
              onInvoke: (BuildContext context, _Piece piece) => invoked++,
            ),
          ],
        ),
      );
      expect(find.text('Delete'), findsNWidgets(2));
      for (int i = 0; i < 2; i++) {
        expect(
          _actionSemantics(tester, 'Delete', i).enabled,
          isTrue,
        );
        expect(_actionSemantics(tester, 'Delete', i).hint, isNull);
      }
      await tester.tap(find.text('Delete').first);
      await tester.pump();
      expect(invoked, 1);
    });
  });

  // ── Mode d'ACL : c'est l'application qui dit ────────────────────────────
  group('le mode d\'ACL déclaré reste souverain sur les refus de DROIT', () {
    testWidgets('hide masque le droit retiré par la ligne',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _harness(
          acl: const ZAllowAllAcl(),
          rowAcl: (_Piece piece) =>
              const ZRowPermissions.denying(<ZCrudAction>{ZCrudAction.delete}),
          actions: <ZRowAction<_Piece>>[
            ZRowAction<_Piece>(
              id: 'delete',
              labelKey: 'delete',
              requiredPermission: ZCrudAction.delete,
              onInvoke: (BuildContext context, _Piece piece) {},
            ),
          ],
        ),
      );
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('disable le rend inerte au lieu de le masquer',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _harness(
          acl: const ZAllowAllAcl(),
          mode: ZActionAclMode.disable,
          rowAcl: (_Piece piece) =>
              const ZRowPermissions.denying(<ZCrudAction>{ZCrudAction.delete}),
          actions: <ZRowAction<_Piece>>[
            ZRowAction<_Piece>(
              id: 'delete',
              labelKey: 'delete',
              requiredPermission: ZCrudAction.delete,
              onInvoke: (BuildContext context, _Piece piece) {},
            ),
          ],
        ),
      );
      expect(find.text('Delete'), findsNWidgets(2));
      expect(
        _actionSemantics(tester, 'Delete', 0).enabled,
        isFalse,
      );
    });

    testWidgets('mais une action INÉLIGIBLE reste rendue même en mode hide',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _harness(
          acl: const ZAllowAllAcl(),
          actions: <ZRowAction<_Piece>>[
            ZRowAction<_Piece>(
              id: 'validate',
              labelKey: 'validate',
              requiredPermission: ZCrudAction.validate,
              onInvoke: (BuildContext context, _Piece piece) {},
              enabledFor: (_Piece piece) => !piece.validated,
            ),
          ],
        ),
      );
      expect(
        find.text('validate'),
        findsNWidgets(2),
        reason: 'le mode d\'ACL gouverne les DROITS, pas l\'éligibilité',
      );
    });
  });

  // ── Éligibilité posée sur une action de fabrique ────────────────────────
  testWidgets('withEligibility conserve id, permission et style destructif',
      (WidgetTester tester) async {
    final ZRowAction<_Piece> base = ZRowAction<_Piece>.purgeWith(
      (BuildContext context, _Piece piece) {},
    );
    final ZRowAction<_Piece> derived = base.withEligibility(
      (_Piece piece) => piece.closed,
      reasonKey: 'Encore ouverte',
    );
    expect(derived.id, base.id);
    expect(derived.labelKey, base.labelKey);
    expect(derived.requiredPermission, base.requiredPermission);
    expect(derived.destructive, isTrue);
    expect(derived.enabledFor, isNotNull);
    expect(derived.ineligibleReasonKey, 'Encore ouverte');
    expect(base.enabledFor, isNull);
  });
}
