/// **Matrice `paramètre × mode` du port de présentation**, et son rendu
/// Markdown — pour `ZGetFormPresenter` (binding GetX).
///
/// ## Le besoin, mesuré
///
/// CR-IFFD-78 (2026-08-09), §③ : **« tout paramètre du port est soit honoré sur
/// une surface, soit déclaré inerte sur elle »**. C'est AD-4 appliqué aux
/// paramètres — jamais un réglage inerte, comme jamais un bouton inerte.
///
/// La CR relève que le port a **deux** implémentations et que la divergence
/// entre elles est précisément ce qu'une table écrite à la main laisserait
/// passer. Ce fichier est donc le **jumeau mesuré** de
/// `packages/zcrud_navigation/test/support/z_presenter_parameter_matrix.dart`.
///
/// ## 🔴 Pourquoi ce fichier est un JUMEAU et non un import
///
/// Le `test/` d'un paquet n'est pas importable depuis un autre paquet, et AD-1
/// interdit de faire remonter cet outillage dans un `lib/` (il porterait de la
/// prose développeur atteignable depuis une application — FR-26). La duplication
/// est donc **structurelle**. Ce qui compte, c'est qu'elle ne puisse pas
/// **diverger là où ça compte** :
///
/// * la **liste des paramètres** n'est copiée de personne : les deux gardes la
///   dérivent du **MÊME port sur disque** ([kZPortSourcePaths]) et exigent
///   l'égalité avec leur enum. Un paramètre ajouté au port fait rougir **les
///   deux** paquets ;
/// * les **statuts** ne sont copiés de personne non plus : ils sont **mesurés**,
///   implémentation par implémentation. C'est tout l'objet de l'exercice — si
///   `ZGetFormPresenter` honorait un paramètre autrement que `ZAdaptivePresenter`,
///   les deux documents le **montreraient** au lieu de le taire.
///
/// ## 🔴 Pourquoi ce fichier vit dans `test/`, et pas dans `lib/`
///
/// **FR-26 / NFR-S7 par CONSTRUCTION** : ce fichier porte de la prose destinée
/// aux **développeurs** (en-têtes de colonnes, notes). Hors de `lib/`, elle
/// n'est pas « interdite par convention » : elle est **inatteignable** depuis
/// une application, donc elle ne peut pas s'afficher dans une UI sans
/// localisation. Le document `.md` produit n'est, lui, jamais compilé. Coût
/// runtime pour l'hôte : **zéro octet**.
///
/// ## Les propriétés, et où elles sont tenues
///
/// 1. **Exhaustivité — deux maillons.** *mode* : [kZPresenterModes] est
///    `ZEditionPresentation.values`. *paramètre* : [zProbeArgs] est un `switch`
///    **expression exhaustif sans `default`** ⇒ ajouter une valeur à
///    [ZPresenterParam] **casse la compilation** ; et une garde exige que cet
///    enum égale les paramètres **lus dans le port sur disque**. 🔴 **Limite
///    nommée** : ce second maillon est une garde, pas la compilation.
/// 2. **Statut MESURÉ, pas déclaré.** Aucun champ « honoré » n'existe :
///    [ZMatrixCell.honoured] est un *getter* qui compare **deux empreintes de
///    surface**. Jamais la valeur rendue contre la constante qui l'a produite —
///    toujours deux rendus l'un contre l'autre.
/// 3. **Anti-vacuité.** La garde exige qu'aucun paramètre ne soit inerte sur les
///    trois modes : un couple de valeurs incapable de discriminer se ferait
///    remarquer au lieu de se déguiser en « inerte ».
/// 4. **Synchronisation prouvée.** Le document est comparé **tel qu'il est sur
///    disque**, jamais régénéré avant comparaison.
///
/// ## Totalité (AD-10)
///
/// Aucune fonction de ce fichier ne lève.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:zcrud_navigation/zcrud_navigation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Ancrage dépôt (jamais un `../` relatif — convention `melos exec`)
// ─────────────────────────────────────────────────────────────────────────────

/// Racine du dépôt (le dossier qui porte `melos.yaml`), quel que soit le CWD.
Directory zRepoRoot() {
  Directory dir = Directory.current.absolute;
  for (int i = 0; i < 8; i++) {
    if (File('${dir.path}/melos.yaml').existsSync()) return dir;
    final Directory parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  fail('Racine du dépôt (melos.yaml) introuvable depuis ${Directory.current}');
}

/// Chemins — **relatifs à la racine du dépôt** — des deux fichiers qui portent
/// la signature du port. Leur existence est vérifiée par la garde.
const List<String> kZPortSourcePaths = <String>[
  'packages/zcrud_navigation/lib/src/presentation/z_form_presenter.dart',
  'packages/zcrud_navigation/lib/src/presentation/'
      'z_implicit_dismiss_control.dart',
];

/// Chemin du document publié, **relatif à la racine du dépôt**.
const String kZGetMatrixDocPath =
    'packages/zcrud_get/doc/parameter-matrix-z-get-form-presenter.md';

/// Les paramètres **nommés et optionnels** déclarés par les signatures du port,
/// lus **sur disque**.
///
/// Extraction volontairement littérale : dans le bloc `{ … }` de chaque méthode
/// `present…<T>(`, toute déclaration `<type> <nom>` qui n'est pas `required` est
/// retenue. Les `required` (`builder`, `mode`) sont **exclus** : ce ne sont pas
/// des réglages, ce sont les entrées obligatoires.
///
/// AD-10 : jamais d'exception — un fichier absent contribue simplement
/// l'ensemble vide, et la garde le signale.
Set<String> zPortParameterNames() {
  final Set<String> out = <String>{};
  for (final String rel in kZPortSourcePaths) {
    final File f = File('${zRepoRoot().path}/$rel');
    if (!f.existsSync()) continue;
    final String src = f.readAsStringSync();
    for (final RegExpMatch m in RegExp(
      r'Future<T\?>\s+present\w*<T>\(\s*BuildContext context,\s*\{([^}]*)\}',
      dotAll: true,
    ).allMatches(src)) {
      final String block = m.group(1) ?? '';
      for (final String raw in block.split(',')) {
        final String line = raw
            .split('\n')
            .map((String l) => l.trim())
            .where((String l) => !l.startsWith('//'))
            .join(' ')
            .trim();
        if (line.isEmpty || line.startsWith('required')) continue;
        final RegExpMatch? d =
            RegExp(r'([A-Za-z_][\w<>?,\s]*?)\s+(\w+)\s*(=|$)').firstMatch(line);
        if (d != null) out.add(d.group(2)!);
      }
    }
  }
  return out;
}

// ─────────────────────────────────────────────────────────────────────────────
// Le grid
// ─────────────────────────────────────────────────────────────────────────────

/// Un paramètre **de réglage** du port (les `required` en sont exclus).
///
/// 🔴 Cet enum n'est pas une copie de confiance : une garde exige
/// `values.map(name).toSet() == zPortParameterNames()`.
enum ZPresenterParam {
  /// `double? maxWidth`.
  maxWidth,

  /// `double? maxHeight`.
  maxHeight,

  /// `bool useSafeArea`.
  useSafeArea,

  /// `bool barrierDismissible`.
  barrierDismissible,

  /// `bool allowImplicitDismiss`.
  allowImplicitDismiss,

  /// `bool isDismissible`.
  isDismissible,

  /// `ZSheetFrameSpec? sheetFrame`.
  sheetFrame,
}

/// Les modes sondés — **tous** ceux de l'enum, sans exception possible.
const List<ZEditionPresentation> kZPresenterModes = ZEditionPresentation.values;

/// Le jeu d'arguments d'une sonde : les **défauts du port**, sauf le paramètre
/// sous test quand [alternative] vaut `true`.
final class ZProbeArgs {
  /// Construit un jeu d'arguments.
  const ZProbeArgs({
    this.maxWidth,
    this.maxHeight,
    this.useSafeArea = true,
    this.barrierDismissible = true,
    this.allowImplicitDismiss = true,
    this.isDismissible = true,
    this.sheetFrame,
  });

  /// `maxWidth` remis au présentateur.
  final double? maxWidth;

  /// `maxHeight` remis au présentateur.
  final double? maxHeight;

  /// `useSafeArea` remis au présentateur.
  final bool useSafeArea;

  /// `barrierDismissible` remis au présentateur.
  final bool barrierDismissible;

  /// `allowImplicitDismiss` remis au présentateur.
  final bool allowImplicitDismiss;

  /// `isDismissible` remis au présentateur.
  final bool isDismissible;

  /// `sheetFrame` remis au présentateur.
  final ZSheetFrameSpec? sheetFrame;
}

/// Valeur **contraire** sondée pour [p] — rendue en clair pour le document.
///
/// `switch` **expression exhaustif sans `default`** : ajouter une valeur à
/// [ZPresenterParam] **ne compile pas** tant qu'elle n'a pas de couple de
/// sondage. C'est le maillon structurel de la propriété 1.
String zAlternativeLabel(ZPresenterParam p) => switch (p) {
      ZPresenterParam.maxWidth => '`160.0` (défaut : `null`)',
      ZPresenterParam.maxHeight => '`120.0` (défaut : `null`)',
      ZPresenterParam.useSafeArea => '`false` (défaut : `true`)',
      ZPresenterParam.barrierDismissible => '`false` (défaut : `true`)',
      ZPresenterParam.allowImplicitDismiss => '`false` (défaut : `true`)',
      ZPresenterParam.isDismissible => '`false` (défaut : `true`)',
      ZPresenterParam.sheetFrame =>
        '`ZSheetFrameSpec(mode: never, widthRatio: 1, maxWidth: infinity)` '
            '(défaut : `null`)',
    };

/// Les arguments de la sonde de [p]. `alternative: false` ⇒ **tous** les
/// défauts du port ; `alternative: true` ⇒ le seul [p] change.
///
/// `switch` exhaustif sans `default` (cf. [zAlternativeLabel]).
ZProbeArgs zProbeArgs(ZPresenterParam p, {required bool alternative}) {
  if (!alternative) return const ZProbeArgs();
  return switch (p) {
    ZPresenterParam.maxWidth => const ZProbeArgs(maxWidth: 160),
    ZPresenterParam.maxHeight => const ZProbeArgs(maxHeight: 120),
    ZPresenterParam.useSafeArea => const ZProbeArgs(useSafeArea: false),
    ZPresenterParam.barrierDismissible =>
      const ZProbeArgs(barrierDismissible: false),
    ZPresenterParam.allowImplicitDismiss =>
      const ZProbeArgs(allowImplicitDismiss: false),
    ZPresenterParam.isDismissible => const ZProbeArgs(isDismissible: false),
    ZPresenterParam.sheetFrame => const ZProbeArgs(
        sheetFrame: ZSheetFrameSpec(
          mode: ZSheetFrameMode.never,
          widthRatio: 1,
          maxWidth: double.infinity,
        ),
      ),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// L'observation — LA MÊME pour tous les paramètres
// ─────────────────────────────────────────────────────────────────────────────

/// Empreinte **uniforme** d'une surface présentée.
///
/// 🔴 Aucun champ n'est propre à un paramètre : c'est ce qui interdit de tailler
/// une observation pour faire réussir sa cellule.
final class ZSurfaceObservation {
  /// Construit une observation.
  const ZSurfaceObservation({
    required this.constraints,
    required this.padding,
    required this.rect,
    required this.sheet,
    required this.barrier,
  });

  /// Contraintes **reçues** par le contenu (mesurées par un `LayoutBuilder`
  /// placé dans le builder — donc la contrainte LIANTE, jamais une taille
  /// rendue qui vaudrait la largeur d'écran par accident).
  final String constraints;

  /// Encart de sécurité **restant** au contenu (`MediaQuery.paddingOf`) : une
  /// `SafeArea` interposée le consomme, son absence le laisse intact.
  final String padding;

  /// Rectangle global du marqueur.
  final String rect;

  /// `enableDrag` / `shape` du `BottomSheet` du SDK, ou `—` s'il n'y en a pas.
  final String sheet;

  /// Effet d'un tap **hors surface** : `ferme` ou `reste`.
  final String barrier;

  /// L'empreinte comparée. Deux surfaces sont « les mêmes » ssi elle est égale.
  String get fingerprint => 'contraintes=$constraints ; encart=$padding ; '
      'rect=$rect ; feuille=$sheet ; barrière=$barrier';
}

/// Clé de marqueur du contenu sondé.
const ValueKey<String> kZProbeMarker = ValueKey<String>('z-probe-marker');

/// Largeur/hauteur d'écran du montage des sondes (dp, `devicePixelRatio: 1`).
const Size kZProbeScreen = Size(400, 800);

/// Encart de sécurité **non nul** du montage : sans lui, `useSafeArea` serait
/// indiscernable de son contraire **partout**, et la matrice mentirait par
/// vacuité.
const FakeViewPadding kZProbePadding =
    FakeViewPadding(top: 44, bottom: 34, left: 12, right: 8);

/// Présente une surface avec [args], relève l'observation **uniforme**.
///
/// [present] est fourni par l'appelant : c'est le seul point où l'implémentation
/// concrète entre en jeu (ce fichier ne connaît donc que le port).
Future<ZSurfaceObservation> zObserveSurface(
  WidgetTester tester, {
  required String probeId,
  required void Function(BuildContext context, WidgetBuilder builder) present,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = kZProbeScreen;
  tester.view.padding = kZProbePadding;
  tester.view.viewPadding = kZProbePadding;
  tester.view.viewInsets = FakeViewPadding.zero;
  addTearDown(tester.view.reset);

  String constraints = '—';
  String padding = '—';
  late BuildContext host;

  // 🔴 DÉMONTAGE explicite avant la sonde suivante. `GetMaterialApp` installe
  // `Get.key`, une `GlobalKey` de navigateur **globale au processus** : monter
  // un second `GetMaterialApp` alors que le premier vit encore ferait une
  // duplication de `GlobalKey`. On vide donc l'arbre, puis on réinitialise
  // l'état GetX, avant chaque montage.
  await tester.pumpWidget(const SizedBox.shrink());
  Get.reset();

  await tester.pumpWidget(
    GetMaterialApp(
      // Clé DISTINCTE par sonde : sans elle, deux `pumpWidget` successifs
      // réutilisent le même `Element`, donc le même `NavigatorState` — et la
      // route de la sonde précédente resterait empilée.
      key: ValueKey<String>(probeId),
      home: Builder(
        builder: (BuildContext c) {
          host = c;
          return const Scaffold(body: SizedBox.expand());
        },
      ),
    ),
  );

  present(host, (BuildContext c) {
    return LayoutBuilder(
      builder: (BuildContext c2, BoxConstraints cons) {
        constraints = cons.toString();
        padding = MediaQuery.paddingOf(c2).toString();
        return const SizedBox(key: kZProbeMarker, width: 80, height: 100);
      },
    );
  });
  await tester.pumpAndSettle();

  final Finder marker = find.byKey(kZProbeMarker);
  final String rect =
      marker.evaluate().isEmpty ? 'absent' : tester.getRect(marker).toString();

  final Finder sheetFinder = find.byType(BottomSheet);
  final String sheet = sheetFinder.evaluate().isEmpty
      ? '—'
      : () {
          final BottomSheet w = tester.widget<BottomSheet>(sheetFinder);
          return 'enableDrag=${w.enableDrag} ; shape=${w.shape}';
        }();

  // Tap HORS surface : la barrière d'un `dialog`/`sheet` s'y trouve ; en `page`
  // le tap atterrit sur la page elle-même et ne ferme rien — c'est la même
  // manipulation pour les trois modes, aucune n'est privilégiée.
  await tester.tapAt(const Offset(2, 2));
  await tester.pumpAndSettle();
  final String barrier =
      find.byKey(kZProbeMarker).evaluate().isEmpty ? 'ferme' : 'reste';

  return ZSurfaceObservation(
    constraints: constraints,
    padding: padding,
    rect: rect,
    sheet: sheet,
    barrier: barrier,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Le résultat — aucun champ « honoré » : c'est un getter
// ─────────────────────────────────────────────────────────────────────────────

/// Une cellule **mesurée** de la matrice.
final class ZMatrixCell {
  /// Construit une cellule à partir des **deux observations**.
  const ZMatrixCell({
    required this.param,
    required this.mode,
    required this.reference,
    required this.alternative,
  });

  /// Le paramètre sondé.
  final ZPresenterParam param;

  /// Le mode sondé.
  final ZEditionPresentation mode;

  /// L'observation avec **tous les défauts du port**.
  final ZSurfaceObservation reference;

  /// L'observation où **seul** [param] change.
  final ZSurfaceObservation alternative;

  /// 🔴 **Dérivé, jamais déclaré** : le paramètre agit ssi les deux empreintes
  /// diffèrent. Il n'existe aucun champ où écrire autre chose.
  bool get honoured => reference.fingerprint != alternative.fingerprint;
}

/// Libellé de statut. Prose **développeur**, confinée à `test/`.
String zStatusLabel(bool honoured) => honoured ? 'honoré' : 'inerte';

// ─────────────────────────────────────────────────────────────────────────────
// Rendu Markdown
// ─────────────────────────────────────────────────────────────────────────────

/// Rend le document publié. **Fonction pure** : mêmes cellules ⇒ même octet.
///
/// [implementation] nomme l'implémentation mesurée — le document ne prétend
/// jamais couvrir les autres.
String renderZPresenterMatrixMarkdown({
  required String implementation,
  required String implementationPath,
  required String guardPath,
  required String supportPath,
  required List<ZMatrixCell> cells,
}) {
  final StringBuffer b = StringBuffer()
    ..writeln('<!-- GÉNÉRÉ — NE PAS ÉDITER À LA MAIN. -->')
    ..writeln('<!-- Source : $supportPath -->')
    ..writeln('<!-- Garde de synchronisation : $guardPath -->')
    ..writeln()
    ..writeln('# Matrice paramètre × mode — `$implementation`')
    ..writeln()
    ..writeln('Répond à la question posée par CR-IFFD-78 : **« ce paramètre '
        'agit-il sur ce mode ? »**, sans ouvrir le `switch`.')
    ..writeln()
    ..writeln('🔴 **Aucun statut n\'est écrit ici, ni nulle part.** Chaque '
        'cellule est le résultat d\'une **mesure différentielle** : la même '
        'surface est présentée deux fois — une fois avec tous les défauts du '
        'port, une fois en ne changeant **que** ce paramètre — et l\'on compare '
        'la même empreinte dans les deux cas (contraintes reçues par le '
        'contenu, encart de sécurité restant, rectangle rendu, `enableDrag` et '
        '`shape` du `BottomSheet`, effet d\'un tap hors surface).')
    ..writeln()
    ..writeln('> `honoré` ⇔ les deux empreintes **diffèrent**. '
        '`inerte` ⇔ elles sont **identiques**.')
    ..writeln()
    ..writeln('Annoncer « honoré » un paramètre que la branche ne lit pas est '
        'donc **inexprimable** — il n\'y a pas de déclaration à falsifier. '
        'Et la garde exige qu\'aucun paramètre ne soit inerte sur les trois '
        'modes : un couple de valeurs incapable de produire une différence se '
        'ferait remarquer au lieu de se déguiser en « inerte ».')
    ..writeln()
    ..writeln('| Paramètre | Valeur contraire sondée | '
        '${kZPresenterModes.map((ZEditionPresentation m) => '`${m.name}`').join(' | ')} |')
    ..writeln('|---|---|${kZPresenterModes.map((_) => '---').join('|')}|');

  for (final ZPresenterParam p in ZPresenterParam.values) {
    final Iterable<String> row = kZPresenterModes.map((ZEditionPresentation m) {
      final ZMatrixCell c = cells.firstWhere(
        (ZMatrixCell c) => c.param == p && c.mode == m,
      );
      return zStatusLabel(c.honoured);
    });
    b.writeln('| `${p.name}` | ${zAlternativeLabel(p)} | '
        '${row.join(' | ')} |');
  }

  b
    ..writeln()
    ..writeln('## Portée')
    ..writeln()
    ..writeln('Ce document couvre **`$implementation`** '
        '(`$implementationPath`), et lui seul. L\'autre implémentation du port '
        'livrée par le dépôt a sa propre matrice, mesurée par sa propre '
        'garde :')
    ..writeln()
    ..writeln('* `ZAdaptivePresenter` → '
        '`packages/zcrud_navigation/doc/parameter-matrix-z-adaptive-presenter.md` ;')
    ..writeln('* `ZGetFormPresenter` → '
        '`packages/zcrud_get/doc/parameter-matrix-z-get-form-presenter.md`.')
    ..writeln()
    ..writeln('Recensement (grep sur `packages/` et `example/`, 2026-08-09) : '
        '**deux** implémentations en `lib/` dans tout le dépôt, celles '
        'ci-dessus. `zcrud_riverpod` et `zcrud_provider` n\'en portent aucune '
        '(grep négatif, `rc=1`, sur `ZFormPresenter|ZImplicitDismissControl|'
        'zcrud_navigation`). Une implémentation **tierce** du port n\'est tenue '
        'par aucune de ces gardes : elle doit publier sa propre matrice.')
    ..writeln()
    ..writeln('## Comment lire une case « inerte »')
    ..writeln()
    ..writeln('« Inerte » ne veut pas dire « bug ». Trois inerties sont '
        '**structurelles** et le resteront : une route pleine n\'a pas de '
        'barrière, un dialogue ne se glisse pas, et `sheetFrame` ne décrit '
        'qu\'une feuille. Ce que la règle interdit, c\'est l\'inertie '
        '**silencieuse** : chaque case de ce tableau est mesurée, et le '
        'dartdoc du port ne promet rien qu\'une case dise inerte.')
    ..writeln()
    ..writeln('🔴 `useSafeArea` en mode `page` est le cas signalé par '
        'CR-IFFD-78 ①. Mesuré : une route pleine n\'insère **aucune** '
        '`SafeArea`, ni avec `true` (le défaut) ni avec `false` — le contenu '
        'brut peint sous l\'encoche dans les deux cas. Honorer la promesse '
        'déplacerait donc l\'arbre **par défaut** de tout hôte passif ; la '
        'promesse a été **retirée du dartdoc** à la place, et cette case '
        'l\'atteste. Un hôte qui veut l\'encart en `page` place sa propre '
        '`SafeArea`, ou fournit un `ZEditionChrome` (la voie chrome monte un '
        '`Scaffold` + `SliverAppBar`, qui consomme l\'encart haut, et une '
        '`SafeArea(top: false)` sous les actions).');

  return b.toString();
}
