/// Démo « Prise en charge navire — contrôle des documents » : le **gabarit de
/// référence** demandé par la CR DODLP `cr-ship-handling-nested-docs-2026-08-09`
/// — *« stepper racine tout-affiché contenant un sous-stepper paginé dynamique
/// dont les sous-étapes dérivent d'une valeur d'un autre champ »*.
///
/// ## Le montage exact, et ce qu'il démontre
///
/// | Demande CR | Ce que la page montre |
/// |---|---|
/// | 1 — sous-stepper **paginé** dans un racine **tout-affiché** | racine `ZStepperConfig.showAllSteps: true` ; étape « Contrôle des documents » portant `nestedSteps` + `nestedConfig` **paginé** |
/// | 2 — sous-étapes **dynamiques** dérivées d'une valeur chargée **async** | chaque sous-étape porte une `ZEditionStep.condition` sur la tranche `shipType`, que l'hôte écrit **après** un aller-retour dépôt déclenché par `shipId` |
/// | 3 — `rowChips` de statut à **libellé + sous-titre par choix** | `ZFieldChoice.subtitle` sur les 4 valeurs de `DocumentStatus` |
/// | 4 — **seams fichier** pour un `file` multi **hors flux form** | `ZcrudScope.filePicker` (acquisition) + `cloudStorage` (transport) + `appFileResolver` (résolution des **ids** déjà persistés) |
/// | 5 — **maps aplaties** puis ré-agrégées | un champ `docStatus<Type>` / `docFiles<Type>` par document, ré-agrégés en deux `Map` à la soumission ([_aggregate]) |
///
/// ## 🔴 Ce que la LISTE d'étapes ne sait PAS faire, et le motif qui y répond
///
/// Aucune capacité du socle ne **dérive** une liste d'étapes d'une valeur —
/// mesuré : `grep -rn "nestedStepsFrom\|stepsSource\|stepsFromKey\|ZStepsSource"
/// packages/zcrud_core/lib` → **RC=1, aucune occurrence**. Le motif déclaratif
/// est donc : **déclarer TOUTES les sous-étapes possibles** (l'ensemble des
/// documents est énumérable) et les **filtrer par `condition`**. C'est ce que
/// fait [kShipDocumentSubSteps], et c'est suffisant pour le cas navires.
///
/// ⚠️ **Limite du motif, à dire à l'hôte** : il exige un ensemble **fermé et
/// connu à la compilation**. Une liste de documents servie par le backend
/// (ajout d'un type sans redéploiement) n'est PAS exprimable ainsi ; l'hôte
/// devrait alors reconstruire sa `List<ZEditionStep>` — ce que la doc de
/// `ZEditionStep.condition` désigne justement comme le recours que la condition
/// existe pour éviter.
///
/// ## 🔴 Pourquoi la sous-étape « En attente du type » n'est PAS décorative
///
/// Elle porte l'état de chargement honnête (ni sous-étapes fausses, ni blocage),
/// **et** elle garantit que l'ensemble des sous-étapes effectives n'est **jamais
/// vide**. Ce second rôle est obligatoire : un `ZStepperEdition` **imbriqué**
/// dont toutes les sous-étapes sont filtrées lève (mesuré le 2026-08-09,
/// v0.71.0) :
///
/// ```
/// RangeError (length): Invalid value: Valid value range is empty: 0
///   _ZStepperEditionState._windowFor (z_stepper_edition.dart:668)
///   _ZStepperEditionState._contribution (z_stepper_edition.dart:712)
///   _ZStepperEditionState._publishWindow (z_stepper_edition.dart:799)
/// ```
///
/// au **montage** comme **en vol** (via `_onEffectiveStepsChanged`). Un racine
/// (paginé ou déplié) intégralement filtré, lui, monte proprement — seul le
/// chemin `_contribution()` est fautif. **Ce défaut appartient à
/// `zcrud_core` et n'est PAS corrigé ici** (périmètre `example/`) : la page se
/// contente de ne jamais l'atteindre, et le dit. Les conditions de
/// [kShipDocumentSubSteps] sont construites pour que l'ensemble soit **toujours
/// non vide** : `shipType` vide ⇒ l'étape d'attente ; `shipType` non vide ⇒ au
/// moins les deux documents exigés de tout navire.
///
/// ## Sort d'une valeur dont la sous-étape disparaît
///
/// **Elle est CONSERVÉE** (mesuré) — la tranche du contrôleur n'est jamais
/// purgée par la disparition d'une étape. C'est la même doctrine que les choix
/// orphelins de la v0.65.0 : on ne détruit pas silencieusement une saisie de
/// l'utilisateur. La page l'affiche : le bandeau de tête compte les statuts
/// saisis pour des documents **actuellement hors périmètre**.
///
/// 🔴 **Tout est DÉCLARATIF** : `ZFieldSpec` et `ZEditionStep` `const`, aucun
/// `fieldBuilder`, aucun remontage forcé, aucune reconstruction de la liste
/// d'étapes. Les seuls apports impératifs sont ceux que l'architecture réserve à
/// l'hôte : un `ZFormController` stable, et des seams injectés au `ZcrudScope`.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

// ─────────────────────────────── Domaine (démo) ──────────────────────────────

/// Types de navire de la démo (miroir réduit du `ShipType` DODLP).
enum DemoShipType {
  /// Vraquier.
  bulk,

  /// Pétrolier.
  tanker,

  /// Porte-conteneurs.
  container,
}

/// Documents contrôlables (miroir réduit de `ShipDocumentType` DODLP).
///
/// L'ensemble est **fermé** : c'est ce qui rend le motif « tout déclarer, tout
/// filtrer » applicable.
enum DemoShipDocument {
  /// Liste d'équipage — exigée de tout navire.
  crewList,

  /// Manifeste de cargaison — exigé de tout navire.
  cargoManifest,

  /// Registre des hydrocarbures — pétroliers seulement.
  oilRecordBook,

  /// Certificat de densité de la cargaison — vraquiers seulement.
  bulkDensity,

  /// Plan d'arrimage des conteneurs — porte-conteneurs seulement.
  stowagePlan,
}

/// Documents exigés pour [type] — l'équivalent de
/// `ShipDocumentType.shipHandlingDocuments(shipType)` côté DODLP. Sert de
/// **source de vérité du test** : les conditions déclarées dans
/// [kShipDocumentSubSteps] doivent produire exactement cet ensemble.
List<DemoShipDocument> demoRequiredDocuments(DemoShipType type) =>
    <DemoShipDocument>[
      DemoShipDocument.crewList,
      DemoShipDocument.cargoManifest,
      switch (type) {
        DemoShipType.tanker => DemoShipDocument.oilRecordBook,
        DemoShipType.bulk => DemoShipDocument.bulkDensity,
        DemoShipType.container => DemoShipDocument.stowagePlan,
      },
    ];

/// Nom du champ de **statut** aplati du document [d] (patron DODLP
/// `shipDocumentsStatus<TypeName>`).
String demoStatusFieldOf(DemoShipDocument d) =>
    'docStatus${d.name[0].toUpperCase()}${d.name.substring(1)}';

/// Nom du champ de **pièces jointes** aplati du document [d] (patron DODLP
/// `shipDocuments<TypeName>`).
String demoFilesFieldOf(DemoShipDocument d) =>
    'docFiles${d.name[0].toUpperCase()}${d.name.substring(1)}';

// ─────────────────────────── Schéma de champs (const) ────────────────────────

/// Statuts de contrôle, **avec sous-titre par choix** — la demande 3 de la CR
/// (`DocumentStatus.description`). Le sous-titre est porté par
/// `ZFieldChoice.subtitle` et rendu par la famille `rowChips` sur une seconde
/// ligne (plus un `Tooltip` a11y).
const _statusChoices = <ZFieldChoice>[
  ZFieldChoice(
    value: 'conforme',
    label: 'Conforme',
    subtitle: 'Présent, lisible et en cours de validité.',
  ),
  ZFieldChoice(
    value: 'nonConforme',
    label: 'Non conforme',
    subtitle: 'Présent mais illisible, périmé ou incomplet.',
  ),
  ZFieldChoice(
    value: 'manquant',
    label: 'Manquant',
    subtitle: 'Exigé et non fourni à ce jour.',
  ),
  ZFieldChoice(
    value: 'nonDemande',
    label: 'Non demandé',
    subtitle: 'Non exigé pour ce navire.',
  ),
];

/// Config des pièces jointes d'un document : multi, PDF/Office, plafonnée.
const _docFilesConfig = FileFieldConfig(
  maxFiles: 4,
  allowedDocumentTypes: <String, List<String>>{
    'documents': <String>['pdf', 'doc', 'docx'],
    'images': <String>['png', 'jpg'],
  },
);

/// Navire — `select` alimenté par une liste (patron POC DODLP : les relations
/// sont servies par des selects sur les listes surveillées, pas par un registre
/// de relations). C'est le champ **amont** dont tout dérive.
const _shipId = ZFieldSpec(
  name: 'shipId',
  type: EditionFieldType.select,
  label: 'Navire',
  validators: <ZValidatorSpec>[
    ZValidatorSpec.required(errorText: 'Sélectionnez un navire.'),
  ],
  choices: <ZFieldChoice>[
    ZFieldChoice(value: 'ship-1', label: 'MV Aného (vraquier)'),
    ZFieldChoice(value: 'ship-2', label: 'MT Kara (pétrolier)'),
    ZFieldChoice(value: 'ship-3', label: 'MSC Lomé (porte-conteneurs)'),
  ],
);

/// Type de navire — **jamais saisi** : écrit par l'hôte au retour du dépôt.
/// `readOnly` le dit à l'utilisateur, et c'est la tranche que les conditions de
/// sous-étape observent.
const _shipType = ZFieldSpec(
  name: 'shipType',
  type: EditionFieldType.select,
  label: 'Type de navire (chargé depuis le dépôt)',
  readOnly: true,
  choices: <ZFieldChoice>[
    ZFieldChoice(value: 'bulk', label: 'Vraquier'),
    ZFieldChoice(value: 'tanker', label: 'Pétrolier'),
    ZFieldChoice(value: 'container', label: 'Porte-conteneurs'),
  ],
);

/// Photos du navire — `file` multi **image**, hors sous-stepper.
const _shipImages = ZFieldSpec(
  name: 'shipImages',
  type: EditionFieldType.image,
  label: 'Photos du navire',
  multiple: true,
  config: FileFieldConfig(
    maxFiles: 6,
    acceptedExtensions: <String>['png', 'jpg'],
    imageFallback: true,
  ),
);

const _remarks = ZFieldSpec(
  name: 'remarks',
  type: EditionFieldType.multiline,
  label: 'Remarques du contrôle',
);

/// Fabrique le couple statut/pièces d'un document (aplatissage de la map).
List<ZFieldSpec> _docFields(DemoShipDocument d, String label) => <ZFieldSpec>[
      ZFieldSpec(
        name: demoStatusFieldOf(d),
        type: EditionFieldType.rowChips,
        label: 'Statut — $label',
        choices: _statusChoices,
      ),
      ZFieldSpec(
        name: demoFilesFieldOf(d),
        type: EditionFieldType.file,
        label: 'Pièces — $label',
        multiple: true,
        config: _docFilesConfig,
      ),
    ];

/// Libellé métier de chaque document.
const Map<DemoShipDocument, String> kShipDocumentLabels =
    <DemoShipDocument, String>{
  DemoShipDocument.crewList: 'Liste d’équipage',
  DemoShipDocument.cargoManifest: 'Manifeste de cargaison',
  DemoShipDocument.oilRecordBook: 'Registre des hydrocarbures',
  DemoShipDocument.bulkDensity: 'Certificat de densité',
  DemoShipDocument.stowagePlan: 'Plan d’arrimage',
};

/// Catalogue **complet** des champs (ordre canonique de rendu). Tous les
/// documents y figurent, y compris ceux qu'aucun navire courant n'exige : c'est
/// la fenêtre de visibilité, pilotée par le stepper, qui décide de ce qui est
/// monté.
final List<ZFieldSpec> kShipDocumentsFields = <ZFieldSpec>[
  _shipId,
  _shipType,
  for (final d in DemoShipDocument.values)
    ..._docFields(d, kShipDocumentLabels[d]!),
  _shipImages,
  _remarks,
];

// ──────────────────────────── Étapes (const, filtrées) ───────────────────────

/// Condition « le type est chargé » — commune aux documents exigés de tout
/// navire. `isNotEmpty` et non `notNull` : la valeur transite par `null` pendant
/// le chargement, et une chaîne vide doit compter comme « pas encore chargé ».
const _typeLoaded = ZCondition.isNotEmpty('shipType');

/// Sous-étapes du sous-stepper **paginé**, déclarées **toutes**, filtrées par
/// condition. L'ordre est celui du contrôle.
///
/// 🔴 **Invariant tenu par construction : l'ensemble effectif n'est jamais
/// vide.** `shipType` vide ⇒ seule l'étape d'attente ; `shipType` non vide ⇒ au
/// moins `crewList` + `cargoManifest`. Cf. l'avertissement en tête de fichier :
/// un sous-stepper vide lève dans le socle v0.71.0.
final List<ZEditionStep> kShipDocumentSubSteps = <ZEditionStep>[
  const ZEditionStep(
    title: 'En attente du type de navire',
    subtitle: 'Choisissez un navire à l’étape 1 — les documents exigés '
        'seront chargés depuis le dépôt.',
    icon: Icons.hourglass_empty,
    fields: <String>[],
    optional: true,
    condition: ZCondition.isEmpty('shipType'),
  ),
  _docStep(DemoShipDocument.crewList, _typeLoaded, Icons.groups_outlined),
  _docStep(
      DemoShipDocument.cargoManifest, _typeLoaded, Icons.inventory_2_outlined),
  _docStep(DemoShipDocument.oilRecordBook,
      const ZCondition.equals('shipType', 'tanker'), Icons.oil_barrel_outlined),
  _docStep(DemoShipDocument.bulkDensity,
      const ZCondition.equals('shipType', 'bulk'), Icons.scale_outlined),
  _docStep(DemoShipDocument.stowagePlan,
      const ZCondition.equals('shipType', 'container'), Icons.grid_on_outlined),
];

ZEditionStep _docStep(
        DemoShipDocument d, ZCondition condition, IconData icon) =>
    ZEditionStep(
      title: kShipDocumentLabels[d]!,
      subtitle: 'Statut du contrôle et pièces justificatives',
      icon: icon,
      fields: <String>[demoStatusFieldOf(d), demoFilesFieldOf(d)],
      condition: condition,
    );

/// Étapes **racine**, rendues toutes dépliées (`showAllSteps: true`).
final List<ZEditionStep> kShipDocumentsSteps = <ZEditionStep>[
  const ZEditionStep(
    title: 'Identification du navire',
    subtitle: 'Le type est chargé en asynchrone depuis le dépôt',
    icon: Icons.directions_boat_outlined,
    fields: <String>['shipId', 'shipType'],
  ),
  ZEditionStep(
    title: 'Contrôle des documents',
    subtitle: 'Sous-stepper PAGINÉ, sous-étapes dérivées du type de navire',
    icon: Icons.fact_check_outlined,
    // Aucun champ direct : l'étape n'existe que pour porter le sous-stepper.
    fields: const <String>[],
    nestedSteps: kShipDocumentSubSteps,
    // 🔴 Le montage exact de la CR : racine DÉPLIÉ, enfant PAGINÉ.
    nestedConfig: const ZStepperConfig(showSubtitles: true),
  ),
  const ZEditionStep(
    title: 'Photos et remarques',
    subtitle: 'Champ image multi + texte libre',
    icon: Icons.photo_library_outlined,
    fields: <String>['shipImages', 'remarks'],
  ),
];

/// Valeurs initiales. `docFilesCrewList` démarre avec une **référence opaque**
/// (`String`), pas un `AppFile` : c'est exactement la donnée DODLP existante
/// (`shipDocumentsIds`), et c'est ce que le port `ZAppFileResolver` rend
/// visible. Sans résolveur injecté, cette valeur serait **silencieusement
/// ignorée** — le défaut que le port a corrigé.
Map<String, Object?> kShipDocumentsInitialValues() => <String, Object?>{
      'shipId': null,
      'shipType': null,
      'docFilesCrewList': <Object>['ref-crew-2024-001'],
    };

// ───────────────────────────── Seams injectés (démo) ─────────────────────────

/// Dépôt de navires **asynchrone** — le miroir de
/// `dodlp.shipRepository.getOne(id)`. Le délai est réel et observable : c'est
/// tout l'intérêt du gabarit (l'utilisateur choisit, la valeur arrive plus tard).
class DemoShipRepository {
  /// Construit le dépôt avec sa [latency] (réglable pour les tests).
  const DemoShipRepository({this.latency = const Duration(milliseconds: 700)});

  /// Délai simulé de l'aller-retour dépôt.
  final Duration latency;

  static const Map<String, DemoShipType> _types = <String, DemoShipType>{
    'ship-1': DemoShipType.bulk,
    'ship-2': DemoShipType.tanker,
    'ship-3': DemoShipType.container,
  };

  /// Charge le type de navire de [shipId] (`null` si inconnu).
  Future<DemoShipType?> shipTypeOf(String shipId) async {
    await Future<void>.delayed(latency);
    return _types[shipId];
  }
}

/// Résolveur de **références opaques** de fichiers : convertit les ids persistés
/// en `AppFile` affichables. Impl de démo — la vraie vit dans `zcrud_firestore`
/// ou l'app (AD-1 : jamais dans le cœur).
class DemoShipFileResolver extends ZAppFileResolver {
  /// Construit le résolveur de démo.
  const DemoShipFileResolver();

  @override
  Future<List<AppFile>> resolve(List<String> refs) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return <AppFile>[
      for (final r in refs)
        AppFile(
          id: r,
          name: '$r.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 24576,
          remoteUrl: 'https://exemple.invalid/$r.pdf',
          uploadState: ZAppFileUploadState.uploaded,
        ),
    ];
  }
}

/// Stockage cloud de démo : reflète `pending → uploading → uploaded` dans la
/// tranche via le seam `ZcrudScope.cloudStorage`. Aucune E/S réelle.
class DemoCloudStorage implements CloudStorageRepository {
  /// Construit le stockage de démo.
  const DemoCloudStorage();

  @override
  Future<ZResult<AppFile>> upload(AppFile file) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return Right<ZFailure, AppFile>(
      file.copyWith(
        remoteUrl: 'https://exemple.invalid/${file.name}',
        uploadState: ZAppFileUploadState.uploaded,
      ),
    );
  }

  @override
  Future<ZResult<Unit>> delete(AppFile file) async =>
      const Right<ZFailure, Unit>(unit);

  @override
  Future<ZResult<String>> downloadUrl(AppFile file) async =>
      Right<ZFailure, String>(file.remoteUrl ?? '');

  @override
  Stream<double> watchProgress(AppFile file) =>
      Stream<double>.fromIterable(const <double>[0, 1]);
}

// ─────────────────────────────────── Écran ───────────────────────────────────

/// Écran de la démo (cf. doc de bibliothèque en tête de fichier).
class ShipDocumentsDemoScreen extends StatefulWidget {
  /// Construit la démo ; [repository] est surchargeable par les tests pour
  /// rendre l'attente observable sans horloge réelle.
  const ShipDocumentsDemoScreen({
    this.repository = const DemoShipRepository(),
    super.key,
  });

  /// Dépôt fournissant le type de navire (asynchrone).
  final DemoShipRepository repository;

  @override
  State<ShipDocumentsDemoScreen> createState() =>
      _ShipDocumentsDemoScreenState();
}

class _ShipDocumentsDemoScreenState extends State<ShipDocumentsDemoScreen> {
  late final ZFormController _controller;

  /// Jeton de course : seule la réponse du DERNIER `shipId` demandé est écrite.
  /// Sans lui, deux sélections rapprochées pourraient s'inverser à l'arrivée —
  /// et le formulaire afficherait les documents du mauvais navire.
  int _requestToken = 0;

  /// Chargement en cours (affiché honnêtement ; n'empêche RIEN de saisir).
  bool _loadingType = false;

  @override
  void initState() {
    super.initState();
    _controller =
        ZFormController(initialValues: kShipDocumentsInitialValues());
    // 🔴 L'unique orchestration impérative de la page, et elle est chez l'HÔTE :
    // le socle n'a pas — et ne prétend pas avoir — de canal « dérivation
    // asynchrone ». On écoute la tranche amont et on écrit la tranche dérivée.
    _controller.fieldListenable('shipId').addListener(_onShipChanged);
  }

  @override
  void dispose() {
    _controller.fieldListenable('shipId').removeListener(_onShipChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onShipChanged() {
    final Object? id = _controller.valueOf('shipId');
    final int token = ++_requestToken;
    // Le type précédent n'est plus vrai : on l'efface TOUT DE SUITE. C'est ce
    // qui rend l'attente honnête — pendant le chargement, aucune sous-étape de
    // document n'est montée, et l'étape « En attente » prend leur place.
    _controller.setValue('shipType', null);
    if (id is! String || id.isEmpty) {
      if (mounted) setState(() => _loadingType = false);
      return;
    }
    if (mounted) setState(() => _loadingType = true);
    // ignore: discarded_futures
    _load(id, token);
  }

  Future<void> _load(String id, int token) async {
    final DemoShipType? type = await widget.repository.shipTypeOf(id);
    if (!mounted || token != _requestToken) return;
    setState(() => _loadingType = false);
    _controller.setValue('shipType', type?.name);
  }

  /// Ré-agrégation des champs aplatis vers les deux `Map` du modèle (demande 5
  /// de la CR). C'est l'exact pendant de `formDataTransformer` côté DODLP.
  ({
    Map<DemoShipDocument, String> statuses,
    Map<DemoShipDocument, List<String>> files,
  }) _aggregate() {
    final statuses = <DemoShipDocument, String>{};
    final files = <DemoShipDocument, List<String>>{};
    for (final d in DemoShipDocument.values) {
      final Object? s = _controller.valueOf(demoStatusFieldOf(d));
      if (s is String && s.isNotEmpty) statuses[d] = s;
      final Object? f = _controller.valueOf(demoFilesFieldOf(d));
      if (f is List && f.isNotEmpty) {
        files[d] = <String>[
          for (final e in f)
            if (e is AppFile) e.id ?? e.name else if (e is String) e,
        ];
      }
    }
    return (statuses: statuses, files: files);
  }

  @override
  Widget build(BuildContext context) {
    final root = ZcrudScope.maybeOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Navire — contrôle des documents')),
      body: ZcrudScope(
        theme: root?.theme,
        labels: root?.labels,
        // Les 3 seams FICHIER, ensemble : acquisition, transport, résolution.
        // C'est la réponse à la demande 4 de la CR — un champ `file` multi dont
        // la donnée persistée est une liste d'IDS reste pleinement rendu.
        filePicker: root?.filePicker,
        cloudStorage: const DemoCloudStorage(),
        appFileResolver: const DemoShipFileResolver(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Banner(controller: _controller, loading: _loadingType),
            Expanded(
              child: ZStepperEdition(
                controller: _controller,
                fields: kShipDocumentsFields,
                steps: kShipDocumentsSteps,
                // Racine TOUT AFFICHÉ (mode déplié v0.66.0).
                config: const ZStepperConfig(
                  showAllSteps: true,
                  showSubtitles: true,
                ),
                padding: const EdgeInsetsDirectional.all(12),
                previousLabel: 'Précédent',
                nextLabel: 'Suivant',
                finishLabel: 'Clôturer le contrôle',
                onComplete: () {
                  final agg = _aggregate();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${agg.statuses.length} statut(s) et '
                        '${agg.files.length} lot(s) de pièces ré-agrégés.',
                        textAlign: TextAlign.start,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bandeau de tête : mode d'emploi, état de chargement, et — surtout — le
/// **compte des saisies conservées hors périmètre**, qui rend visible le sort
/// d'une valeur dont la sous-étape a disparu.
class _Banner extends StatelessWidget {
  const _Banner({required this.controller, required this.loading});

  final ZFormController controller;
  final bool loading;

  /// Statuts saisis pour des documents que le navire courant n'exige PAS.
  int _orphanCount() {
    final Object? t = controller.valueOf('shipType');
    final DemoShipType? type = switch (t) {
      'bulk' => DemoShipType.bulk,
      'tanker' => DemoShipType.tanker,
      'container' => DemoShipType.container,
      _ => null,
    };
    final required = type == null
        ? const <DemoShipDocument>[]
        : demoRequiredDocuments(type);
    var n = 0;
    for (final d in DemoShipDocument.values) {
      if (required.contains(d)) continue;
      final Object? v = controller.valueOf(demoStatusFieldOf(d));
      if (v is String && v.isNotEmpty) n++;
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Le bandeau observe la tranche `shipType` (canal ciblé, AD-2/SM-1) — il ne
    // reconstruit pas le formulaire.
    return ValueListenableBuilder<Object?>(
      valueListenable: controller.fieldListenable('shipType'),
      builder: (context, _, _) {
        final orphans = _orphanCount();
        return Container(
          width: double.infinity,
          color: theme.colorScheme.surfaceContainerHighest,
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Étape 1 : choisissez un navire. Son type arrive du dépôt '
                'APRÈS coup — pendant l’attente, l’étape 2 affiche '
                '« En attente du type de navire » et rien d’autre. '
                'Une fois le type connu, le sous-stepper PAGINÉ de l’étape '
                '2 monte exactement les documents exigés.',
                textAlign: TextAlign.start,
                style: theme.textTheme.bodySmall,
              ),
              if (loading)
                Semantics(
                  liveRegion: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text('Chargement du type de navire…',
                          textAlign: TextAlign.start,
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              if (orphans > 0)
                Text(
                  '$orphans statut(s) saisi(s) pour un document hors '
                  'périmètre : CONSERVÉ(S), jamais purgé(s).',
                  key: const ValueKey<String>('ship-orphan-banner'),
                  textAlign: TextAlign.start,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
            ],
          ),
        );
      },
    );
  }
}
