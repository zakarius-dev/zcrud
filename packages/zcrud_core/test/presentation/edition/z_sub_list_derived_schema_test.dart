// **Sous-schéma dérivé**, **gabarits de création dérivés**, **identité du
// gabarit transmise au crochet** et **forme de présentation du formulaire
// d'item** — passe 3 du portage du moteur `subItems` legacy.
//
// 🔴 LA GARDE QUI PROUVE LE PORTAGE (groupe A) reproduit l'usage réel de
// `dodlp-otr/lib/modules/vido/presentation/forms/mes_dossiers_form.dart` : une
// timeline dont les rangées ne s'éditent pas, dont le menu d'AJOUT n'offre que
// les transitions autorisées **depuis l'état courant du formulaire parent**, et
// dont le crochet fabrique l'item à partir de la charge utile du gabarit choisi.
// Si elle passe, le portage est prouvé sur le terrain — pas en théorie.
//
// ⚠️ ÉCART MESURÉ AVEC LA SOURCE LEGACY, et pourquoi la garde ne le copie pas :
// le champ legacy déclare `readOnly: true` **et** un menu d'ajout, or
// `DynamicListViewer.getCaption` ne rend le bouton d'ajout que
// `if (widget.readOnly == false && acl.create)` (dynamic_list_viewer.dart:145).
// Dans le dépôt hôte, ce menu d'ajout n'est donc **jamais rendu** : c'est un
// geste mort, de la même famille que le prédicat `filter` jamais invoqué qu'a
// relevé la passe 2. zcrud applique la même règle (`canCreate = !readOnly &&
// acl.can(create)`), si bien que copier la déclaration à la lettre donnerait une
// garde **verte pour la mauvaise raison** : rien à cliquer. La garde exprime
// donc l'INTENTION de l'usage dans le vocabulaire de zcrud — rangées non
// éditables par l'**ACL** (`create` seul autorisé), champ non `readOnly` — ce
// qui rend le menu d'ajout réellement atteignable.
//
// 🔴 CONTRE-TÉMOIN À COMPTES ABSOLUS (groupe F) : rien de déclaré ⇒ comptes de
// widgets **absolus**, jamais une comparaison entre deux rendus passifs — un
// canal qui ajouterait un nœud à TOUT LE MONDE ferait bouger les deux mesures
// ensemble et resterait invisible (leçon de la passe 1).
//
// ⚠️ `DynamicEdition` monte ses champs par `ListView.builder` (montage
// PARESSEUX) : sans surface haute, la sous-liste n'est jamais montée.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

// ── Sous-schémas ────────────────────────────────────────────────────────────

const _base = <ZFieldSpec>[
  ZFieldSpec(name: 'a', type: EditionFieldType.text, label: 'A'),
  ZFieldSpec(name: 'b', type: EditionFieldType.text, label: 'B'),
];

const _etendu = <ZFieldSpec>[
  ZFieldSpec(name: 'a', type: EditionFieldType.text, label: 'A'),
  ZFieldSpec(name: 'b', type: EditionFieldType.text, label: 'B'),
  ZFieldSpec(name: 'c', type: EditionFieldType.text, label: 'C'),
];

/// Champ parent qui pilote la dérivation (une tranche que le résolveur LIT).
const _pilote = ZFieldSpec(
  name: 'etat',
  type: EditionFieldType.text,
  label: 'État',
);

/// Champ parent que **personne** ne lit — sert à prouver que le canal est
/// ciblé : y écrire ne doit rien réveiller.
const _muet = ZFieldSpec(
  name: 'muet',
  type: EditionFieldType.text,
  label: 'Muet',
);

ZFieldSpec _sousListe({
  ZSubListDisplayMode mode = ZSubListDisplayMode.compact,
  List<ZFieldSpec> itemFields = _base,
  List<String> summaryFields = const <String>['a'],
  List<ZSubListItemTemplate> templates = const <ZSubListItemTemplate>[],
  Map<String, Object?> defaultNewItem = const <String, Object?>{},
  ZSubItemFormPresentation presentation = ZSubItemFormPresentation.dialog,
}) =>
    ZFieldSpec(
      name: 'items',
      type: EditionFieldType.subItems,
      label: 'Items',
      config: ZSubListConfig(
        itemFields: itemFields,
        displayMode: mode,
        summaryFields: summaryFields,
        creationTemplates: templates,
        defaultNewItem: defaultNewItem,
        itemFormPresentation: presentation,
      ),
    );

/// ACL **sélective** — le seul moyen de prouver quelle porte est ouverte.
class _AclFor implements ZAcl {
  const _AclFor(this.allowed);
  final Set<ZCrudAction> allowed;
  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) =>
      allowed.contains(action);
}

/// Surface haute : sans elle, `ListView.builder` peut ne jamais monter la
/// sous-liste et la garde serait verte pour la mauvaise raison.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// **Chemin NOMINAL** : `DynamicEdition` → `ZFieldWidget` → famille. AUCUN
/// `fieldBuilder` — c'est tout l'enjeu (leçon de la passe 1).
Widget _nominal(
  ZFieldSpec field, {
  required ZFormController controller,
  ZSubListSeamRegistry? registry,
  ZAcl acl = const ZAllowAllAcl(),
  List<ZFieldSpec> autres = const <ZFieldSpec>[],
}) =>
    MaterialApp(
      home: ZcrudScope(
        acl: acl,
        subListSeamRegistry: registry,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Scaffold(
            body: DynamicEdition(
              controller: controller,
              fields: <ZFieldSpec>[...autres, field],
            ),
          ),
        ),
      ),
    );

ZFormController _controllerWith(
  Object? items, {
  Map<String, Object?> extra = const <String, Object?>{},
}) =>
    ZFormController(
      initialValues: <String, Object?>{'items': items, ...extra},
      visibleFields: <String>['items', ...extra.keys],
    );

/// La valeur **AGRÉGÉE** dans la tranche parente — la donnée, pas le rendu.
List<Map<String, dynamic>> _aggregated(ZFormController c) {
  final raw = c.valueOf('items');
  if (raw is! List) return const <Map<String, dynamic>>[];
  return <Map<String, dynamic>>[
    for (final e in raw)
      if (e is Map) Map<String, dynamic>.from(e),
  ];
}

ZSubListSeamRegistry _registry(ZSubListSeams seams, {String key = 'items'}) =>
    ZSubListSeamRegistry()..register(key, seams);

/// Les **entrées du menu de gabarits** actuellement ouvertes, et elles seules.
///
/// `find.text('…')` ne suffit pas : le libellé d'un gabarit peut être **aussi**
/// celui d'une ligne déjà créée (c'est le cas d'une timeline, où la ligne
/// affiche l'événement qu'un gabarit avait servi à ajouter). Chercher le texte
/// globalement rendrait la garde verte — ou rouge — pour la mauvaise raison.
List<String> _menuGabarits(WidgetTester tester) => tester
    .widgetList<PopupMenuItem<ZSubListItemTemplate>>(
        find.byType(PopupMenuItem<ZSubListItemTemplate>))
    .map((entry) => ((entry.child ?? const SizedBox()) as Text).data ?? '')
    .toList();

/// Démonte complètement l'arbre entre deux scénarios d'un même `testWidgets`.
///
/// Sans cela, `pumpWidget` **réutilise** l'élément de la sous-liste (même type,
/// même position) : son `State` — donc ses items déjà créés — survivrait au
/// changement de contrôleur, et l'assertion croisée compterait les items du
/// scénario précédent.
Future<void> _remonter(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

/// Saisit [texte] dans le champ dont le **libellé** est [libelle] — jamais par
/// index de `EditableText` : l'ordre de montage n'est pas un contrat.
Future<void> _saisirDans(
  WidgetTester tester,
  String libelle,
  String texte,
) async {
  await tester.enterText(
    find.descendant(
      of: find.widgetWithText(TextFormField, libelle),
      matching: find.byType(EditableText),
    ),
    texte,
  );
  await tester.pump();
}

void main() {
  // ══════════════════════════════════════════════════════════════════════════
  // A. LA GARDE QUI PROUVE LE PORTAGE — l'usage réel de `mes_dossiers_form`
  // ══════════════════════════════════════════════════════════════════════════
  group('A. Portage de l\'usage réel (timeline VIDO)', () {
    // Transitions autorisées, calquées sur `DepotageEvent.isTransitionAllowed`.
    const suivantes = <String?, List<String>>{
      null: <String>['debut'],
      'debut': <String>['controle', 'fin'],
      'controle': <String>['fin'],
      'fin': <String>[],
    };
    const libelles = <String, String>{
      'debut': 'Début du dépotage',
      'controle': 'Contrôle',
      'fin': 'Fin du dépotage',
    };

    /// Le sous-schéma est **projeté** : ce que la timeline affiche n'est pas ce
    /// qu'elle stocke (`type` est stocké, `typeLabel` est affiché) — c'est le
    /// `dynamicSubItemTransformer` du legacy, et c'est pour cela que `type` n'a
    /// aucune raison d'être un champ du sous-schéma.
    const itemFields = <ZFieldSpec>[
      ZFieldSpec(
          name: 'typeLabel', type: EditionFieldType.text, label: 'Événement'),
      ZFieldSpec(name: 'agent', type: EditionFieldType.text, label: 'Agent'),
    ];

    /// Le champ, **non `readOnly`** : ce sont l'ACL (create seul) et la
    /// projection qui rendent la timeline non éditable rangée par rangée.
    final champ = ZFieldSpec(
      name: 'items',
      type: EditionFieldType.subItems,
      label: 'Timeline',
      config: const ZSubListConfig(
        itemFields: itemFields,
        displayMode: ZSubListDisplayMode.compact,
        summaryFields: <String>['typeLabel', 'agent'],
      ),
    );

    /// Les gabarits, **calculés depuis l'état du formulaire parent** : le
    /// dernier événement de la liste d'items commande les suivants possibles.
    List<ZSubListItemTemplate> gabarits(ZValueOf parent) {
      final items = parent('items');
      String? dernier;
      if (items is List && items.isNotEmpty) {
        final last = items.last;
        if (last is Map) dernier = last['type'] as String?;
      }
      return <ZSubListItemTemplate>[
        for (final type in suivantes[dernier] ?? const <String>[])
          ZSubListItemTemplate(
            id: type,
            labelKey: 'zz.$type',
            labelFallback: libelles[type],
            // La charge utile du gabarit — le `option.data` du legacy. `type`
            // n'est PAS un champ du sous-schéma : sans la conservation du
            // résidu, il serait perdu.
            defaults: <String, Object?>{'type': type},
            // Le geste legacy n'ouvrait AUCUN formulaire : le type vient du
            // gabarit, l'horodatage et l'auteur du moment du clic.
            opensForm: false,
          ),
      ];
    }

    testWidgets(
        '🔴 PRINCIPAL : gabarits calculés depuis l\'état parent, crochet '
        'fabriquant l\'item depuis la charge du gabarit, clé hors sous-schéma '
        'CONSERVÉE', (tester) async {
      _useTallSurface(tester);
      final recues = <ZSubItemCrudRequest>[];
      final registry = _registry(ZSubListSeams(
        creationTemplatesResolver: gabarits,
        onCrud: (request) async {
          recues.add(request);
          final type = request.template?.defaults['type'] as String?;
          if (request.action != ZCrudAction.create || type == null) {
            return const ZSubItemCrudOutcome.proceed();
          }
          // Exactement le `onCrudSubItem` legacy : l'item est FABRIQUÉ ici.
          return ZSubItemCrudOutcome.replace(<String, dynamic>{
            'type': type,
            'typeLabel': libelles[type],
            'agent': 'agent-42',
          });
        },
      ));
      final controller = _controllerWith(const <Map<String, dynamic>>[]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(
        champ,
        controller: controller,
        registry: registry,
        // Rangées non éditables : ni consulter, ni modifier, ni supprimer.
        acl: const _AclFor(<ZCrudAction>{ZCrudAction.create}),
      ));
      await tester.pump();

      // Liste vide ⇒ seule la transition initiale est offerte.
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(_menuGabarits(tester), <String>['Début du dépotage']);

      await tester.tap(find.text('Début du dépotage'));
      await tester.pumpAndSettle();

      // Aucun formulaire n'a été ouvert (`opensForm: false`) — geste legacy.
      expect(find.byType(AlertDialog), findsNothing);

      // Le crochet a reçu le GABARIT CHOISI, pas seulement ses valeurs.
      expect(recues, hasLength(1));
      expect(recues.single.action, ZCrudAction.create);
      expect(recues.single.template?.id, 'debut');
      expect(recues.single.template?.defaults['type'], 'debut');
      expect(recues.single.item, isNull, reason: 'création : aucun item visé');

      // 🔴 La clé HORS sous-schéma (`type`) a survécu jusqu'à la donnée agrégée.
      final apres1 = _aggregated(controller);
      expect(apres1, hasLength(1));
      expect(apres1.single['type'], 'debut');
      expect(apres1.single['typeLabel'], 'Début du dépotage');
      expect(apres1.single['agent'], 'agent-42');

      // La ligne rend la projection, pas la clé technique.
      expect(find.text('Début du dépotage'), findsOneWidget);

      // 🔴 L'ÉTAT PARENT A CHANGÉ ⇒ les gabarits offerts changent.
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(_menuGabarits(tester), <String>['Contrôle', 'Fin du dépotage'],
          reason: 'la transition initiale est consommée, les suivantes '
              'découlent du DERNIER item — donc de l\'état parent');

      await tester.tap(find.text('Fin du dépotage').last);
      await tester.pumpAndSettle();

      final apres2 = _aggregated(controller);
      expect(apres2.map((e) => e['type']).toList(), <String>['debut', 'fin']);

      // Plus aucune transition ⇒ le menu de gabarits disparaît, et le contrôle
      // d'ajout redevient le bouton `+` simple (l'ACL autorise toujours).
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(_menuGabarits(tester), isEmpty);
    });

    testWidgets(
        'rangées non éditables : aucune action de ligne, mais l\'ajout reste',
        (tester) async {
      _useTallSurface(tester);
      final registry = _registry(ZSubListSeams(
        creationTemplatesResolver: gabarits,
        onCrud: (r) async => const ZSubItemCrudOutcome.proceed(),
      ));
      final controller = _controllerWith(const <Map<String, dynamic>>[
        <String, dynamic>{'type': 'debut', 'typeLabel': 'Début', 'agent': 'x'},
      ]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(
        champ,
        controller: controller,
        registry: registry,
        acl: const _AclFor(<ZCrudAction>{ZCrudAction.create}),
      ));
      await tester.pump();

      expect(find.byIcon(Icons.visibility), findsNothing);
      expect(find.byIcon(Icons.edit), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // B. SOUS-SCHÉMA DÉRIVÉ DE L'ÉTAT PARENT
  // ══════════════════════════════════════════════════════════════════════════
  group('B. Sous-schéma dérivé (subSchemaResolver)', () {
    ZSubListSeams schemaSeams() => ZSubListSeams(
          subSchemaResolver: (parent) =>
              parent('etat') == 'plein' ? _etendu : _base,
        );

    testWidgets(
        '🔴 CHEMIN NOMINAL : changer l\'état parent change les champs de l\'item',
        (tester) async {
      _useTallSurface(tester);
      final controller = _controllerWith(
        const <Map<String, dynamic>>[
          <String, dynamic>{'a': 'A1', 'b': 'B1', 'c': 'C1'},
        ],
        extra: const <String, Object?>{'etat': 'vide'},
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(
        _sousListe(mode: ZSubListDisplayMode.inline),
        controller: controller,
        registry: _registry(schemaSeams()),
        autres: const <ZFieldSpec>[_pilote, _muet],
      ));
      await tester.pump();

      // Écrire dans une tranche parente que PERSONNE ne lit ne réveille rien.
      controller.setValue('muet', 'peu importe');
      await tester.pump();
      expect(find.widgetWithText(TextFormField, 'C'), findsNothing);

      // Schéma de base : `c` n'est pas rendu, mais sa valeur n'est PAS détruite
      // (elle vit dans le résidu hors sous-schéma).
      expect(find.widgetWithText(TextFormField, 'A'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'C'), findsNothing);
      expect(_aggregated(controller).single['c'], 'C1');

      controller.setValue('etat', 'plein');
      await tester.pump();

      // 🔴 Le sous-schéma s'est étendu SUR LE CHEMIN NOMINAL.
      expect(find.widgetWithText(TextFormField, 'C'), findsOneWidget);
      // La valeur remontée du résidu vers la tranche est bien celle d'avant.
      expect(_aggregated(controller).single['c'], 'C1');

      // Retour en arrière : `c` redescend dans le résidu, jamais détruit.
      controller.setValue('etat', 'vide');
      await tester.pump();
      expect(find.widgetWithText(TextFormField, 'C'), findsNothing);
      expect(_aggregated(controller).single['c'], 'C1');
    });

    testWidgets(
        '🔴 AD-2 : le sous-schéma change SANS recréer les ZFormController '
        'd\'item, et sans reconstruire les champs inchangés', (tester) async {
      final builds = <String, int>{};
      final controleurs = <String, ZFormController>{};
      final parent = ZFormController(
        initialValues: const <String, Object?>{'etat': 'vide'},
        visibleFields: const <String>['etat'],
      );
      addTearDown(parent.dispose);

      Widget itemFieldBuilder(
        BuildContext context,
        ZFormController itemController,
        ZFieldSpec field,
        String itemId,
      ) {
        controleurs[itemId] = itemController;
        return ZFieldWidget(
          controller: itemController,
          field: field,
          onBuild: () {
            final k = '$itemId/${field.name}';
            builds[k] = (builds[k] ?? 0) + 1;
          },
        );
      }

      await tester.pumpWidget(MaterialApp(
        home: ZcrudScope(
          acl: const ZAllowAllAcl(),
          subListSeamRegistry: _registry(schemaSeams()),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Scaffold(
              body: ZSubListFieldWidget(
                field: _sousListe(mode: ZSubListDisplayMode.inline),
                initialValue: const <Map<String, dynamic>>[
                  <String, dynamic>{'a': 'A1', 'b': 'B1'},
                ],
                parentController: parent,
                itemFieldBuilder: itemFieldBuilder,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(controleurs, hasLength(1));
      final itemId = controleurs.keys.single;
      final avant = controleurs[itemId];
      expect(builds['$itemId/a'], 1);
      expect(builds['$itemId/b'], 1);
      expect(builds.containsKey('$itemId/c'), isFalse);

      // Écrire dans une tranche parente que PERSONNE ne lit : rien ne bouge.
      parent.setValue('muet', 'peu importe');
      await tester.pump();
      expect(builds['$itemId/a'], 1,
          reason: 'tranche non lue ⇒ aucun réveil (canal CIBLÉ)');

      // Écrire une valeur qui ne change PAS le schéma : rien ne bouge non plus.
      parent.setValue('etat', 'autre-chose');
      await tester.pump();
      expect(builds['$itemId/a'], 1,
          reason: 'schéma identique ⇒ aucune reconstruction');

      // 🔴 Le schéma change réellement.
      parent.setValue('etat', 'plein');
      await tester.pump();

      // 🔴 L'IDENTITÉ de l'item est intacte — c'est la première moitié de
      // l'assertion, et elle n'est pas décorative : une implémentation qui
      // reconstruirait la liste d'items en repartant des graines laisserait
      // `controleurs[itemId]` intact (l'ancienne entrée n'est jamais écrasée)
      // et une comparaison par identité SEULE resterait verte.
      expect(controleurs.keys.toList(), <String>[itemId],
          reason: 'un item recréé porterait une NOUVELLE identité de place');
      // Le CONTRÔLEUR de l'item est le MÊME objet — jamais recréé (AD-2).
      expect(identical(controleurs[itemId], avant), isTrue,
          reason: 'un ZFormController recréé perdrait état, focus et curseur');
      // Le champ apparu est monté une fois ; les champs inchangés ont
      // reconstruit AU PLUS une fois de plus (le conteneur se rebâtit, mais
      // leur état est conservé — comptes ABSOLUS).
      expect(builds['$itemId/c'], 1);
      expect(builds['$itemId/a'], 2);
      expect(builds['$itemId/b'], 2);
    });

    testWidgets(
        'AD-2 : la saisie d\'un sous-champ SURVIT au changement de schéma',
        (tester) async {
      _useTallSurface(tester);
      final controller = _controllerWith(
        const <Map<String, dynamic>>[
          <String, dynamic>{'a': '', 'b': ''},
        ],
        extra: const <String, Object?>{'etat': 'vide'},
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(
        _sousListe(mode: ZSubListDisplayMode.inline),
        controller: controller,
        registry: _registry(schemaSeams()),
        autres: const <ZFieldSpec>[_pilote],
      ));
      await tester.pump();

      await _saisirDans(tester, 'A', 'SAISIE');
      expect(_aggregated(controller).single['a'], 'SAISIE');

      controller.setValue('etat', 'plein');
      await tester.pump();

      // Le texte saisi est toujours là, dans le MÊME champ, et la donnée
      // agrégée n'a pas été rebâtie depuis la graine.
      expect(find.text('SAISIE'), findsOneWidget);
      expect(_aggregated(controller).single['a'], 'SAISIE');
      expect(find.widgetWithText(TextFormField, 'C'), findsOneWidget);
    });

    testWidgets(
        '🔴 AD-2 : un résolveur qui lit SA PROPRE tranche n\'est PAS relancé '
        'par l\'agrégation des items', (tester) async {
      _useTallSurface(tester);
      var appels = 0;
      final controller = _controllerWith(
        const <Map<String, dynamic>>[
          <String, dynamic>{'a': '', 'b': ''},
        ],
        extra: const <String, Object?>{'etat': 'vide'},
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(
        _sousListe(mode: ZSubListDisplayMode.inline),
        controller: controller,
        registry: _registry(ZSubListSeams(
          subSchemaResolver: (parent) {
            appels++;
            // Lecture LÉGITIME de sa propre tranche : le nombre d'items est
            // une entrée naturelle d'un schéma dérivé (c'est ce que fait la
            // timeline du groupe A).
            final items = parent('items');
            return (items is List && items.length > 1) ? _etendu : _base;
          },
        )),
        autres: const <ZFieldSpec>[_pilote],
      ));
      await tester.pump();
      final base = appels;
      expect(base, greaterThan(0), reason: 'le résolveur doit avoir été appelé');

      // Taper dans un sous-champ agrège vers la tranche `items` du parent.
      await _saisirDans(tester, 'A', 'frappe-1');
      await _saisirDans(tester, 'A', 'frappe-12');
      await _saisirDans(tester, 'A', 'frappe-123');

      // 🔴 Sans l'exclusion de sa propre tranche, CHAQUE frappe dans un
      // sous-champ relancerait la résolution du schéma — c'est-à-dire le
      // rafraîchissement global que ce canal existe pour supprimer.
      expect(appels, base,
          reason: 'la tranche du champ lui-même ne doit JAMAIS être abonnée');
      expect(_aggregated(controller).single['a'], 'frappe-123');
    });

    testWidgets('AD-10 : un résolveur qui LÈVE replie sur le schéma déclaré',
        (tester) async {
      _useTallSurface(tester);
      final controller = _controllerWith(
        const <Map<String, dynamic>>[
          <String, dynamic>{'a': 'A1', 'b': 'B1'},
        ],
        extra: const <String, Object?>{'etat': 'vide'},
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(
        _sousListe(mode: ZSubListDisplayMode.inline),
        controller: controller,
        registry: _registry(ZSubListSeams(
          subSchemaResolver: (parent) => throw StateError('résolveur cassé'),
        )),
        autres: const <ZFieldSpec>[_pilote],
      ));
      await tester.pump();

      // Aucune exception n'a cassé l'écran, et le schéma DÉCLARÉ est rendu.
      expect(tester.takeException(), isNull);
      expect(find.widgetWithText(TextFormField, 'A'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'B'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'C'), findsNothing);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // C. GABARITS DE CRÉATION DÉRIVÉS
  // ══════════════════════════════════════════════════════════════════════════
  group('C. Gabarits dérivés (creationTemplatesResolver)', () {
    testWidgets('le résolveur REMPLACE les gabarits déclarés en config',
        (tester) async {
      _useTallSurface(tester);
      final controller = _controllerWith(
        const <Map<String, dynamic>>[],
        extra: const <String, Object?>{'etat': 'x'},
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(
        _sousListe(
          templates: const <ZSubListItemTemplate>[
            ZSubListItemTemplate(labelKey: 'zz.config', labelFallback: 'CONFIG'),
          ],
        ),
        controller: controller,
        registry: _registry(ZSubListSeams(
          creationTemplatesResolver: (parent) => <ZSubListItemTemplate>[
            ZSubListItemTemplate(
              labelKey: 'zz.derive',
              labelFallback: 'DÉRIVÉ ${parent('etat')}',
            ),
          ],
        )),
        autres: const <ZFieldSpec>[_pilote],
      ));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('DÉRIVÉ x'), findsOneWidget);
      expect(find.text('CONFIG'), findsNothing,
          reason: 'remplacement, pas fusion — sinon on ne peut RIEN retirer');
    });

    testWidgets('AD-10 : un résolveur de gabarits qui LÈVE replie sur la config',
        (tester) async {
      _useTallSurface(tester);
      final controller = _controllerWith(const <Map<String, dynamic>>[]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(
        _sousListe(
          templates: const <ZSubListItemTemplate>[
            ZSubListItemTemplate(labelKey: 'zz.config', labelFallback: 'CONFIG'),
          ],
        ),
        controller: controller,
        registry: _registry(ZSubListSeams(
          creationTemplatesResolver: (parent) => throw StateError('cassé'),
        )),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('CONFIG'), findsOneWidget);
    });

    testWidgets(
        'gabarit déclaré en CONFIG : son identité atteint aussi le crochet',
        (tester) async {
      _useTallSurface(tester);
      final recues = <ZSubItemCrudRequest>[];
      final controller = _controllerWith(const <Map<String, dynamic>>[]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(
        _sousListe(
          templates: const <ZSubListItemTemplate>[
            ZSubListItemTemplate(
              id: 'urgent',
              labelKey: 'zz.urgent',
              labelFallback: 'Urgent',
              defaults: <String, Object?>{'a': 'pré-rempli'},
            ),
          ],
        ),
        controller: controller,
        registry: _registry(ZSubListSeams(
          onCrud: (r) async {
            recues.add(r);
            return const ZSubItemCrudOutcome.proceed();
          },
        )),
      ));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Urgent'));
      await tester.pumpAndSettle();
      // `opensForm` par défaut ⇒ le formulaire s'ouvre, pré-rempli.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('pré-rempli'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(recues.single.template?.id, 'urgent');
    });

    testWidgets(
        'le bouton `+` SIMPLE ne choisit aucun gabarit : template == null',
        (tester) async {
      _useTallSurface(tester);
      final recues = <ZSubItemCrudRequest>[];
      final controller = _controllerWith(const <Map<String, dynamic>>[]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(
        _sousListe(),
        controller: controller,
        registry: _registry(ZSubListSeams(
          onCrud: (r) async {
            recues.add(r);
            return const ZSubItemCrudOutcome.proceed();
          },
        )),
      ));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(recues.single.template, isNull);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // D. LES TROIS FORMES DE PRÉSENTATION RENDENT LA MÊME DONNÉE
  // ══════════════════════════════════════════════════════════════════════════
  group('D. Forme du formulaire d\'item (dialogue / feuille / page)', () {
    /// Joue **exactement la même saisie** dans la forme demandée et rend la
    /// `Map` agrégée. C'est l'assertion croisée : trois enveloppes, une donnée.
    Future<Map<String, dynamic>> saisir(
      WidgetTester tester,
      ZSubItemFormPresentation presentation,
    ) async {
      _useTallSurface(tester);
      await _remonter(tester);
      final controller = _controllerWith(const <Map<String, dynamic>>[]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(
        _sousListe(presentation: presentation),
        controller: controller,
      ));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Ciblage par LIBELLÉ, jamais par index : les trois formes n'ont pas la
      // même géométrie, et un ordre de montage n'est pas un contrat.
      await _saisirDans(tester, 'A', 'valeur-A');
      await _saisirDans(tester, 'B', 'valeur-B');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final items = _aggregated(controller);
      expect(items, hasLength(1),
          reason: 'la forme « ${presentation.name} » n\'a rien enregistré');
      return items.single;
    }

    late Map<String, dynamic> parDialogue;
    late Map<String, dynamic> parFeuille;
    late Map<String, dynamic> parPage;

    testWidgets('dialogue (défaut) : AlertDialog', (tester) async {
      parDialogue = await saisir(tester, ZSubItemFormPresentation.dialog);
      expect(parDialogue['a'], 'valeur-A');
    });

    testWidgets('feuille : la même saisie, hors AlertDialog', (tester) async {
      parFeuille = await saisir(tester, ZSubItemFormPresentation.sheet);
      expect(parFeuille['a'], 'valeur-A');
    });

    testWidgets('page : la même saisie, hors AlertDialog', (tester) async {
      parPage = await saisir(tester, ZSubItemFormPresentation.page);
      expect(parPage['a'], 'valeur-A');
    });

    testWidgets('🔴 ASSERTION CROISÉE : les trois rendent la MÊME Map',
        (tester) async {
      final d = await saisir(tester, ZSubItemFormPresentation.dialog);
      final f = await saisir(tester, ZSubItemFormPresentation.sheet);
      final p = await saisir(tester, ZSubItemFormPresentation.page);
      // Mêmes clés, dans le même ordre, avec les mêmes valeurs.
      expect(f.keys.toList(), d.keys.toList());
      expect(p.keys.toList(), d.keys.toList());
      expect(f, d);
      expect(p, d);
      expect(d, <String, dynamic>{'a': 'valeur-A', 'b': 'valeur-B'});
    });

    /// Ouvre le formulaire d'ajout dans la forme demandée.
    Future<ZFormController> ouvrir(
      WidgetTester tester,
      ZSubItemFormPresentation presentation,
    ) async {
      _useTallSurface(tester);
      await _remonter(tester);
      final controller = _controllerWith(const <Map<String, dynamic>>[]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _nominal(_sousListe(presentation: presentation), controller: controller),
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('la forme demandée est bien CELLE qui est montée',
        (tester) async {
      await ouvrir(tester, ZSubItemFormPresentation.dialog);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);

      await ouvrir(tester, ZSubItemFormPresentation.sheet);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(BottomSheet), findsOneWidget);

      await ouvrir(tester, ZSubItemFormPresentation.page);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(AppBar), findsOneWidget);
      // Le formulaire de page est bien une ROUTE : le retour la dépile.
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('AD-13 (feuille) : bouton ≥ 48 dp, titre annoncé EN-TÊTE',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await ouvrir(tester, ZSubItemFormPresentation.sheet);

      expect(tester.getSize(find.widgetWithText(TextButton, 'Save')).height,
          greaterThanOrEqualTo(48.0));
      expect(tester.getSize(find.widgetWithText(TextButton, 'Cancel')).height,
          greaterThanOrEqualTo(48.0));
      // Scopé à la FEUILLE : le libellé du champ conteneur porte le même texte
      // dans la liste en arrière-plan — chercher globalement viserait l'autre.
      expect(
        tester
            .getSemantics(find.descendant(
              of: find.byType(BottomSheet),
              matching: find.text('Items'),
            ))
            .flagsCollection
            .isHeader,
        isTrue,
        reason: 'un titre non annoncé comme en-tête est un titre invisible '
            'au lecteur d\'écran',
      );
      semantics.dispose();
    });

    testWidgets('AD-13 (page) : bouton ≥ 48 dp, titre annoncé EN-TÊTE',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await ouvrir(tester, ZSubItemFormPresentation.page);

      expect(tester.getSize(find.widgetWithText(TextButton, 'Save')).height,
          greaterThanOrEqualTo(48.0));
      expect(
        tester
            .getSemantics(find.descendant(
              of: find.byType(AppBar),
              matching: find.text('Items'),
            ))
            .flagsCollection
            .isHeader,
        isTrue,
      );
      semantics.dispose();
    });

    testWidgets('AD-13 (feuille) : « Cancel » n\'enregistre rien',
        (tester) async {
      final controller = await ouvrir(tester, ZSubItemFormPresentation.sheet);
      await _saisirDans(tester, 'A', 'jeté');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(_aggregated(controller), isEmpty);
    });

    testWidgets(
        'AD-13 : le retour clavier/système ANNULE, il n\'enregistre pas '
        '(page)', (tester) async {
      _useTallSurface(tester);
      final controller = _controllerWith(const <Map<String, dynamic>>[]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(
        _sousListe(presentation: ZSubItemFormPresentation.page),
        controller: controller,
      ));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await _saisirDans(tester, 'A', 'jeté');

      // Retour système (le bouton de la barre de titre est le même chemin).
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(_aggregated(controller), isEmpty,
          reason: 'annuler ne crée rien — comme la boîte de dialogue');
    });

    testWidgets(
        '🔴 AD-10 : hors Navigator, aucune forme n\'est montable — le geste '
        'est SIGNALÉ, jamais fatal', (tester) async {
      // 🔴 AUCUN `MaterialApp`, donc AUCUN `Navigator` au-dessus du champ. Une
      // garde posée sous `MaterialApp` serait verte pour la mauvaise raison :
      // le Navigator y est toujours présent et le chemin défensif jamais pris.
      final parent = ZFormController(
        initialValues: const <String, Object?>{},
        visibleFields: const <String>[],
      );
      addTearDown(parent.dispose);
      for (final forme in ZSubItemFormPresentation.values) {
        await _remonter(tester);
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: MediaQuery(
              data: const MediaQueryData(size: Size(1200, 2000)),
              child: Theme(
                data: ThemeData(),
                child: Material(
                  // Un `Overlay` (exigé par les tooltips) mais **pas** un
                  // `Navigator` : c'est exactement la situation à couvrir.
                  child: Overlay(
                    initialEntries: <OverlayEntry>[
                      OverlayEntry(
                        builder: (context) => ZcrudScope(
                          acl: const ZAllowAllAcl(),
                          child: ZSubListFieldWidget(
                            field: _sousListe(presentation: forme),
                            initialValue: const <Map<String, dynamic>>[],
                            parentController: parent,
                            onChanged: (_) {},
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(Navigator.maybeOf(tester.element(find.byIcon(Icons.add))), isNull,
            reason: 'la garde n\'a de sens que SANS Navigator');

        await tester.tap(find.byIcon(Icons.add));
        await tester.pump();

        // Le geste n'ouvre rien et n'écrit rien…
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(BottomSheet), findsNothing);
        // …le champ reste monté et utilisable…
        expect(find.byIcon(Icons.add), findsOneWidget);
        // …et l'incident est SIGNALÉ, jamais avalé (invariant AD-10).
        final signale = tester.takeException();
        expect(signale, isA<StateError>(),
            reason: 'forme « ${forme.name} » : un échec silencieux laisserait '
                'l\'hôte croire que la forme est servie');
        expect('$signale', contains(forme.name));
      }
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // E. RUPTURE ASSUMÉE — les clés hors sous-schéma de la GRAINE survivent
  // ══════════════════════════════════════════════════════════════════════════
  group('E. Clés hors sous-schéma d\'une graine de création', () {
    testWidgets(
        '🔴 RUPTURE : une clé de `defaultNewItem` hors sous-schéma est '
        'CONSERVÉE (elle était perdue)', (tester) async {
      _useTallSurface(tester);
      final controller = _controllerWith(const <Map<String, dynamic>>[]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(
        _sousListe(
          defaultNewItem: const <String, Object?>{'origine': 'gabarit'},
        ),
        controller: controller,
      ));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).at(0), 'saisi');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final item = _aggregated(controller).single;
      expect(item['origine'], 'gabarit',
          reason: 'la charge utile déclarée par l\'hôte ne doit plus être '
              'détruite par le formulaire');
      expect(item['a'], 'saisi');
    });

    testWidgets('le crochet VOIT la clé hors sous-schéma dans `data`',
        (tester) async {
      _useTallSurface(tester);
      final recues = <ZSubItemCrudRequest>[];
      final controller = _controllerWith(const <Map<String, dynamic>>[]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(
        _sousListe(defaultNewItem: const <String, Object?>{'origine': 'x'}),
        controller: controller,
        registry: _registry(ZSubListSeams(
          onCrud: (r) async {
            recues.add(r);
            return const ZSubItemCrudOutcome.proceed();
          },
        )),
      ));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(recues.single.data['origine'], 'x',
          reason: 'arbitrer une donnée amputée serait arbitrer autre chose');
    });

    testWidgets(
        'une clé DÉCLARÉE l\'emporte toujours sur son homonyme de la graine',
        (tester) async {
      _useTallSurface(tester);
      final controller = _controllerWith(const <Map<String, dynamic>>[]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(
        // `a` EST du sous-schéma : la graine le pré-remplit, elle ne le double
        // pas dans le résidu.
        _sousListe(defaultNewItem: const <String, Object?>{'a': 'graine'}),
        controller: controller,
      ));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).at(0), 'écrasé');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(_aggregated(controller).single['a'], 'écrasé');
    });

    testWidgets(
        'PÉRIMÈTRE : sans clé étrangère, la donnée créée est IDENTIQUE '
        '(contre-témoin de la rupture)', (tester) async {
      _useTallSurface(tester);
      final controller = _controllerWith(const <Map<String, dynamic>>[]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(
        _sousListe(defaultNewItem: const <String, Object?>{'a': 'x'}),
        controller: controller,
      ));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Comptes ABSOLUS : exactement les clés du sous-schéma, rien de plus.
      final item = _aggregated(controller).single;
      expect(item.keys.toList(), <String>['a', 'b']);
      expect(item, <String, dynamic>{'a': 'x', 'b': null});
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // F. CONTRE-TÉMOIN À COMPTES ABSOLUS — rien de déclaré ⇒ rien ne change
  // ══════════════════════════════════════════════════════════════════════════
  group('F. Contre-témoin (comptes ABSOLUS)', () {
    testWidgets(
        'aucun résolveur, aucune forme déclarée ⇒ structure d\'avant, au '
        'widget près', (tester) async {
      _useTallSurface(tester);
      final controller = _controllerWith(const <Map<String, dynamic>>[
        <String, dynamic>{'a': 'A1', 'b': 'B1'},
        <String, dynamic>{'a': 'A2', 'b': 'B2'},
      ]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _nominal(_sousListe(), controller: controller),
      );
      await tester.pump();

      // Comptes ABSOLUS d'une sous-liste compacte de 2 items, ACL ouverte :
      // 1 bouton d'ajout + (consulter/modifier/supprimer) × 2 lignes.
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsNWidgets(2));
      expect(find.byIcon(Icons.edit), findsNWidgets(2));
      expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
      // Aucun menu de débordement, aucun menu de gabarits.
      expect(find.byIcon(Icons.more_vert), findsNothing);
      expect(find.byType(PopupMenuButton<ZSubListItemTemplate>), findsNothing);
      // Aucune forme ouverte, aucune route poussée.
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(AppBar), findsNothing);
      // La donnée agrégée est celle de la graine, à la clé près.
      expect(_aggregated(controller), <Map<String, dynamic>>[
        <String, dynamic>{'a': 'A1', 'b': 'B1'},
        <String, dynamic>{'a': 'A2', 'b': 'B2'},
      ]);
    });

    testWidgets(
        'un registre SANS les nouveaux résolveurs n\'abonne rien au parent',
        (tester) async {
      _useTallSurface(tester);
      final controller = _controllerWith(
        const <Map<String, dynamic>>[
          <String, dynamic>{'a': 'A1', 'b': 'B1'},
        ],
        extra: const <String, Object?>{'etat': 'vide'},
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(
        _sousListe(mode: ZSubListDisplayMode.inline),
        controller: controller,
        // Un seam d'un AUTRE genre : le canal est là, les résolveurs non.
        registry: _registry(ZSubListSeams(
          itemTitleBuilder: (item) => 'T-${item['a']}',
        )),
        autres: const <ZFieldSpec>[_pilote],
      ));
      await tester.pump();

      final avant = _aggregated(controller);
      controller.setValue('etat', 'plein');
      await tester.pump();

      // Le schéma n'a pas bougé et la donnée non plus — comptes ABSOLUS.
      expect(find.widgetWithText(TextFormField, 'C'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'A'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'B'), findsOneWidget);
      expect(_aggregated(controller), avant);
    });
  });
}
