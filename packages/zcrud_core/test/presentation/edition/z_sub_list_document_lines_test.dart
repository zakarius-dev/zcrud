// **Lignes d'un document** (master-detail intra-formulaire) — le cas réel des
// lignes d'une commande d'achat/vente, porté depuis le moteur legacy d'un
// cinquième dépôt hôte (`erp/lib/modules/purchases/edition_forms.dart`).
//
// 🔴 CE QUE CE SITE MONTRE, ET QUE LE SOCLE NE SAVAIT PAS FAIRE :
//   1. le crochet CRUD **ne pouvait pas parler à l'utilisateur** — l'usage réel
//      affiche « X existe déjà dans la liste » AVANT de refuser. Le véto de la
//      v1.8.0 était **muet** ;
//   2. le crochet **ne pouvait pas écrire dans l'état du parent** — l'usage réel
//      y maintient les totaux (HT / TVA / TTC) qu'un champ voisin affiche ;
//   3. une **colonne de résumé ne pouvait pas être une valeur non éditable** :
//      « Montant HT » et « Montant TTC » sont **affichés, jamais saisis**, et
//      `_displayText` lisant `item.controller.valueOf(name)`, une colonne absente
//      du sous-schéma rendait **vide** (mesuré : 0 occurrence).
//
// 🔴 LA GARDE QUI PROUVE LE LOT (groupe A) reproduit le site en entier : colonnes
// calculées affichées et non saisies, crochet qui recalcule les montants, rejette
// un doublon **avec son motif rendu**, et met à jour une tranche voisine du
// parent. Si elle passe, le cas d'usage central est reproductible.
//
// 🔴 LE CONTRE-TÉMOIN (groupe E) assère des **comptes ABSOLUS** de widgets, pas
// une comparaison entre deux rendus passifs : un canal qui ajouterait un nœud à
// TOUT LE MONDE ferait bouger les deux mesures ensemble et resterait invisible.
//
// 🔴 LA GARDE DE BOUCLE (groupe D) est la plus adversariale : le correctif de
// parent écrit **la tranche même** que le résolveur de sous-schéma lit — le pire
// cas. Elle assère des **comptes** (écritures parentes, appels de crochet, appels
// de résolveur), pas une absence de plantage.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

// ── Le formulaire de référence : un document et ses lignes ──────────────────

const _sousChamps = <ZFieldSpec>[
  ZFieldSpec(
      name: 'designation', type: EditionFieldType.text, label: 'labelDesignation'),
  ZFieldSpec(
      name: 'quantite', type: EditionFieldType.number, label: 'labelQuantite'),
  ZFieldSpec(
      name: 'prixUnitaire', type: EditionFieldType.number, label: 'labelPU'),
];

/// Les colonnes du résumé — **deux d'entre elles ne sont pas des champs** :
/// `montantHT` et `montantTTC` sont calculés par le crochet et déposés dans
/// l'item. C'est exactement la déclaration du site legacy (`DynamicListField`
/// « Montant HT » / « Montant TTC », affichés, jamais saisis).
const _colonnes = <ZSubListSummaryColumn>[
  ZSubListSummaryColumn(name: 'designation', labelKey: 'labelDesignation'),
  ZSubListSummaryColumn(name: 'quantite', labelKey: 'labelQuantite'),
  ZSubListSummaryColumn(
    name: 'montantHT',
    labelKey: 'labelMontantHT',
    decimals: 2,
    suffixKey: 'devise',
  ),
  ZSubListSummaryColumn(
    name: 'montantTTC',
    labelKey: 'labelMontantTTC',
    decimals: 2,
    suffixKey: 'devise',
  ),
];

const _champLignes = ZFieldSpec(
  name: 'lignes',
  type: EditionFieldType.subItems,
  label: 'labelLignes',
  config: ZSubListConfig(
    itemFields: _sousChamps,
    displayMode: ZSubListDisplayMode.compact,
    summaryColumns: _colonnes,
    showSummaryHeaders: true,
  ),
);

/// Le **même** champ sans colonnes déclarées : les `summaryFields` nomment
/// pourtant `montantHT`. C'est le témoin d'opt-in — la valeur non éditable ne
/// s'affiche QUE là où une colonne la désigne.
const _champLignesLegacy = ZFieldSpec(
  name: 'lignes',
  type: EditionFieldType.subItems,
  label: 'labelLignes',
  config: ZSubListConfig(
    itemFields: _sousChamps,
    displayMode: ZSubListDisplayMode.compact,
    summaryFields: <String>['designation', 'quantite', 'montantHT'],
  ),
);

/// Champ **nu** du contre-témoin : rien de déclaré au-delà de ce que la v1.8.0
/// connaissait déjà.
const _champNu = ZFieldSpec(
  name: 'lignes',
  type: EditionFieldType.subItems,
  label: 'labelLignes',
  config: ZSubListConfig(
    itemFields: _sousChamps,
    displayMode: ZSubListDisplayMode.compact,
    summaryFields: <String>['designation', 'quantite'],
  ),
);

/// Libellés **métier** de l'hôte : c'est par eux que passent les en-têtes de
/// colonnes, le suffixe de devise ET le motif de véto (invariant FR-26 — aucun
/// libellé codé en dur dans le socle).
final _libelles = ZcrudLabels(<String, String>{
  'labelDesignation': 'Désignation',
  'labelQuantite': 'Quantité',
  'labelPU': 'Prix unitaire',
  'labelMontantHT': 'Montant HT',
  'labelMontantTTC': 'Montant TTC',
  'labelLignes': 'Lignes de commande',
  'devise': 'F',
  'ligneDupliquee': 'Cette référence figure déjà dans les lignes',
});

/// Surface haute : `DynamicEdition` monte ses champs par `ListView.builder`
/// (montage PARESSEUX). Sans elle, la sous-liste peut n'être jamais montée — la
/// garde serait alors verte pour la mauvaise raison.
void _surfaceHaute(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Contrôleur parent qui **journalise ses écritures de tranche**.
///
/// C'est le seul instrument capable de distinguer « le correctif a été appliqué
/// une fois » de « il a été appliqué deux fois avec la même valeur » : une
/// seconde écriture identique ne notifie pas (no-op natif de `ValueNotifier`) et
/// resterait donc **invisible** à un compteur de rebuilds.
class _ControleurJournal extends ZFormController {
  _ControleurJournal({super.initialValues, super.visibleFields});

  final List<String> ecritures = <String>[];

  @override
  void setValue(String name, Object? value, {bool derived = false}) {
    ecritures.add(name);
    super.setValue(name, value, derived: derived);
  }

  int ecrituresDe(String name) => ecritures.where((e) => e == name).length;
}

/// **Chemin NOMINAL** : le champ traverse `DynamicEdition` → `ZFieldWidget` →
/// famille. AUCUN `fieldBuilder` — c'est tout l'enjeu.
Widget _nominal(
  ZFieldSpec champ, {
  required ZFormController controller,
  ZSubListSeamRegistry? registry,
  List<Widget> observateurs = const <Widget>[],
}) =>
    MaterialApp(
      home: ZcrudScope(
        acl: const ZAllowAllAcl(),
        labels: _libelles,
        subListSeamRegistry: registry,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Scaffold(
            body: Column(
              children: <Widget>[
                ...observateurs,
                Expanded(
                  child: DynamicEdition(
                    controller: controller,
                    fields: <ZFieldSpec>[champ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

ZSubListSeamRegistry _registre(ZSubListSeams seams) =>
    ZSubListSeamRegistry()..register('lignes', seams);

double _nombre(Object? v) => v == null ? 0 : (num.tryParse('$v') ?? 0).toDouble();

List<Map<String, dynamic>> _lignesDe(Object? brut) {
  if (brut is! List) return <Map<String, dynamic>>[];
  return <Map<String, dynamic>>[
    for (final e in brut)
      if (e is Map) Map<String, dynamic>.from(e),
  ];
}

/// Le **crochet métier** du site réel : il normalise la ligne, recalcule ses
/// montants depuis le taux de taxe du DOCUMENT, refuse un doublon **en disant
/// pourquoi**, et met à jour les totaux du parent.
ZSubItemCrudHook _crochetLignes({
  List<ZCrudAction>? journal,
  Map<String, Object?>? correctifForce,
}) =>
    (request) async {
      journal?.add(request.action);
      final lire = request.parent;
      final taux = _nombre(lire?.call('tauxTva'));
      final deja = _lignesDe(lire?.call('lignes'));
      final data = Map<String, dynamic>.from(request.data);

      if (request.action == ZCrudAction.delete) {
        final restantes =
            deja.where((l) => l['id'] != data['id']).toList(growable: false);
        return ZSubItemCrudOutcome.proceed(
          parentPatch: correctifForce ?? _totaux(restantes),
        );
      }

      // Doublon : la règle métier du site (« X existe déjà dans la liste »).
      final doublon = deja.any((l) =>
          l['designation'] == data['designation'] && l['id'] != data['id']);
      if (doublon) {
        return const ZSubItemCrudOutcome.veto(
          reasonKey: 'ligneDupliquee',
          reasonFallback: 'Doublon',
        );
      }

      final ht = _nombre(data['quantite']) * _nombre(data['prixUnitaire']);
      data['id'] ??= 'L${deja.length + 1}';
      data['montantHT'] = ht;
      data['montantTTC'] = ht * (1 + taux / 100);

      final autres =
          deja.where((l) => l['id'] != data['id']).toList(growable: false);
      return ZSubItemCrudOutcome.replace(
        data,
        parentPatch: correctifForce ?? _totaux(<Map<String, dynamic>>[...autres, data]),
      );
    };

Map<String, Object?> _totaux(List<Map<String, dynamic>> lignes) {
  var ht = 0.0;
  var ttc = 0.0;
  for (final l in lignes) {
    ht += _nombre(l['montantHT']);
    ttc += _nombre(l['montantTTC']);
  }
  return <String, Object?>{'totalHT': ht, 'totalTTC': ttc};
}

Finder _dansLeFormulaireDItem(Finder quoi) =>
    find.descendant(of: find.byType(AlertDialog), matching: quoi);

Future<void> _ajouterLigne(
  WidgetTester tester, {
  required String designation,
  required String quantite,
  required String prix,
}) async {
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();
  final champs = _dansLeFormulaireDItem(find.byType(EditableText));
  await tester.enterText(champs.at(0), designation);
  await tester.enterText(champs.at(1), quantite);
  await tester.enterText(champs.at(2), prix);
  await tester.pump();
  await tester.tap(_dansLeFormulaireDItem(find.text('Save')));
  await tester.pumpAndSettle();
}

List<Map<String, dynamic>> _agrege(ZFormController c) =>
    _lignesDe(c.valueOf('lignes'));

void main() {
  // ── A. LA GARDE QUI PROUVE LE LOT ─────────────────────────────────────────
  group('A. Lignes de document (le site réel, reproduit)', () {
    testWidgets(
        '🔴 PRINCIPALE : montants calculés AFFICHÉS et NON SAISIS, doublon '
        'refusé AVEC son motif rendu, totaux du parent mis à jour',
        (tester) async {
      _surfaceHaute(tester);
      final actions = <ZCrudAction>[];
      final controller = _ControleurJournal(
        initialValues: const <String, Object?>{
          'tauxTva': 18,
          'lignes': <Map<String, dynamic>>[],
          'totalHT': 0,
          'totalTTC': 0,
        },
        visibleFields: const <String>['lignes'],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_nominal(
        _champLignes,
        controller: controller,
        registry: _registre(
          ZSubListSeams(onCrud: _crochetLignes(journal: actions)),
        ),
      ));
      await tester.pump();

      // 1. La ligne est saisie : désignation, quantité, prix unitaire. RIEN
      //    d'autre — les montants ne sont pas saisissables.
      await _ajouterLigne(tester,
          designation: 'Ciment', quantite: '2', prix: '1000');

      // 2. Les montants CALCULÉS sont rendus, mis en forme (2 décimales +
      //    suffixe de devise l10n).
      expect(find.text('2000.00\u00A0F'), findsOneWidget,
          reason: 'Montant HT calculé par le crochet, affiché en colonne');
      expect(find.text('2360.00\u00A0F'), findsOneWidget,
          reason: 'Montant TTC = HT × (1 + 18/100), affiché en colonne');

      // 3. Les en-têtes des colonnes calculées viennent de la table l10n de
      //    l'hôte — aucun nom technique, aucun libellé codé en dur.
      expect(find.text('Montant HT'), findsOneWidget);
      expect(find.text('Montant TTC'), findsOneWidget);
      expect(find.text('montantHT'), findsNothing);

      // 4. La donnée agrégée porte les montants ET l'identifiant attribué par
      //    le crochet — aucun des deux n'est un champ du sous-schéma.
      final apres = _agrege(controller);
      expect(apres, hasLength(1));
      expect(apres.first['montantHT'], 2000.0);
      expect(apres.first['montantTTC'], 2360.0);
      expect(apres.first['id'], 'L1');

      // 5. Les TOTAUX du parent — la tranche voisine — ont été mis à jour.
      expect(controller.valueOf('totalHT'), 2000.0);
      expect(controller.valueOf('totalTTC'), 2360.0);

      // 6. Le montant n'est PAS saisissable : le formulaire d'item n'expose que
      //    les trois sous-champs déclarés, et n'affiche nulle part le montant.
      await tester.tap(find.byIcon(Icons.edit).first);
      await tester.pumpAndSettle();
      expect(_dansLeFormulaireDItem(find.byType(EditableText)), findsNWidgets(3),
          reason: 'trois champs saisissables : les itemFields, pas un de plus');
      expect(_dansLeFormulaireDItem(find.text('2000.00\u00A0F')), findsNothing);
      expect(_dansLeFormulaireDItem(find.text('Montant HT')), findsNothing);
      await tester.tap(_dansLeFormulaireDItem(find.text('Cancel')));
      await tester.pumpAndSettle();

      // 7. Le DOUBLON est refusé, et l'utilisateur sait pourquoi.
      await _ajouterLigne(tester,
          designation: 'Ciment', quantite: '5', prix: '9999');
      expect(find.text('Cette référence figure déjà dans les lignes'),
          findsOneWidget,
          reason: 'motif du véto rendu, résolu par la table l10n de l\'hôte');
      expect(_agrege(controller), hasLength(1),
          reason: 'le véto n\'applique RIEN');
      expect(controller.valueOf('totalHT'), 2000.0,
          reason: 'un véto n\'applique pas non plus de correctif de parent');

      // Le crochet n'a vu que les deux créations : la consultation du
      // formulaire d'item, annulée, n'est pas une mutation.
      expect(actions, <ZCrudAction>[ZCrudAction.create, ZCrudAction.create]);
    });

    testWidgets(
        'la suppression d\'une ligne met à jour les totaux du parent',
        (tester) async {
      _surfaceHaute(tester);
      final controller = _ControleurJournal(
        initialValues: const <String, Object?>{
          'tauxTva': 18,
          'lignes': <Map<String, dynamic>>[],
        },
        visibleFields: const <String>['lignes'],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(
        _champLignes,
        controller: controller,
        registry: _registre(ZSubListSeams(onCrud: _crochetLignes())),
      ));
      await tester.pump();

      await _ajouterLigne(tester,
          designation: 'Ciment', quantite: '2', prix: '1000');
      expect(controller.valueOf('totalHT'), 2000.0);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(_agrege(controller), isEmpty);
      expect(controller.valueOf('totalHT'), 0.0);
      expect(controller.valueOf('totalTTC'), 0.0);
    });
  });

  // ── B. COLONNE NON ÉDITABLE — LES DEUX PROPRIÉTÉS ─────────────────────────
  group('B. Colonne de résumé non éditable', () {
    testWidgets(
        'la valeur hors sous-schéma S\'AFFICHE et le champ N\'EST PAS '
        'saisissable (les deux propriétés, pas une seule)', (tester) async {
      _surfaceHaute(tester);
      final controller = ZFormController(
        initialValues: const <String, Object?>{
          'lignes': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'L1',
              'designation': 'Ciment',
              'quantite': 3,
              'prixUnitaire': 500,
              'montantHT': 1500,
              'montantTTC': 1770,
            },
          ],
        },
        visibleFields: const <String>['lignes'],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(_champLignes, controller: controller));
      await tester.pump();

      // (a) elle s'affiche…
      expect(find.text('1500.00\u00A0F'), findsOneWidget);
      // (b) …et rien ne la rend saisissable : la sous-liste compacte ne monte
      //     aucun champ, et le formulaire d'item n'en monte que trois.
      expect(find.byType(EditableText), findsNothing);
      await tester.tap(find.byIcon(Icons.edit).first);
      await tester.pumpAndSettle();
      expect(_dansLeFormulaireDItem(find.byType(EditableText)), findsNWidgets(3));
      expect(_dansLeFormulaireDItem(find.text('1500')), findsNothing);
    });

    testWidgets(
        'OPT-IN STRICT : le même nom en `summaryFields` (sans colonne '
        'déclarée) rend TOUJOURS vide — un hôte passif ne bouge pas',
        (tester) async {
      _surfaceHaute(tester);
      final controller = ZFormController(
        initialValues: const <String, Object?>{
          'lignes': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'L1',
              'designation': 'Ciment',
              'quantite': 3,
              'montantHT': 1500,
            },
          ],
        },
        visibleFields: const <String>['lignes'],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _nominal(_champLignesLegacy, controller: controller),
      );
      await tester.pump();

      expect(find.text('Ciment'), findsOneWidget);
      expect(find.text('1500'), findsNothing,
          reason: 'comportement historique CONSERVÉ : summaryFields ne lit pas '
              'le résidu hors sous-schéma');
    });

    testWidgets('mise en forme : décimales sur un `num`, suffixe l10n, et '
        'une valeur non numérique passe INCHANGÉE', (tester) async {
      _surfaceHaute(tester);
      final controller = ZFormController(
        initialValues: const <String, Object?>{
          'lignes': <Map<String, dynamic>>[
            <String, dynamic>{'designation': 'A', 'montantHT': 1234.5},
            <String, dynamic>{'designation': 'B', 'montantHT': 'n/a'},
            <String, dynamic>{'designation': 'C'},
          ],
        },
        visibleFields: const <String>['lignes'],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(
        const ZFieldSpec(
          name: 'lignes',
          type: EditionFieldType.subItems,
          label: 'labelLignes',
          config: ZSubListConfig(
            itemFields: _sousChamps,
            displayMode: ZSubListDisplayMode.compact,
            summaryColumns: <ZSubListSummaryColumn>[
              ZSubListSummaryColumn(name: 'designation'),
              ZSubListSummaryColumn(
                name: 'montantHT',
                labelKey: 'labelMontantHT',
                decimals: 2,
                suffixKey: 'devise',
              ),
            ],
          ),
        ),
        controller: controller,
      ));
      await tester.pump();

      expect(find.text('1234.50\u00A0F'), findsOneWidget,
          reason: 'décimales fixes + suffixe l10n');
      expect(find.text('n/a\u00A0F'), findsOneWidget,
          reason: 'une valeur non numérique traverse `decimals` inchangée');
      // La cellule vide reste vide : ni « 0.00 », ni un suffixe solitaire.
      expect(find.text('0.00\u00A0F'), findsNothing);
      expect(find.text('F'), findsNothing);
    });
  });

  // ── C. MOTIF DE VÉTO ──────────────────────────────────────────────────────
  group('C. Motif de véto', () {
    testWidgets('un véto SANS motif ne rend AUCUN message (rétro-compat '
        'stricte du véto muet de la v1.8.0)', (tester) async {
      _surfaceHaute(tester);
      final controller = ZFormController(
        initialValues: const <String, Object?>{
          'lignes': <Map<String, dynamic>>[],
        },
        visibleFields: const <String>['lignes'],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(
        _champLignes,
        controller: controller,
        registry: _registre(ZSubListSeams(
          onCrud: (request) async => const ZSubItemCrudOutcome.veto(),
        )),
      ));
      await tester.pump();

      await _ajouterLigne(tester,
          designation: 'Ciment', quantite: '1', prix: '1');
      expect(find.byType(SnackBar), findsNothing);
      expect(_agrege(controller), isEmpty);
    });

    testWidgets('le motif est LOCALISÉ : la table de l\'hôte l\'emporte sur '
        'le repli, et le repli sur la clé', (tester) async {
      _surfaceHaute(tester);
      final controller = ZFormController(
        initialValues: const <String, Object?>{
          'lignes': <Map<String, dynamic>>[],
        },
        visibleFields: const <String>['lignes'],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(
        _champLignes,
        controller: controller,
        registry: _registre(ZSubListSeams(
          onCrud: (request) async => const ZSubItemCrudOutcome.veto(
            // Clé ABSENTE de la table : c'est le repli qui doit s'afficher.
            reasonKey: 'motifInconnu',
            reasonFallback: 'Refus sans traduction',
          ),
        )),
      ));
      await tester.pump();

      await _ajouterLigne(tester,
          designation: 'Ciment', quantite: '1', prix: '1');
      expect(find.text('Refus sans traduction'), findsOneWidget);
      expect(find.text('motifInconnu'), findsNothing,
          reason: 'la clé brute ne s\'affiche jamais quand un repli existe');
    });

    testWidgets('le motif est rendu pour une SUPPRESSION refusée aussi',
        (tester) async {
      _surfaceHaute(tester);
      final controller = ZFormController(
        initialValues: const <String, Object?>{
          'lignes': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'L1', 'designation': 'Ciment'},
          ],
        },
        visibleFields: const <String>['lignes'],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(
        _champLignes,
        controller: controller,
        registry: _registre(ZSubListSeams(
          onCrud: (request) async => const ZSubItemCrudOutcome.veto(
            reasonKey: 'ligneDupliquee',
          ),
        )),
      ));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Cette référence figure déjà dans les lignes'),
          findsOneWidget);
      expect(_agrege(controller), hasLength(1));
    });
  });

  // ── D. CORRECTIF DE PARENT : UNE FOIS, SANS BOUCLE ────────────────────────
  group('D. Correctif de parent', () {
    testWidgets(
        '🔴 appliqué UNE SEULE FOIS, sans boucle, même quand il écrit la '
        'tranche que le résolveur de sous-schéma LIT', (tester) async {
      _surfaceHaute(tester);
      var appelsResolveur = 0;
      var appelsCrochet = 0;
      final controller = _ControleurJournal(
        initialValues: const <String, Object?>{
          'tauxTva': 18,
          'lignes': <Map<String, dynamic>>[],
          'totalHT': 0,
        },
        visibleFields: const <String>['lignes'],
      );
      addTearDown(controller.dispose);

      // Le résolveur LIT `tauxTva` — donc le champ s'y abonne. Le correctif
      // écrira cette tranche-là : le pire cas.
      final registry = _registre(ZSubListSeams(
        subSchemaResolver: (parent) {
          appelsResolveur++;
          parent('tauxTva');
          return _sousChamps;
        },
        onCrud: (request) async {
          appelsCrochet++;
          return ZSubItemCrudOutcome.replace(
            <String, dynamic>{...request.data, 'montantHT': 42},
            parentPatch: const <String, Object?>{
              'totalHT': 42,
              'tauxTva': 20,
            },
          );
        },
      ));

      await tester.pumpWidget(
        _nominal(_champLignes, controller: controller, registry: registry),
      );
      await tester.pump();
      final resolveurAuMontage = appelsResolveur;
      controller.ecritures.clear();

      await _ajouterLigne(tester,
          designation: 'Ciment', quantite: '1', prix: '1');

      // 1. Le crochet a été appelé UNE fois — un correctif ne le rappelle pas.
      expect(appelsCrochet, 1);
      // 2. Chaque tranche du correctif a été écrite EXACTEMENT une fois. Un
      //    compteur de rebuilds ne verrait pas une seconde écriture identique ;
      //    ce journal, si.
      expect(controller.ecrituresDe('totalHT'), 1);
      expect(controller.ecrituresDe('tauxTva'), 1);
      // 3. La re-résolution déclenchée par l'écriture de `tauxTva` a lieu, et
      //    s'arrête là : le schéma rendu est le même, aucune cascade.
      expect(appelsResolveur, resolveurAuMontage + 1,
          reason: 'UNE re-résolution, déclenchée par l\'écriture de la tranche '
              'suivie — puis plus rien : le schéma rendu est le même, aucune '
              'cascade, aucune boucle');
      // 4. La donnée agrégée a survécu.
      expect(_agrege(controller), hasLength(1));
      expect(controller.valueOf('totalHT'), 42);
      expect(controller.valueOf('tauxTva'), 20);
    });

    testWidgets(
        'la tranche de la SOUS-LISTE elle-même est ignorée : un correctif ne '
        'peut pas écraser l\'agrégation', (tester) async {
      _surfaceHaute(tester);
      final controller = _ControleurJournal(
        initialValues: const <String, Object?>{
          'tauxTva': 0,
          'lignes': <Map<String, dynamic>>[],
        },
        visibleFields: const <String>['lignes'],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(
        _champLignes,
        controller: controller,
        registry: _registre(ZSubListSeams(
          onCrud: _crochetLignes(
            correctifForce: const <String, Object?>{
              'lignes': 'AGRÉGATION DÉTRUITE',
              'totalHT': 7,
            },
          ),
        )),
      ));
      await tester.pump();

      await _ajouterLigne(tester,
          designation: 'Ciment', quantite: '2', prix: '1000');

      expect(_agrege(controller), hasLength(1),
          reason: 'la tranche du champ conteneur n\'est pas écrasable');
      expect(controller.valueOf('lignes'), isA<List<Object?>>());
      expect(controller.valueOf('totalHT'), 7,
          reason: 'les AUTRES tranches du correctif, elles, sont écrites');
    });

    testWidgets(
        'sans correctif déclaré, AUCUNE tranche parente n\'est écrite '
        '(rétro-compat stricte)', (tester) async {
      _surfaceHaute(tester);
      final controller = _ControleurJournal(
        initialValues: const <String, Object?>{
          'lignes': <Map<String, dynamic>>[],
        },
        visibleFields: const <String>['lignes'],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(
        _champLignes,
        controller: controller,
        registry: _registre(ZSubListSeams(
          onCrud: (request) async => const ZSubItemCrudOutcome.proceed(),
        )),
      ));
      await tester.pump();
      controller.ecritures.clear();

      await _ajouterLigne(tester,
          designation: 'Ciment', quantite: '1', prix: '1');

      // La tranche du champ lui-même est écrite par l'agrégation (`onChanged` →
      // `setValue`), comme depuis toujours ; AUCUNE autre ne l'est.
      expect(controller.ecritures.toSet(), <String>{'lignes'},
          reason: 'la seule voie d\'écriture reste l\'agrégation par onChanged');
      expect(_agrege(controller), hasLength(1));
    });

    testWidgets('le crochet LIT l\'état du parent par nom (ZValueOf), sans '
        's\'y abonner', (tester) async {
      _surfaceHaute(tester);
      final vues = <Object?>[];
      final controller = ZFormController(
        initialValues: const <String, Object?>{
          'tauxTva': 18,
          'devise': 'XOF',
          'lignes': <Map<String, dynamic>>[],
        },
        visibleFields: const <String>['lignes'],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(
        _champLignes,
        controller: controller,
        registry: _registre(ZSubListSeams(
          onCrud: (request) async {
            vues
              ..add(request.parent?.call('tauxTva'))
              ..add(request.parent?.call('devise'));
            return const ZSubItemCrudOutcome.proceed();
          },
        )),
      ));
      await tester.pump();

      await _ajouterLigne(tester,
          designation: 'Ciment', quantite: '1', prix: '1');
      expect(vues, <Object?>[18, 'XOF']);
    });
  });

  // ── E. CONTRE-TÉMOIN À COMPTES ABSOLUS ────────────────────────────────────
  group('E. Contre-témoin', () {
    testWidgets(
        '🔴 rien de déclaré ⇒ structure IDENTIQUE — comptes ABSOLUS de '
        'widgets (une comparaison entre deux rendus passifs ne verrait pas un '
        'nœud ajouté à tout le monde)', (tester) async {
      _surfaceHaute(tester);
      final controller = ZFormController(
        initialValues: const <String, Object?>{
          'lignes': <Map<String, dynamic>>[
            <String, dynamic>{'designation': 'Ciment', 'quantite': 3},
          ],
        },
        visibleFields: const <String>['lignes'],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(_champNu, controller: controller));
      await tester.pump();

      // Une ligne, deux colonnes, trois actions natives (view/edit/delete).
      expect(find.byType(IconButton), findsNWidgets(4),
          reason: '3 actions de ligne + le bouton d\'ajout — pas un de plus');
      expect(find.byType(PopupMenuButton<ZSubItemMenuOption>), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(EditableText), findsNothing);
      // Textes rendus : le libellé de section, les deux EN-TÊTES de colonnes
      // (le rendu tabulaire est le défaut depuis que `compact` l'est) et les
      // deux cellules. Aucun badge, aucun texte de plus.
      expect(find.byType(Text), findsNWidgets(5));
      expect(find.text('Désignation'), findsOneWidget);
      expect(find.text('Quantité'), findsOneWidget);
      expect(find.text('Lignes de commande'), findsOneWidget);
      expect(find.text('Ciment'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });
}
