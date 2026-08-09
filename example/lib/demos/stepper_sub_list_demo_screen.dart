import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Démo « Stepper & sous-listes » — la **réponse visible** aux trois demandes
/// DODLP du CR stepper (gaps 2/3/4), toutes trois revenues « déjà couvert » :
///
///  1. **Gap 2** — `EditionFieldType.rowChips` *est* le « select en mode
///     chips » : `corps` (mono statique), `grade` (mono à choix **dynamiques**
///     via `ZChoicesSource`) et `specialites` (**multi**, `multiple: true`) le
///     montrent côte à côte, sans aucun mode d'affichage ajouté à
///     `ZSelectConfig` ;
///  2. **Gap 3** — un `subItems` **compact** vit dans une étape de
///     [ZStepperEdition] ; l'interrupteur d'ACL de la barre d'application
///     montre les actions de ligne apparaître/disparaître en direct
///     (`ZSubListConfig.aclCollectionId` + `ZcrudScope.acl`) ;
///  3. **Gap 4** — un champ `custom` servi par le registre écrit une
///     `Map<String, List<String>>` **telle quelle** dans sa tranche, et son
///     `required` **mord** : une map vide bloque « Suivant » **avec** un
///     message visible (le refus muet corrigé en v0.67.0).
///
/// Plus le mode **déplié** livré en v0.66.0 (`ZStepperConfig.showAllSteps` :
/// rail numéroté, badges, titre + sous-titre par étape), basculable depuis la
/// barre d'application.
///
/// 🔴 **Tout est DÉCLARATIF** : les champs sont des `ZFieldSpec` `const`, les
/// étapes des `ZEditionStep` `const`. Les seuls apports impératifs de l'hôte
/// sont ceux que l'architecture lui réserve — un `ZFormController` stable, et
/// deux seams injectés au `ZcrudScope` (registre de widgets, registre de
/// sources de choix) plus le port `ZAcl`. Aucun `fieldBuilder`, aucun
/// contournement du dispatcher.
///
/// L'éditeur de permissions rendu ici est **l'exemple minimal du moyen**
/// (trois interrupteurs), pas l'écran métier de DODLP : le socle porte le
/// canal de valeur structurée, pas leur formulaire.
class StepperSubListDemoScreen extends StatefulWidget {
  /// Construit la démo.
  const StepperSubListDemoScreen({super.key});

  @override
  State<StepperSubListDemoScreen> createState() =>
      _StepperSubListDemoScreenState();
}

// ─────────────────────────────── Schéma (const) ──────────────────────────────

/// Corps d'appartenance — `rowChips` **mono**, choix **statiques** : c'est
/// exactement la forme legacy `s2choiceType: S2ChoiceType.chips`.
const _corps = ZFieldSpec(
  name: 'corps',
  type: EditionFieldType.rowChips,
  label: 'Corps',
  choices: <ZFieldChoice>[
    ZFieldChoice(value: 'terre', label: 'Armée de terre'),
    ZFieldChoice(value: 'gendarmerie', label: 'Gendarmerie'),
  ],
);

/// Grade — `rowChips` **mono** à choix **DYNAMIQUES** : la source est résolue
/// par clé (`choicesSourceKey`) et recalculée sur la tranche `corps`
/// (`filterKeys`). Aucune closure dans le schéma (AD-3/AD-14).
const _grade = ZFieldSpec(
  name: 'grade',
  type: EditionFieldType.rowChips,
  label: 'Grade',
  validators: <ZValidatorSpec>[
    ZValidatorSpec.required(errorText: 'Le grade est requis.'),
  ],
  config: ZSelectConfig(
    choicesSourceKey: 'gradesParCorps',
    filterKeys: <String>['corps'],
  ),
);

/// Spécialités — même famille `rowChips`, `multiple: true` : toutes les options
/// restent visibles et chacune bascule (la tranche porte une `List`).
const _specialites = ZFieldSpec(
  name: 'specialites',
  type: EditionFieldType.rowChips,
  label: 'Spécialités',
  multiple: true,
  choices: <ZFieldChoice>[
    ZFieldChoice(value: 'transmissions', label: 'Transmissions'),
    ZFieldChoice(value: 'logistique', label: 'Logistique'),
    ZFieldChoice(value: 'secourisme', label: 'Secourisme'),
  ],
);

const _nom = ZFieldSpec(
  name: 'nom',
  type: EditionFieldType.text,
  label: 'Nom',
);

/// Autorisations — champ `custom` servi par le registre, dont la valeur de
/// tranche est une **map**. `required` mord sur `{}` (règle unique du dépôt).
const _autorisations = ZFieldSpec(
  name: 'autorisations',
  type: EditionFieldType.custom,
  label: 'Autorisations',
  validators: <ZValidatorSpec>[
    ZValidatorSpec.required(
      errorText: 'Autorisez au moins un module pour continuer.',
    ),
  ],
);

/// Mobilités — sous-liste CRUD **compacte** dans une étape, ACL de ligne
/// activée par son discriminant de collection.
const _mobilites = ZFieldSpec(
  name: 'mobilites',
  type: EditionFieldType.subItems,
  label: 'Mobilités',
  validators: <ZValidatorSpec>[
    ZValidatorSpec.required(errorText: 'Saisissez au moins une mobilité.'),
  ],
  config: ZSubListConfig(
    displayMode: ZSubListDisplayMode.compact,
    summaryFields: <String>['poste', 'annee'],
    aclCollectionId: 'mobilites',
    itemFields: <ZFieldSpec>[
      ZFieldSpec(name: 'poste', type: EditionFieldType.text, label: 'Poste'),
      ZFieldSpec(name: 'annee', type: EditionFieldType.text, label: 'Année'),
    ],
  ),
);

/// Catalogue de champs de la démo (ordre canonique de rendu).
const List<ZFieldSpec> kStepperSubListFields = <ZFieldSpec>[
  _nom,
  _corps,
  _grade,
  _specialites,
  _autorisations,
  _mobilites,
];

/// Partition en 3 étapes. « Autorisations » précède « Historique » pour que le
/// requis de la map soit démontré sur **« Suivant »** (le gate d'étape), et non
/// seulement sur le bouton final.
const List<ZEditionStep> kStepperSubListSteps = <ZEditionStep>[
  ZEditionStep(
    title: 'Identité',
    subtitle: 'Nom, corps et grade — le grade suit le corps choisi',
    icon: Icons.badge_outlined,
    fields: <String>['nom', 'corps', 'grade', 'specialites'],
  ),
  ZEditionStep(
    title: 'Autorisations',
    subtitle: 'Champ custom écrivant une map — requis sur map vide',
    icon: Icons.lock_outline,
    fields: <String>['autorisations'],
  ),
  ZEditionStep(
    title: 'Historique',
    subtitle: 'Sous-liste compacte + ACL de ligne basculable',
    icon: Icons.history,
    fields: <String>['mobilites'],
  ),
];

/// Valeurs initiales : l'étape 1 est franchissable d'emblée, les étapes 2 et 3
/// démarrent **vides** — c'est là que le requis doit se voir.
Map<String, Object?> kStepperSubListInitialValues() => <String, Object?>{
      'nom': 'KOFFI Ama',
      'corps': 'terre',
      'grade': 'sergent',
      'specialites': <Object?>[],
      'autorisations': <String, Object?>{},
      'mobilites': <Map<String, dynamic>>[],
    };

// ───────────────────────────── Seams injectés ────────────────────────────────

/// Source de choix **calculée** : les grades dépendent du corps. Pur-données,
/// injectée par `ZcrudScope.choicesSourceRegistry` (jamais un singleton).
class _GradesParCorps extends ZChoicesSource {
  const _GradesParCorps();

  @override
  List<ZFieldChoice> options(Map<String, Object?> filterContext) {
    if (filterContext['corps'] == 'gendarmerie') {
      return const <ZFieldChoice>[
        ZFieldChoice(value: 'brigadier', label: 'Brigadier'),
        ZFieldChoice(value: 'marechalDesLogis', label: 'Maréchal des logis'),
        ZFieldChoice(value: 'adjudant', label: 'Adjudant'),
      ];
    }
    return const <ZFieldChoice>[
      ZFieldChoice(value: 'caporal', label: 'Caporal'),
      ZFieldChoice(value: 'sergent', label: 'Sergent'),
      ZFieldChoice(value: 'adjudantChef', label: 'Adjudant-chef'),
    ];
  }
}

/// ACL de démonstration : **consultation seule**. Injectée au `ZcrudScope`, elle
/// n'agit sur les lignes de sous-liste que parce que `ZSubListConfig` porte un
/// `aclCollectionId` (opt-in délibéré du socle : un hôte passif ne bouge pas).
class _ConsultationSeuleAcl implements ZAcl {
  const _ConsultationSeuleAcl();

  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) =>
      !action.mutatesData;
}

/// Registre de widgets **local à la page** : il sert le `kind` `custom`. Il
/// n'est PAS ajouté au registre applicatif (`buildDemoWidgetRegistry`) — un
/// éditeur de permissions est propre à ce formulaire, pas à l'app.
ZWidgetRegistry buildStepperSubListRegistry() {
  return ZWidgetRegistry()
    ..register(
      'custom',
      (context, ctx) => _PermissionsEditor(ctx: ctx),
    );
}

/// Registre de sources de choix local à la page.
ZChoicesSourceRegistry buildStepperSubListChoicesRegistry() {
  return ZChoicesSourceRegistry()
    ..register('gradesParCorps', const _GradesParCorps());
}

// ────────────────────────── Éditeur composite minimal ────────────────────────

/// Modules autorisables — l'exemple minimal, volontairement à trois entrées.
const _modules = <String, String>{
  'agents': 'Agents',
  'missions': 'Missions',
  'rapports': 'Rapports',
};

/// Éditeur de valeur **structurée** (Gap 4), réduit à ce qu'il faut pour
/// démontrer le contrat : chaque bascule écrit une **NOUVELLE** map
/// `{module: ['read','write']}` dans la tranche via `ctx.onChanged`. Jamais de
/// mutation en place — une map mutée ne notifierait rien (AD-2).
class _PermissionsEditor extends StatelessWidget {
  const _PermissionsEditor({required this.ctx});

  final ZFieldWidgetContext ctx;

  Map<String, Object?> get _current {
    final v = ctx.value;
    return v is Map ? Map<String, Object?>.from(v) : <String, Object?>{};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = _current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          ctx.field.label ?? ctx.field.name,
          textAlign: TextAlign.start,
          style: theme.textTheme.titleSmall,
        ),
        Text(
          '${current.length} module(s) autorisé(s)',
          textAlign: TextAlign.start,
          style: theme.textTheme.bodySmall,
        ),
        for (final entry in _modules.entries)
          SwitchListTile(
            // Cible ≥ 48 dp : `SwitchListTile` Material respecte le minimum.
            key: ValueKey<String>('perm-${entry.key}'),
            title: Text(entry.value, textAlign: TextAlign.start),
            value: current.containsKey(entry.key),
            onChanged: ctx.field.readOnly
                ? null
                : (on) {
                    // COPIE : la tranche ne voit un changement que si la
                    // référence change.
                    final next = Map<String, Object?>.from(current);
                    if (on) {
                      next[entry.key] = const <String>['read', 'write'];
                    } else {
                      next.remove(entry.key);
                    }
                    ctx.onChanged(next);
                  },
          ),
      ],
    );
  }
}

// ─────────────────────────────────── Écran ───────────────────────────────────

class _StepperSubListDemoScreenState extends State<StepperSubListDemoScreen> {
  late final ZFormController _controller;
  late final ZWidgetRegistry _registry;
  late final ZChoicesSourceRegistry _choices;

  /// Mode déplié (`showAllSteps`) vs paginé — bascule de la barre d'application.
  bool _expanded = false;

  /// ACL restrictive active — bascule de la barre d'application.
  bool _readOnlyAcl = false;

  @override
  void initState() {
    super.initState();
    _controller =
        ZFormController(initialValues: kStepperSubListInitialValues());
    _registry = buildStepperSubListRegistry();
    _choices = buildStepperSubListChoicesRegistry();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final root = ZcrudScope.maybeOf(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stepper & sous-listes'),
        actions: <Widget>[
          IconButton(
            tooltip: _expanded ? 'Mode déplié' : 'Mode paginé',
            icon: Icon(_expanded ? Icons.unfold_less : Icons.unfold_more),
            onPressed: () => setState(() => _expanded = !_expanded),
          ),
          IconButton(
            tooltip: _readOnlyAcl
                ? 'ACL : consultation seule'
                : 'ACL : tout permis',
            icon: Icon(_readOnlyAcl ? Icons.lock : Icons.lock_open),
            onPressed: () => setState(() => _readOnlyAcl = !_readOnlyAcl),
          ),
        ],
      ),
      // Le scope de la page ré-injecte les seams de la racine (thème / l10n /
      // sélecteur de fichiers) SOUS ses propres seams : un scope imbriqué
      // masque son parent, il ne s'y ajoute pas.
      body: ZcrudScope(
        theme: root?.theme,
        labels: root?.labels,
        filePicker: root?.filePicker,
        widgetRegistry: _registry,
        choicesSourceRegistry: _choices,
        acl: _readOnlyAcl
            ? const _ConsultationSeuleAcl()
            : const ZAllowAllAcl(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const _Legend(),
            Expanded(
              // 🟢 Le contournement qui vivait ici a été RETIRÉ (v0.68.0).
              //
              // Cette page a été écrite le 2026-08-09 et a découvert, en le
              // faisant, que `ZStepperEdition.didUpdateWidget` ne réagissait
              // pas à un changement de `config` : basculer `showAllSteps` sur
              // un stepper déjà monté laissait la fenêtre de visibilité du
              // mode paginé, donc les étapes suivantes s'affichaient avec leur
              // en-tête et un contenu VIDE — sans exception, sans rouge. La
              // vitrine compensait par un `KeyedSubtree` à clé de mode, qui
              // forçait un remontage.
              //
              // Le socle réagit désormais aux changements STRUCTURELS de
              // `config` (et à eux seuls : un changement visuel ne reconstruit
              // pas les champs). La bascule se passe donc de compensation.
              //
              // ⚠️ Différence assumée depuis le retrait : sans remontage,
              // l'étape courante est CONSERVÉE au retour en mode paginé, au
              // lieu d'être remise à la première.
              child: ZStepperEdition(
                controller: _controller,
                fields: kStepperSubListFields,
                steps: kStepperSubListSteps,
                config: ZStepperConfig(
                  showAllSteps: _expanded,
                  showSubtitles: true,
                ),
                padding: const EdgeInsetsDirectional.all(12),
                previousLabel: 'Précédent',
                nextLabel: 'Suivant',
                finishLabel: 'Terminer',
                onComplete: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Dossier agent complété.')),
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

/// Mode d'emploi affiché en tête — la page est lue comme un modèle.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      padding:
          const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        'Étape 1 : « Grade » suit « Corps » (choix dynamiques) et '
        '« Spécialités » est le même widget en multi. Étape 2 : « Suivant » '
        'refuse une map vide ET affiche pourquoi. Étape 3 : la bascule ACL de '
        'la barre retire les actions de ligne de la sous-liste. L\'icône '
        'déplier affiche toutes les étapes avec leur rail numéroté.',
        textAlign: TextAlign.start,
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}
