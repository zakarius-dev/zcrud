/// **Catalogue `EditionFieldType` → statut**, et son rendu Markdown.
///
/// ## Le besoin, mesuré
///
/// CR d'exploration DODLP du 2026-08-06, §7 : **problème de découvrabilité**.
/// DODLP a écrit un `ZDateRangeField` maison
/// (`dodlp-otr/lib/src/config/zcrud/z_date_range_field.dart`) en affirmant dans
/// son propre dartdoc que « zcrud n'a pas de type `dateRange` dans son
/// catalogue » — alors que `EditionFieldType.dateRange` et son widget dédié
/// existent depuis **v0.10.0** (commit `ae3a6ad`, 2026-07-18) et que DODLP
/// consomme déjà **v0.59.0**. L'hôte demande que le socle **publie et
/// maintienne** la table « type → statut ».
///
/// ## 🔴 Pourquoi ce fichier vit dans `test/`, et pas dans `lib/`
///
/// Un tableau de 46 lignes écrit à la main devient faux au premier type
/// ajouté ; le dépôt a déjà été mordu par des dartdoc périmés. Le livrable doit
/// donc être **dérivé du code**. Mais le dériver ne justifie pas de
/// l'**embarquer** :
///
/// * **Coût runtime nul.** Rien ici n'est exporté par `lib/zcrud_core.dart` :
///   un hôte qui ne lit pas la doc ne paie **0 octet** (ni la table, ni la
///   prose, ni le renderer Markdown).
/// * **FR-26 / NFR-S7 par CONSTRUCTION.** Ce catalogue porte de la prose
///   destinée aux **développeurs** (en-têtes de colonnes, notes). Si elle
///   vivait dans `lib/`, un hôte pourrait l'afficher — un libellé non localisé
///   dans une UI. Hors de `lib/`, ce n'est pas « interdit par convention » :
///   c'est **inatteignable** depuis une application.
/// * **AD-1 sans arête.** Le rattachement d'un type à son paquet satellite
///   ([ZFieldTypeEntry.satellite]) est une **`String` inerte** — jamais un
///   `import`. Le graphe de `zcrud_core` reste **OUT = 0**. C'est la forme sûre
///   demandée : elle *informe* sur `zcrud_geo` sans jamais le *référencer*.
///   La véracité de cette `String` n'est pas laissée à la confiance : elle est
///   **vérifiée sur disque** par la garde (le paquet doit exister ET mentionner
///   le `kind` du type).
///
/// ## Les trois propriétés, et où elles sont tenues
///
/// 1. **Exhaustivité forcée** — [entryFor] est un `switch` **expression**
///    exhaustif **sans `default`** sur `EditionFieldType`. Ajouter une valeur à
///    l'enum sans lui donner d'entrée **casse la compilation** de ce fichier,
///    donc la suite de tests entière. (Filet de sécurité redondant côté garde :
///    un test vérifie que [kZFieldTypeCatalog] couvre les 46 valeurs, une fois
///    chacune.)
/// 2. **Synchronisation prouvée** — [renderZFieldTypeCatalogMarkdown] produit
///    le document ; la garde lit `docs/zcrud-field-type-catalog.md` **tel qu'il
///    est sur disque** et compare. Elle ne régénère jamais avant de comparer.
/// 3. **Statut MESURÉ, pas déclaré** — il n'existe **aucun champ où écrire un
///    statut**. [ZFieldTypeEntry.support] est un *getter* dérivé de
///    `familyOf(type)`, c'est-à-dire de la classification que le **dispatcher
///    lui-même** consulte. Déclarer « supporté » un type que le dispatcher
///    route en `unsupported` est donc **inexprimable**, pas seulement
///    déconseillé.
///
/// ## Totalité (AD-10)
///
/// Aucune fonction de ce fichier ne lève : [entryFor] est totale par
/// exhaustivité, [renderZFieldTypeCatalogMarkdown] est une pure concaténation.
library;

import 'package:zcrud_core/zcrud_core.dart';

/// Chemin du document publié, **relatif à la racine du dépôt** (le dossier qui
/// porte `melos.yaml`).
const String kZFieldTypeCatalogDocPath = 'docs/zcrud-field-type-catalog.md';

/// Ce qu'un hôte doit faire pour obtenir un rendu — **dérivé**, jamais déclaré.
///
/// Voir [ZFieldTypeEntry.support] pour la règle de dérivation.
enum ZFieldTypeSupport {
  /// Widget dédié **dans `zcrud_core`** : rien à ajouter.
  core,

  /// Widget servi par un **paquet satellite zcrud** : l'hôte ajoute la
  /// dépendance et appelle sa fonction d'enregistrement.
  satellite,

  /// Aucun widget fourni : l'**application** enregistre le sien dans le
  /// `ZWidgetRegistry` (point d'extension AD-4). Repli propre sinon.
  hostRegistry,

  /// Pas de widget-feuille — **délibérément** —, mais la fonctionnalité existe
  /// dans le cœur par un **autre chemin d'API** (cf. `stepper`).
  coreAlternatePath,

  /// Champ **non rendu**, par conception.
  notRendered,
}

/// Une ligne du catalogue. **Aucun champ de statut** : le statut est un getter.
final class ZFieldTypeEntry {
  /// Construit une entrée. Tout est optionnel sauf le [type] : ce qui n'est pas
  /// renseigné se traduit par un statut **dégradé**, jamais par une promesse.
  const ZFieldTypeEntry(
    this.type, {
    this.config,
    this.source,
    this.satellite,
    this.registrar,
    this.alternates = const <String>[],
    this.seams = const <String>[],
  });

  /// Le type catalogué.
  final EditionFieldType type;

  /// Classe de configuration dédiée consultée par le moteur pour ce type, ou
  /// `null` s'il n'en a pas.
  ///
  /// C'est un **littéral de `Type`** : nommer une classe inexistante ne
  /// compile pas. La garde vérifie en plus qu'elle est **vivante** (consultée
  /// par un `is <Config>` quelque part dans `lib/`), donc jamais décorative.
  final Type? config;

  /// Chemin — **relatif à la racine du dépôt** — du fichier où trouver le
  /// rendu. Son **existence est vérifiée sur disque** par la garde : c'est
  /// exactement le défaut historique (un dartdoc citant un fichier inexistant)
  /// rendu impossible.
  final String? source;

  /// Nom du **paquet** satellite qui sert ce type, ou `null`.
  ///
  /// 🔴 `String` inerte — **aucun `import`**, donc aucune arête AD-1. La garde
  /// vérifie que `packages/<satellite>/` existe et mentionne le `kind` du type.
  final String? satellite;

  /// Fonction d'enregistrement exposée par le [satellite] (ce que l'hôte doit
  /// appeler au bootstrap). Vérifiée présente dans les sources du satellite.
  final String? registrar;

  /// Chemins d'API **alternatifs** du cœur qui servent ce type autrement qu'en
  /// widget-feuille. Non vide ⇒ le type est servi malgré une famille
  /// `unsupported`. Existence vérifiée sur disque.
  final List<String> alternates;

  /// Seams (dépendances injectables au `ZcrudScope`) que ce type consomme.
  ///
  /// Noms de types, pas littéraux de `Type` : plusieurs seams sont des
  /// **`typedef` de fonction** (`ZColorPicker`), dont le `Type` runtime rend la
  /// signature complète et non le nom — illisible dans un tableau. La garde
  /// compense en vérifiant **sur disque** deux choses plus fortes qu'un
  /// littéral : le nom est déclaré dans `zcrud_core/lib/` (`class`/`typedef`)
  /// **et** c'est bien un champ de `ZcrudScope` — donc un vrai point
  /// d'injection, pas n'importe quel type.
  final List<String> seams;

  /// La famille que **le dispatcher** associe à ce type. Appel réel à
  /// `familyOf` — pas une copie.
  EditionFamily get family => familyOf(type);

  /// Le `kind` sous lequel un widget doit être enregistré au `ZWidgetRegistry`,
  /// ou `null` si le type ne passe pas par le registre. **Dérivé** de la
  /// convention réelle du dispatcher (`kind == field.type.name`).
  String? get registryKind => switch (family) {
        EditionFamily.registryOrFallback || EditionFamily.freeWidget =>
          type.name,
        _ => null,
      };

  /// Statut **dérivé** — il n'y a nulle part où en écrire un autre.
  ZFieldTypeSupport get support => switch (family) {
        EditionFamily.hidden => ZFieldTypeSupport.notRendered,
        EditionFamily.unsupported => alternates.isEmpty
            ? ZFieldTypeSupport.hostRegistry
            : ZFieldTypeSupport.coreAlternatePath,
        EditionFamily.registryOrFallback || EditionFamily.freeWidget =>
          satellite == null
              ? ZFieldTypeSupport.hostRegistry
              : ZFieldTypeSupport.satellite,
        _ => ZFieldTypeSupport.core,
      };
}

/// Entrée du [type], par `switch` **exhaustif sans `default`**.
///
/// 🔴 Ajouter une valeur à `EditionFieldType` sans la traiter ici **ne compile
/// pas**. C'est la propriété 1 : l'exhaustivité n'est pas surveillée, elle est
/// structurellement impossible à violer.
ZFieldTypeEntry entryFor(EditionFieldType type) => switch (type) {
      // ── Familles de base servies par un widget dédié du cœur ───────────────
      EditionFieldType.text ||
      EditionFieldType.multiline ||
      EditionFieldType.password =>
        ZFieldTypeEntry(
          type,
          config: ZTextConfig,
          source: '${_kFamilies}z_text_field_widget.dart',
        ),
      EditionFieldType.number ||
      EditionFieldType.integer ||
      EditionFieldType.float =>
        ZFieldTypeEntry(
          type,
          config: ZNumberConfig,
          source: '${_kFamilies}z_number_field_widget.dart',
        ),
      EditionFieldType.boolean => ZFieldTypeEntry(
          type,
          source: '${_kFamilies}z_boolean_field_widget.dart',
        ),
      EditionFieldType.dateTime || EditionFieldType.time => ZFieldTypeEntry(
          type,
          config: ZDateConfig,
          source: '${_kFamilies}z_date_field_widget.dart',
        ),
      // MESURÉ : le dispatcher ne lit AUCUNE config pour `dateRange`
      // (`z_field_widget.dart`, branche `EditionFamily.dateRange`) — pas de
      // bornes `firstDate`/`lastDate` comme pour `date`. La colonne le dit.
      EditionFieldType.dateRange => ZFieldTypeEntry(
          type,
          source: '${_kFamilies}z_date_range_field_widget.dart',
        ),
      EditionFieldType.select ||
      EditionFieldType.radio ||
      EditionFieldType.checkbox =>
        ZFieldTypeEntry(
          type,
          config: ZSelectConfig,
          source: '${_kFamilies}z_select_field_widget.dart',
          seams: const <String>['ZSelectPresenter', 'ZChoicesSourceRegistry'],
        ),
      EditionFieldType.relation => ZFieldTypeEntry(
          type,
          config: ZRelationConfig,
          source: '${_kFamilies}z_relation_field_widget.dart',
          seams: const <String>[
            'ZRelationSourceRegistry',
            'ZRelationCrudRegistry',
          ],
        ),
      EditionFieldType.rowChips => ZFieldTypeEntry(
          type,
          source: '${_kFamilies}z_row_chips_field_widget.dart',
        ),
      EditionFieldType.tags => ZFieldTypeEntry(
          type,
          source: '${_kFamilies}z_tags_field_widget.dart',
        ),
      EditionFieldType.rating => ZFieldTypeEntry(
          type,
          config: ZRatingConfig,
          source: '${_kFamilies}z_rating_field_widget.dart',
        ),
      EditionFieldType.slider => ZFieldTypeEntry(
          type,
          config: ZSliderConfig,
          source: '${_kFamilies}z_slider_field_widget.dart',
        ),
      EditionFieldType.color => ZFieldTypeEntry(
          type,
          config: ZColorConfig,
          source: '${_kFamilies}z_color_field_widget.dart',
          seams: const <String>['ZColorPicker'],
        ),
      EditionFieldType.subItems => ZFieldTypeEntry(
          type,
          config: ZSubListConfig,
          source: '${_kFamilies}z_sub_list_field_widget.dart',
        ),
      EditionFieldType.dynamicItem => ZFieldTypeEntry(
          type,
          config: ZSubListConfig,
          source: '${_kFamilies}z_dynamic_item_field_widget.dart',
        ),
      EditionFieldType.signature => ZFieldTypeEntry(
          type,
          source: '${_kFamilies}z_signature_field_widget.dart',
        ),
      EditionFieldType.file ||
      EditionFieldType.image ||
      EditionFieldType.document =>
        ZFieldTypeEntry(
          type,
          config: FileFieldConfig,
          source: '${_kFamilies}z_app_file_field_widget.dart',
          seams: const <String>['ZFilePicker', 'CloudStorageRepository'],
        ),

      // ── Types servis par un PAQUET SATELLITE (String inerte — AD-1) ────────
      EditionFieldType.markdown ||
      EditionFieldType.inlineMarkdown ||
      EditionFieldType.richText =>
        ZFieldTypeEntry(
          type,
          satellite: 'zcrud_markdown',
          registrar: 'registerZMarkdownFields',
          source: 'packages/zcrud_markdown/lib/src/presentation/'
              'z_markdown_registration.dart',
        ),
      EditionFieldType.html || EditionFieldType.inlineHtml => ZFieldTypeEntry(
          type,
          satellite: 'zcrud_html',
          registrar: 'registerZHtmlFields',
          source: 'packages/zcrud_html/lib/src/presentation/'
              'z_html_wysiwyg_registration.dart',
        ),
      EditionFieldType.location || EditionFieldType.geoArea => ZFieldTypeEntry(
          type,
          satellite: 'zcrud_geo',
          source: 'packages/zcrud_geo/lib/src/presentation/'
              'z_geo_field_widget.dart',
        ),
      // MESURÉ : `zcrud_intl` n'expose PAS de registrar global pour ces deux
      // kinds — l'hôte enregistre lui-même le builder du widget. Le catalogue
      // le dit au lieu d'inventer un `registerZIntlFields` qui n'existe pas.
      EditionFieldType.phoneNumber => ZFieldTypeEntry(
          type,
          satellite: 'zcrud_intl',
          source: 'packages/zcrud_intl/lib/src/presentation/'
              'z_phone_field_widget.dart',
        ),
      EditionFieldType.country => ZFieldTypeEntry(
          type,
          satellite: 'zcrud_intl',
          source: 'packages/zcrud_intl/lib/src/presentation/'
              'z_country_field_widget.dart',
        ),
      EditionFieldType.address => ZFieldTypeEntry(
          type,
          satellite: 'zcrud_intl',
          registrar: 'registerZAddressFieldWidgets',
          source: 'packages/zcrud_intl/lib/src/presentation/'
              'z_address_field_widget.dart',
        ),
      EditionFieldType.pin ||
      EditionFieldType.autocomplete ||
      EditionFieldType.editableTable =>
        ZFieldTypeEntry(
          type,
          satellite: 'zcrud_field_extras',
          registrar: 'registerZFieldExtrasFields',
          source: 'packages/zcrud_field_extras/lib/src/presentation/'
              'z_field_extras_registrar.dart',
        ),
      EditionFieldType.mediaImage ||
      EditionFieldType.mediaFile ||
      EditionFieldType.mediaVideo =>
        ZFieldTypeEntry(
          type,
          satellite: 'zcrud_media',
          registrar: 'registerZMediaFieldWidgets',
          source: 'packages/zcrud_media/lib/src/presentation/'
              'z_media_field_widget.dart',
        ),

      // ── Points d'extension de l'APPLICATION (aucun satellite) ──────────────
      // MESURÉ : `icon` n'est enregistré par AUCUN paquet du monorepo — grep
      // `EditionFieldType.icon` sur `packages/*/lib/` ne renvoie que la
      // classification du cœur elle-même. Il dégrade donc en repli contrôlé
      // tant que l'application n'enregistre pas son propre builder.
      EditionFieldType.icon ||
      EditionFieldType.custom =>
        ZFieldTypeEntry(
          type,
          source: '${_kEdition}families/z_unsupported_field_widget.dart',
          seams: const <String>['ZWidgetRegistry'],
        ),
      EditionFieldType.widget => ZFieldTypeEntry(
          type,
          source: '${_kEdition}families/z_free_widget_field_widget.dart',
          seams: const <String>['ZWidgetRegistry'],
        ),

      // ── Non rendu, délibérément ────────────────────────────────────────────
      EditionFieldType.hidden => ZFieldTypeEntry(
          type,
          source: '${_kEdition}z_field_widget.dart',
        ),

      // ── 🔴 Le piège du catalogue : `unsupported` ≠ « pas disponible » ──────
      // `stepper` est classé `EditionFamily.unsupported` **délibérément** : le
      // dispatcher mappe un `kind` vers un widget-FEUILLE porteur d'UNE tranche
      // de valeur, or un stepper est un **regroupement** qui doit rester le
      // single-writer de `controller.visibleFields` (dartdoc de
      // `z_step_partition.dart`). Le router par le registre casserait cet
      // invariant. Le stepper est **pleinement supporté**, par un AUTRE chemin.
      // C'est précisément la ligne qu'une table naïve rendrait toxique.
      EditionFieldType.stepper => ZFieldTypeEntry(
          type,
          config: ZStepFieldConfig,
          alternates: <String>[
            '${_kEdition}z_step_partition.dart',
            '${_kEdition}z_stepper_edition.dart',
            '${_kEdition}z_stepper_config.dart',
          ],
        ),
    };

const String _kEdition =
    'packages/zcrud_core/lib/src/presentation/edition/';
const String _kFamilies = '${_kEdition}families/';

/// Le catalogue complet, dans l'ordre de déclaration de `EditionFieldType`.
final List<ZFieldTypeEntry> kZFieldTypeCatalog = EditionFieldType.values
    .map(entryFor)
    .toList(growable: false);

// ─────────────────────────────────────────────────────────────────────────────
// Rendu Markdown
// ─────────────────────────────────────────────────────────────────────────────

/// Libellé de colonne « statut ». Prose **développeur**, confinée à `test/`.
String _supportLabel(ZFieldTypeSupport s) => switch (s) {
      ZFieldTypeSupport.core => 'cœur',
      ZFieldTypeSupport.satellite => 'satellite',
      ZFieldTypeSupport.hostRegistry => 'registre app',
      ZFieldTypeSupport.coreAlternatePath => 'cœur (autre chemin)',
      ZFieldTypeSupport.notRendered => 'non rendu',
    };

/// Ce que l'hôte doit faire, **dérivé** de l'entrée (jamais recopié).
String _action(ZFieldTypeEntry e) => switch (e.support) {
      ZFieldTypeSupport.core => 'rien à ajouter',
      ZFieldTypeSupport.satellite => e.registrar == null
          ? 'ajouter `${e.satellite}`, puis enregistrer le `kind` soi-même '
              '(pas de registrar global — cf. « Où regarder »)'
          : 'ajouter `${e.satellite}` puis `${e.registrar}(registry)`',
      ZFieldTypeSupport.hostRegistry =>
        "`ZWidgetRegistry.register('${e.registryKind ?? e.type.name}', …)` "
            '— repli `ZUnsupportedFieldWidget` sinon',
      ZFieldTypeSupport.coreAlternatePath =>
        'passer par `zPartitionFieldsIntoSteps` + `ZStepperEdition`',
      ZFieldTypeSupport.notRendered => 'aucune — champ volontairement invisible',
    };

/// Rend le document publié. **Fonction pure** : mêmes entrées ⇒ même octet.
String renderZFieldTypeCatalogMarkdown() {
  final StringBuffer b = StringBuffer()
    ..writeln('<!-- GÉNÉRÉ — NE PAS ÉDITER À LA MAIN. -->')
    ..writeln('<!-- Source : packages/zcrud_core/test/support/'
        'z_field_type_catalog.dart -->')
    ..writeln('<!-- Garde de synchronisation : packages/zcrud_core/test/'
        'z_field_type_catalog_test.dart -->')
    ..writeln()
    ..writeln('# Catalogue des types de champ zcrud')
    ..writeln()
    ..writeln('Table de découverte demandée par le CR d\'exploration DODLP du '
        '2026-08-06 (§7). Elle répond à une seule question : **« ce type '
        'existe-t-il déjà, et que dois-je ajouter pour l\'obtenir ? »**')
    ..writeln()
    ..writeln('🔴 **Ce document est dérivé du code, pas écrit à la main.** '
        'Chaque colonne est mesurée :')
    ..writeln()
    ..writeln('* la **famille** est le retour réel de `familyOf(type)` — la '
        'classification que le dispatcher `ZFieldWidget` consulte lui-même ;')
    ..writeln('* le **statut** est *dérivé* de cette famille : il n\'existe '
        'aucun champ où en écrire un autre, donc aucun type ne peut être '
        'annoncé « supporté » pendant que le dispatcher le route en repli ;')
    ..writeln('* la **config** est un littéral de `Type` (nommer une classe '
        'inexistante ne compile pas), et une garde vérifie qu\'elle est '
        'réellement consultée dans `lib/` ;')
    ..writeln('* les **chemins** et les **paquets satellites** sont vérifiés '
        'présents sur disque par la garde.')
    ..writeln()
    ..writeln('Une valeur ajoutée à `EditionFieldType` sans entrée ici **casse '
        'la compilation** ; un document divergent du code **fait rougir la '
        'suite de tests**.')
    ..writeln()
    ..writeln('| Type | Famille (dispatcher) | Statut | À faire côté hôte | '
        '`kind` de registre | Config | Où regarder |')
    ..writeln('|---|---|---|---|---|---|---|');

  for (final ZFieldTypeEntry e in kZFieldTypeCatalog) {
    final String where = e.alternates.isNotEmpty
        ? e.alternates.map((String p) => '`$p`').join('<br>')
        : (e.source == null ? '—' : '`${e.source}`');
    b.writeln('| `${e.type.name}` '
        '| `${e.family.name}` '
        '| ${_supportLabel(e.support)} '
        '| ${_action(e)} '
        '| ${e.registryKind == null ? '—' : '`${e.registryKind}`'} '
        '| ${e.config == null ? '—' : '`${e.config}`'} '
        '| $where |');
  }

  b
    ..writeln()
    ..writeln('## Seams injectables par type')
    ..writeln()
    ..writeln('Dépendances optionnelles fournies au `ZcrudScope`. Un seam '
        'absent ne fait jamais échouer le rendu (AD-10) : l\'action concernée '
        'est simplement désactivée.')
    ..writeln()
    ..writeln('| Type | Seams (`ZcrudScope`) |')
    ..writeln('|---|---|');
  for (final ZFieldTypeEntry e
      in kZFieldTypeCatalog.where((ZFieldTypeEntry e) => e.seams.isNotEmpty)) {
    b.writeln('| `${e.type.name}` | '
        '${e.seams.map((String t) => '`$t`').join(', ')} |');
  }

  b
    ..writeln()
    ..writeln('## Les trois lignes qui trompent')
    ..writeln()
    ..writeln('### `stepper` — `unsupported` ne veut PAS dire indisponible')
    ..writeln()
    ..writeln('`familyOf(EditionFieldType.stepper)` retourne bien '
        '`unsupported`, et c\'est **délibéré** : le dispatcher associe un '
        '`kind` à un widget-**feuille** porteur d\'UNE tranche de valeur, alors '
        'qu\'un stepper est un **regroupement** qui doit rester le seul '
        'écrivain de `controller.visibleFields`. Le router par le registre '
        'casserait cet invariant.')
    ..writeln()
    ..writeln('Le stepper est **pleinement supporté**, par un autre chemin : '
        'déclarez vos champs à plat en les annotant d\'un `ZStepFieldConfig`, '
        'puis `zPartitionFieldsIntoSteps` en dérive les `ZEditionStep` que '
        '`ZStepperEdition` consomme. N\'écrivez pas de stepper maison.')
    ..writeln()
    ..writeln('### Types servis par un satellite — aucune arête vers `zcrud_core`')
    ..writeln()
    ..writeln('`zcrud_core` **n\'importe aucun paquet zcrud** (AD-1, graphe '
        'sortant = 0) : il ne peut donc pas « contenir » ces widgets. Il se '
        'contente de **nommer** le type et de router vers le `ZWidgetRegistry` '
        'injecté ; tant que le `kind` n\'y est pas enregistré, le champ dégrade '
        'en `ZUnsupportedFieldWidget` — jamais un crash (AD-10).')
    ..writeln()
    ..writeln('La colonne « satellite » de ce document est donc une **chaîne '
        'de caractères inerte** dans un fichier de test, jamais un `import` : '
        'elle informe sans créer d\'arête. Sa véracité n\'est pas laissée à la '
        'confiance — la garde vérifie sur disque que le paquet existe et qu\'il '
        'mentionne bien le `kind` annoncé.')
    ..writeln()
    ..writeln('### Types sans widget nulle part')
    ..writeln()
    ..writeln('`icon` et `custom` ne sont servis par **aucun** paquet du '
        'monorepo. Contournement : enregistrez votre propre builder sous le '
        '`kind` indiqué (`ZWidgetRegistry.register`) ; c\'est le point '
        'd\'extension prévu (AD-4), le même que pour `widget`. `hidden`, lui, '
        'n\'a pas de contournement parce qu\'il n\'a pas de problème : il est '
        'invisible par contrat.');

  return b.toString();
}
