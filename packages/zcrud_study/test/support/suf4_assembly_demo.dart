/// SUF-4 / T7 — **DÉMO ASSEMBLÉE de bout en bout** : grille de dossiers →
/// page-détail → flux de session.
///
/// ## 🔴 Pourquoi cette démo vit ICI et pas dans `example/` (voie (b), AC7)
///
/// Le conflit structurel annoncé par la story est **RÉEL et TOUJOURS OUVERT**
/// après SUF-2/SUF-3 — re-prouvé sur disque le 2026-07-26 :
///
/// ```
/// $ awk '/^dependencies:/,/^dev_dependencies:/' packages/zcrud_study/pubspec.yaml | grep -v '^#'
///   zcrud_mindmap: ^0.18.0      ← arête DURE
///   zcrud_exam: ^0.18.0         ← arête DURE
/// $ grep -rn "package:zcrud_mindmap" packages/zcrud_study/lib/
///   lib/src/presentation/z_study_mindmap_section.dart:35
///   lib/src/domain/z_mindmap_generation_port.dart:30
/// ```
///
/// Ces arêtes sont **consommées par du vrai code** (`ZStudyMindmapSection`,
/// `ZMindmapGenerationPort`) : les rendre optionnelles serait une refonte
/// d'architecture, hors périmètre SUF-4. Ajouter `zcrud_study` à `example/`
/// exigerait un `dependency_overrides: zcrud_mindmap: path:` — que
/// `example/test/boundary_deps_test.dart` fait **ROUGIR** par construction (sa
/// liste `forbidden` couvre `dependencies` **ET** `dependency_overrides`).
/// L'invariant AC10 de su-10 (« `zcrud_mindmap` reste INTERDIT dans le lock de
/// l'app ») n'est donc **PAS dégradé** : le parcours est assemblé ici, dans le
/// package qui possède déjà toutes les arêtes légitimes.
///
/// ## Ce que la démo assemble — **surfaces PUBLIQUES uniquement**
///
/// | Étape | Widget zcrud (barrel) | Package |
/// |---|---|---|
/// | grille | `ZAdaptiveGrid.builder` + `ZFolderCard` | `zcrud_responsive` / `zcrud_study` |
/// | détail | `ZStudyFolderDetail` (+ `ZSubfolderNavSpec`, sections) | `zcrud_study` |
/// | session | `ZSessionModeSelector` → `ZSessionProgressIndicator` + `ZSrsQualityButtons` → `ZSessionSummaryView` | `zcrud_session` |
///
/// Tout le reste (données, navigation, libellés, streak, horloge) est un **fake
/// app-side** — exactement ce qu'une app réelle fournirait. Aucun `import
/// package:.../src/...`, aucune règle métier réimplémentée.
///
/// ## Apparence neutre & thémable (AC8)
///
/// L'hôte n'impose **aucun** look : il monte un `ZcrudScope` racine
/// (thème + labels **injectés**, comme la démo su-10) et laisse chaque widget
/// résoudre couleurs/typo par les seams. Le seul token posé ici est le thème
/// **de l'exemple**, remplaçable d'une ligne.
///
/// ## Ce que la démo exerce des fermetures SUF-4
///
/// - `ZSessionProgressStyle.linear` (paire 4) — barre continue de la session ;
/// - `ZSrsQualityEmphasis` (paire 1) — fond teinté + bord, valeurs **côté app** ;
/// - `ZQualityBreakdownCoverage.wholeScale` (paire 2) — bilan à longueur stable.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudScope, ZcrudTheme;
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show ZFlashcard, ZRepetitionInfo, ZSrsConfig;
import 'package:zcrud_responsive/zcrud_responsive.dart' show ZAdaptiveGrid;
import 'package:zcrud_session/zcrud_session.dart';
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZStudySessionResult, ZStudyStreak;

/// Un dossier de démonstration — **fake app-side** (aucune entité zcrud).
class DemoFolder {
  /// Construit un dossier de démo.
  const DemoFolder({
    required this.id,
    required this.title,
    required this.colorKey,
    required this.cardCount,
  });

  /// Identifiant opaque.
  final String id;

  /// Titre affiché par la carte.
  final String title;

  /// Clé de couleur **opaque** passée telle quelle à `ZFolderCard`.
  final String colorKey;

  /// Nombre de cartes (rendu dans le slot `counts`).
  final int cardCount;
}

/// Corpus de démonstration (3 dossiers).
const List<DemoFolder> kDemoFolders = <DemoFolder>[
  DemoFolder(
    id: 'f1',
    title: 'Valeur en douane',
    colorKey: 'primary',
    cardCount: 12,
  ),
  DemoFolder(
    id: 'f2',
    title: 'Origine des marchandises',
    colorKey: 'secondary',
    cardCount: 7,
  ),
  DemoFolder(
    id: 'f3',
    title: 'Régimes suspensifs',
    colorKey: 'tertiary',
    cardCount: 0,
  ),
];

/// Clé de la carte de dossier d'index [index] (les tests **tapent** cette clé,
/// jamais un `find.text` dépendant de la langue).
ValueKey<String> demoFolderCardKey(int index) =>
    ValueKey<String>('demoFolderCard_$index');

/// Clé du **point d'entrée de session** posé dans l'onglet Matériel du détail.
const ValueKey<String> demoSessionEntryKey =
    ValueKey<String>('demoSessionEntry');

/// Clé de l'écran de session (racine du flux `zcrud_session`).
const ValueKey<String> demoSessionScreenKey =
    ValueKey<String>('demoSessionScreen');

/// Config SRS de la démo — **source unique** de l'échelle et des seuils (AD-46).
const ZSrsConfig kDemoSrsConfig = ZSrsConfig(minQuality: 1, maxQuality: 5);

/// Emphase de la rangée SRS — **valeurs de l'app**, jamais du widget (SUF-4,
/// paire 1). Ce sont les proportions du design lex (`0.12`/`0.24`, `1`/`2` px) :
/// elles vivent ICI, côté consommateur.
const ZSrsQualityEmphasis kDemoEmphasis = ZSrsQualityEmphasis(
  fillOpacity: 0.12,
  selectedFillOpacity: 0.24,
  borderWidth: 1,
  selectedBorderWidth: 2,
);

/// Racine de la démo : `ZcrudScope` (thème + labels injectés) + la grille.
class Suf4AssemblyDemoApp extends StatelessWidget {
  /// Construit la démo.
  const Suf4AssemblyDemoApp({this.theme, super.key});

  /// Design-tokens **injectés** — `null` ⇒ repli `Theme.of` (AC8 : aucun look
  /// imposé par la démo).
  final ZcrudTheme? theme;

  /// 🔴 **Le `ZcrudScope` est ANCÊTRE du `MaterialApp`, jamais son enfant** —
  /// défaut MESURÉ par `suf4_assembly_demo_test.dart` (AC8), pas anticipé.
  ///
  /// Mon premier jet posait `MaterialApp(home: ZcrudScope(child: grille))`. Le
  /// `Navigator` est alors **au-dessus** du scope : les écrans **poussés**
  /// (détail, session) sont construits par ce `Navigator` et ne voient donc
  /// **PAS** l'`InheritedWidget`. Résultat mesuré : la grille suivait le thème
  /// injecté, mais tout le reste du parcours retombait silencieusement sur les
  /// tokens par défaut (`gapM` 24 injecté → 8 rendu). Un thème d'app qui
  /// s'arrête au premier écran est le pire des mondes : il *a l'air* branché.
  @override
  Widget build(BuildContext context) => ZcrudScope(
        theme: theme,
        child: const MaterialApp(home: DemoFolderGridScreen()),
      );
}

/// Étape 1 — **grille de dossiers** : `ZAdaptiveGrid.builder` + `ZFolderCard`.
class DemoFolderGridScreen extends StatelessWidget {
  /// Construit la grille.
  const DemoFolderGridScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mes dossiers')),
        body: ZAdaptiveGrid.builder(
          itemCount: kDemoFolders.length,
          minItemWidth: 160,
          itemHeight: 120,
          itemBuilder: (context, index) {
            final folder = kDemoFolders[index];
            return ZFolderCard(
              key: demoFolderCardKey(index),
              title: folder.title,
              colorKey: folder.colorKey,
              colorSlotIndex: index,
              counts: Text('${folder.cardCount} cartes'),
              // Navigation app-side : le widget n'en sait rien (D1).
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => DemoFolderDetailScreen(folder: folder),
                ),
              ),
            );
          },
        ),
      );
}

/// Étape 2 — **page-détail** : `ZStudyFolderDetail`, dont l'onglet Matériel
/// porte le **point d'entrée de session**.
class DemoFolderDetailScreen extends StatelessWidget {
  /// Construit le détail du dossier [folder].
  const DemoFolderDetailScreen({required this.folder, super.key});

  /// Dossier ouvert.
  final DemoFolder folder;

  @override
  Widget build(BuildContext context) => ZStudyFolderDetail(
        title: folder.title,
        colorKey: folder.colorKey,
        materialTabLabel: 'Matériel',
        notebookTabLabel: 'Carnet',
        progressionTabLabel: 'Progression',
        // Le ratio est PRÉ-CALCULÉ côté app (le widget ne calcule rien, ES-4.5).
        progressData: ZProgressRingsData(
          total: folder.cardCount,
          correct: folder.cardCount ~/ 2,
          ratio: folder.cardCount == 0 ? 0 : 0.5,
        ),
        nav: const ZSubfolderNavSpec(
          subfolders: <ZSubfolderRef>[
            ZSubfolderRef(id: 's1', label: 'Bases', colorKey: 'primary'),
            ZSubfolderRef(id: 's2', label: 'Cas pratiques', colorKey: 'secondary'),
          ],
          allSubfoldersLabel: 'Tous les sous-dossiers',
        ),
        notebookBuilder: (_) => const Text('Carnet de notes'),
        materialSectionsBuilder: (selectedSubfolderId) =>
            <ZStudyToolsSectionSpec>[
          ZStudyToolsSectionSpec(
            id: 'session',
            title: 'Réviser',
            itemCount: 1,
            emptyState: const SizedBox.shrink(),
            itemBuilder: (context, _) => ListTile(
              key: demoSessionEntryKey,
              leading: const Icon(Icons.play_arrow_rounded),
              title: const Text('Démarrer une session'),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => DemoSessionScreen(folder: folder),
                ),
              ),
            ),
          ),
        ],
      );
}

/// Les trois états du flux de session de la démo — **enum**, jamais une paire
/// de booléens qui pourraient être vrais tous les deux.
enum DemoSessionStage {
  /// Choix du mode (`ZSessionModeSelector`).
  selecting,

  /// Notation en cours (`ZSessionProgressIndicator` + `ZSrsQualityButtons`).
  reviewing,

  /// Bilan (`ZSessionSummaryView`).
  done,
}

/// Étape 3 — **flux de session** : sélecteur → notation → bilan.
///
/// L'état vit dans une `ValueNotifier` **possédée par cet écran** (créée une
/// fois, disposée une fois) et n'est lue que par des `ValueListenableBuilder` :
/// aucun gestionnaire d'état, aucun `setState` d'écran (AD-2/AD-15). C'est un
/// hôte de démonstration — un consommateur, pas un package produit.
class DemoSessionScreen extends StatefulWidget {
  /// Construit l'écran de session pour [folder].
  const DemoSessionScreen({required this.folder, super.key});

  /// Dossier révisé.
  final DemoFolder folder;

  @override
  State<DemoSessionScreen> createState() => _DemoSessionScreenState();
}

class _DemoSessionScreenState extends State<DemoSessionScreen> {
  final ValueNotifier<DemoSessionStage> _stage =
      ValueNotifier<DemoSessionStage>(DemoSessionStage.selecting);
  final ValueNotifier<int> _graded = ValueNotifier<int>(0);
  final Map<String, int> _byQuality = <String, int>{};

  /// Horloge **injectée** (jamais `DateTime.now()` dans un widget zcrud).
  static final DateTime _at = DateTime.utc(2026, 7, 26, 9);

  late final List<ZFlashcard> _cards = <ZFlashcard>[
    for (var i = 0; i < widget.folder.cardCount; i++)
      ZFlashcard(
        id: '${widget.folder.id}_c$i',
        folderId: widget.folder.id,
        question: 'Question $i',
        answer: 'Réponse $i',
      ),
  ];

  @override
  void dispose() {
    _stage.dispose();
    _graded.dispose();
    super.dispose();
  }

  void _grade(int quality) {
    _byQuality['$quality'] = (_byQuality['$quality'] ?? 0) + 1;
    final next = _graded.value + 1;
    _graded.value = next;
    if (next >= _cards.length) _stage.value = DemoSessionStage.done;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        key: demoSessionScreenKey,
        appBar: AppBar(title: Text(widget.folder.title)),
        body: SafeArea(
          child: ValueListenableBuilder<DemoSessionStage>(
            valueListenable: _stage,
            builder: (context, stage, _) => switch (stage) {
              DemoSessionStage.selecting => ZSessionModeSelector(
                  cards: _cards,
                  srsById: const <String, ZRepetitionInfo>{},
                  at: _at,
                  streak: const ZStudyStreak(current: 3, best: 5),
                  onStart: (kind, queue) =>
                      _stage.value = DemoSessionStage.reviewing,
                ),
              DemoSessionStage.reviewing => _buildReviewing(context),
              DemoSessionStage.done => ZSessionSummaryView(
                  result: ZStudySessionResult(
                    total: _cards.length,
                    correct: _graded.value,
                    byQuality: Map<String, int>.unmodifiable(_byQuality),
                  ),
                  duration: const Duration(minutes: 4),
                  config: kDemoSrsConfig,
                  onFinish: () => Navigator.of(context).pop(),
                  // SUF-4 / paire 2 — bilan à longueur STABLE (parité lex).
                  breakdownCoverage: ZQualityBreakdownCoverage.wholeScale,
                ),
            },
          ),
        ),
      );

  Widget _buildReviewing(BuildContext context) =>
      ValueListenableBuilder<int>(
        valueListenable: _graded,
        builder: (context, graded, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // SUF-4 / paire 4 — barre CONTINUE. L'épaisseur de 6 dp du design
            // est INJECTÉE ici, côté app : le widget ne la connaît pas.
            ZSessionProgressIndicator(
              total: _cards.length,
              currentIndex: graded,
              passThreshold: kDemoSrsConfig.passThreshold,
              style: ZSessionProgressStyle.linear,
              linearThickness: 6,
            ),
            const Spacer(),
            // SUF-4 / paire 1 — emphase injectée (fond teinté + bord).
            ZSrsQualityButtons(
              scale: ZQualityScale.fromConfig(kDemoSrsConfig),
              passThreshold: kDemoSrsConfig.passThreshold,
              emphasis: kDemoEmphasis,
              selectedQuality: 4,
              onQualitySelected: _grade,
            ),
          ],
        ),
      );
}
