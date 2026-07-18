import 'package:zcrud_core/zcrud_core.dart';

import 'axis_harness.dart';
import 'dodlp_forms.dart';

/// Message d'erreur FIXE du champ requis `sRequired` du socle (AC3 « erreur de
/// validation »). Littéral stable ⇒ testable indépendamment de la locale.
const String showcaseRequiredError = 'Ce champ est requis (preuve fp-3-1)';

/// Données PUR-DONNÉES (`const` autant que possible) de la showcase MVP (fp-3-1).
///
/// Trois blocs, tous **fictifs** (aucune donnée réelle DODLP, aucun secret,
/// aucun backend — AC7) :
///  1. [socleFields]/[socleSections]/[socleLayout]/[socleInitialValues] — le
///     **socle représentatif** monté par le VRAI moteur (`DynamicEdition` →
///     `ZFieldWidget`) dans `ShowcaseScreen` (AC1/AC3). Chaque famille MVP livrée
///     (Epics 1-2) y figure UNE fois, y compris les états transverses
///     (read-only/désactivé/erreur/valeur initiale/conditionnel — AC3).
///  2. [axes] — l'**ossature par axes** (AC6) peuplée des axes MVP 1/5/6, les
///     axes 2/3/4 étant déclarés « à venir » (cohérent AC2). Réutilisée telle
///     quelle par fp-3-2 (ajout d'`AxisForm`, jamais réécriture de l'ossature).
///  3. [absentCapabilities] — les capacités **ABSENTES / à combler** (AC2),
///     déclarées EXPLICITEMENT (jamais masquées, jamais faux-rendues).
abstract final class ShowcaseData {
  // ── 1. SOCLE REPRÉSENTATIF (AC1) ──────────────────────────────────────────

  /// Familles de **saisie** clavier (texte/nombre) + booléen/date.
  static const List<ZFieldSpec> _entry = <ZFieldSpec>[
    ZFieldSpec(
      name: 'sText',
      type: EditionFieldType.text,
      label: 'Texte',
    ),
    ZFieldSpec(
      name: 'sMultiline',
      type: EditionFieldType.multiline,
      label: 'Texte multi-ligne',
      config: ZTextConfig(minLines: 2, maxLines: 4),
    ),
    ZFieldSpec(
      name: 'sPassword',
      type: EditionFieldType.password,
      label: 'Mot de passe',
    ),
    ZFieldSpec(name: 'sNumber', type: EditionFieldType.number, label: 'Nombre'),
    ZFieldSpec(name: 'sInteger', type: EditionFieldType.integer, label: 'Entier'),
    ZFieldSpec(name: 'sFloat', type: EditionFieldType.float, label: 'Décimal'),
    ZFieldSpec(
      name: 'sBoolean',
      type: EditionFieldType.boolean,
      label: 'Booléen (garde le conditionnel)',
    ),
    ZFieldSpec(
      name: 'sDate',
      type: EditionFieldType.dateTime,
      label: 'Date / heure',
    ),
    ZFieldSpec(name: 'sTime', type: EditionFieldType.time, label: 'Heure'),
    ZFieldSpec(
      name: 'sDateRange',
      type: EditionFieldType.dateRange,
      label: 'Plage de dates',
    ),
  ];

  /// Familles de **sélection** natives + relation.
  static const List<ZFieldSpec> _selection = <ZFieldSpec>[
    ZFieldSpec(
      name: 'sSelect',
      type: EditionFieldType.select,
      label: 'Liste déroulante',
      choices: <ZFieldChoice>[
        ZFieldChoice(value: 'a', label: 'Option A'),
        ZFieldChoice(value: 'b', label: 'Option B'),
        ZFieldChoice(value: 'c', label: 'Option C'),
      ],
    ),
    ZFieldSpec(
      name: 'sRadio',
      type: EditionFieldType.radio,
      label: 'Choix radio',
      choices: <ZFieldChoice>[
        ZFieldChoice(value: 'x', label: 'X'),
        ZFieldChoice(value: 'y', label: 'Y'),
      ],
    ),
    ZFieldSpec(
      name: 'sCheckbox',
      type: EditionFieldType.checkbox,
      label: 'Case à cocher',
    ),
    ZFieldSpec(
      name: 'sRelation',
      type: EditionFieldType.relation,
      label: 'Relation (choix statiques fictifs)',
      choices: <ZFieldChoice>[
        ZFieldChoice(value: 'u1', label: 'Fatou N.'),
        ZFieldChoice(value: 'u2', label: 'Kofi A.'),
      ],
    ),
    ZFieldSpec(
      name: 'sRowChips',
      type: EditionFieldType.rowChips,
      label: 'Puces mono-choix',
      choices: <ZFieldChoice>[
        ZFieldChoice(value: 's', label: 'Sport'),
        ZFieldChoice(value: 'm', label: 'Musique'),
      ],
    ),
    ZFieldSpec(name: 'sTags', type: EditionFieldType.tags, label: 'Étiquettes'),
  ];

  /// Familles **spécialisées / imbriquées**.
  static const List<ZFieldSpec> _specialized = <ZFieldSpec>[
    ZFieldSpec(
      name: 'sRating',
      type: EditionFieldType.rating,
      label: 'Note',
      config: ZRatingConfig(max: 5),
    ),
    ZFieldSpec(
      name: 'sSlider',
      type: EditionFieldType.slider,
      label: 'Curseur',
      config: ZSliderConfig(max: 100, divisions: 10),
    ),
    ZFieldSpec(
      name: 'sColor',
      type: EditionFieldType.color,
      label: 'Couleur (simple)',
    ),
    ZFieldSpec(
      name: 'sSignature',
      type: EditionFieldType.signature,
      label: 'Signature',
    ),
    ZFieldSpec(
      name: 'sSubItems',
      type: EditionFieldType.subItems,
      label: 'Sous-liste (réordonnable)',
      config: ZSubListConfig(
        itemFields: <ZFieldSpec>[
          ZFieldSpec(
            name: 'label',
            type: EditionFieldType.text,
            label: 'Libellé',
          ),
          ZFieldSpec(name: 'qty', type: EditionFieldType.integer, label: 'Qté'),
        ],
      ),
    ),
    ZFieldSpec(
      name: 'sDynamicItem',
      type: EditionFieldType.dynamicItem,
      label: 'Item dynamique',
      config: ZSubListConfig(
        itemFields: <ZFieldSpec>[
          ZFieldSpec(
            name: 'name',
            type: EditionFieldType.text,
            label: 'Nom',
          ),
        ],
      ),
    ),
  ];

  /// Familles **fichier NATIVES du cœur** (`ZAppFileField`, E3-3c) — rendues par
  /// leur VRAI adaptateur natif via le dispatcher (seams picker/storage injectés
  /// par `ZcrudScope` ; le picker showcase est partagé, aucune acquisition réelle).
  /// Étiquetées `liveNative` dans la matrice de couverture : montées ICI pour que
  /// le décompte « Livré natif » corresponde à un rendu EFFECTIF (MED-1 — jamais
  /// un type compté sans être monté).
  static const List<ZFieldSpec> _nativeFiles = <ZFieldSpec>[
    ZFieldSpec(
      name: 'sFile',
      type: EditionFieldType.file,
      label: 'Fichier (natif)',
    ),
    ZFieldSpec(
      name: 'sImage',
      type: EditionFieldType.image,
      label: 'Image (native)',
    ),
    ZFieldSpec(
      name: 'sDocument',
      type: EditionFieldType.document,
      label: 'Document (natif)',
    ),
  ];

  /// Kinds **satellites câblés** (servis par le composeur fp-2-2 via le
  /// `ZWidgetRegistry` injecté — markdown / intl / geo).
  static const List<ZFieldSpec> _satellites = <ZFieldSpec>[
    ZFieldSpec(
      name: 'sMarkdown',
      type: EditionFieldType.markdown,
      label: 'Markdown (satellite)',
    ),
    ZFieldSpec(
      name: 'sPhone',
      type: EditionFieldType.phoneNumber,
      label: 'Téléphone (satellite intl)',
    ),
    ZFieldSpec(
      name: 'sCountry',
      type: EditionFieldType.country,
      label: 'Pays (satellite intl)',
    ),
    ZFieldSpec(
      name: 'sAddress',
      type: EditionFieldType.address,
      label: 'Adresse (satellite intl)',
    ),
    ZFieldSpec(
      name: 'sLocation',
      type: EditionFieldType.location,
      label: 'Position (satellite geo, coordonnées-seules)',
    ),
  ];

  /// **Nouvelles capacités fp-4 / fp-5** (jadis ABSENTES, désormais LIVRÉES) —
  /// chacune rendue par son **VRAI adaptateur** (présence ≠ association) :
  ///  - `color` multiple → `ZColorMultiFieldWidget` (fp-4-4) ;
  ///  - `mediaImage`/`mediaFile`/`mediaVideo` → `ZMediaFieldWidget` (fp-4-2) ;
  ///  - `html`/`inlineHtml` : registrar `registerZHtmlFields` câblé et rendu en
  ///    **lecture** (`ZHtmlView`) démontré ; AUCUN champ html ÉDITABLE monté (tous
  ///    `readOnly`) — l'éditeur WYSIWYG WebView (`ZHtmlEditorField`) n'est pas
  ///    montable en `flutter test` (ET-5), l'édition au runtime reste hors démo
  ///    test ;
  ///  - `inlineMarkdown`/`richText` → `ZMarkdownField` (voies markdown restantes) ;
  ///  - `pin`/`autocomplete`/`editableTable` → `field_extras` (fp-5-2) ;
  ///  - `geoArea` → `ZGeoFieldWidget` (fp-5-3, coords-seules AD-12).
  static const List<ZFieldSpec> _richNew = <ZFieldSpec>[
    ZFieldSpec(
      name: 'sColorMulti',
      type: EditionFieldType.color,
      label: 'Couleur (multiple, fp-4-4)',
      config: ZColorConfig.multiple(),
    ),
    ZFieldSpec(name: 'sMediaImage', type: EditionFieldType.mediaImage, label: 'Image riche (média)'),
    ZFieldSpec(name: 'sMediaFile', type: EditionFieldType.mediaFile, label: 'Fichier riche (média)'),
    ZFieldSpec(name: 'sMediaVideo', type: EditionFieldType.mediaVideo, label: 'Vidéo riche (média)'),
    // ET-5 : lecture HTML montable (ZHtmlView), `readOnly` ⇒ aucun éditeur WYSIWYG
    // WebView monté en test (non montable headless) ; édition au runtime hors démo.
    ZFieldSpec(name: 'sHtml', type: EditionFieldType.html, label: 'HTML (lecture, fp-4-3)', readOnly: true),
    ZFieldSpec(name: 'sInlineHtml', type: EditionFieldType.inlineHtml, label: 'HTML inline (lecture)', readOnly: true),
    ZFieldSpec(name: 'sInlineMarkdown', type: EditionFieldType.inlineMarkdown, label: 'Markdown inline'),
    ZFieldSpec(name: 'sRichText', type: EditionFieldType.richText, label: 'Texte riche (Delta)'),
    ZFieldSpec(name: 'sPin', type: EditionFieldType.pin, label: 'Code PIN (field_extras)'),
    ZFieldSpec(name: 'sAutocomplete', type: EditionFieldType.autocomplete, label: 'Autocomplétion (field_extras)'),
    ZFieldSpec(name: 'sEditableTable', type: EditionFieldType.editableTable, label: 'Table éditable (field_extras)'),
    ZFieldSpec(name: 'sGeoArea', type: EditionFieldType.geoArea, label: 'Zone géo (coords-seules, fp-5-3)'),
  ];

  /// Champs dédiés aux **états transverses** (AC3) démontrés en plus du toggle
  /// global de lecture de la page :
  ///  - `sDisabled` : **désactivé** en permanence (`readOnly: true` par champ) ;
  ///  - `sRequired` : **erreur de validation** révélée (validateur `required`) ;
  ///  - `sPremium`  : **conditionnel** — masqué tant que `sBoolean` est faux.
  static const List<ZFieldSpec> _states = <ZFieldSpec>[
    ZFieldSpec(
      name: 'sDisabled',
      type: EditionFieldType.text,
      label: 'Champ désactivé (readOnly par champ)',
      readOnly: true,
    ),
    ZFieldSpec(
      name: 'sRequired',
      type: EditionFieldType.text,
      label: 'Champ requis (erreur si vide + « Valider »)',
      validators: <ZValidatorSpec>[
        // Message FIXE (indépendant de la locale) : révélé par « Valider ».
        ZValidatorSpec.required(errorText: showcaseRequiredError),
      ],
    ),
    ZFieldSpec(
      name: 'sPremium',
      type: EditionFieldType.text,
      label: 'Champ conditionnel (visible si booléen coché)',
      condition: ZCondition.truthy('sBoolean'),
    ),
  ];

  /// Socle PLAT complet (ordre canonique).
  static const List<ZFieldSpec> socleFields = <ZFieldSpec>[
    ..._entry,
    ..._selection,
    ..._specialized,
    ..._nativeFiles,
    ..._satellites,
    ..._richNew,
    ..._states,
  ];

  /// Sections visuelles du socle (repliables — parité `DynamicEdition`).
  static const List<ZEditionSection> socleSections = <ZEditionSection>[
    ZEditionSection(
      title: 'Saisie & dates',
      fields: <String>[
        'sText', 'sMultiline', 'sPassword', 'sNumber', 'sInteger', 'sFloat',
        'sBoolean', 'sDate', 'sTime', 'sDateRange',
      ],
    ),
    ZEditionSection(
      title: 'Sélections',
      collapsible: true,
      fields: <String>[
        'sSelect', 'sRadio', 'sCheckbox', 'sRelation', 'sRowChips', 'sTags',
      ],
    ),
    ZEditionSection(
      title: 'Spécialisés & imbriqués',
      collapsible: true,
      fields: <String>[
        'sRating', 'sSlider', 'sColor', 'sSignature', 'sSubItems',
        'sDynamicItem',
      ],
    ),
    ZEditionSection(
      title: 'Fichiers natifs (ZAppFileField)',
      collapsible: true,
      fields: <String>['sFile', 'sImage', 'sDocument'],
    ),
    ZEditionSection(
      title: 'Satellites (markdown / intl / geo)',
      collapsible: true,
      fields: <String>[
        'sMarkdown', 'sPhone', 'sCountry', 'sAddress', 'sLocation',
      ],
    ),
    ZEditionSection(
      title: 'Nouvelles capacités fp-4 / fp-5 (adaptateurs réels)',
      collapsible: true,
      fields: <String>[
        'sColorMulti', 'sMediaImage', 'sMediaFile', 'sMediaVideo',
        'sHtml', 'sInlineHtml', 'sInlineMarkdown', 'sRichText',
        'sPin', 'sAutocomplete', 'sEditableTable', 'sGeoArea',
      ],
    ),
    ZEditionSection(
      title: 'États transverses',
      collapsible: true,
      fields: <String>['sDisabled', 'sRequired', 'sPremium'],
    ),
  ];

  /// Grille responsive 12 colonnes (quelques champs compacts côte à côte).
  static const Map<String, ZResponsiveSpan> socleLayout =
      <String, ZResponsiveSpan>{
    'sNumber': ZResponsiveSpan(xs: 12, sm: 4),
    'sInteger': ZResponsiveSpan(xs: 12, sm: 4),
    'sFloat': ZResponsiveSpan(xs: 12, sm: 4),
    'sDate': ZResponsiveSpan(xs: 12, sm: 6),
    'sTime': ZResponsiveSpan(xs: 12, sm: 6),
  };

  /// Valeurs initiales fictives (AC3 « valeur initiale ») : une entrée par champ
  /// (crée toutes les tranches + `visibleFields` en ordre canonique) ; quelques
  /// champs sont **pré-remplis** pour démontrer l'amorçage.
  static Map<String, Object?> socleInitialValues() => <String, Object?>{
        for (final f in socleFields) f.name: _defaultFor(f),
        // Valeurs initiales explicites (démontrent l'amorçage AC3).
        'sText': 'Valeur initiale',
        'sInteger': 42,
        'sSelect': 'b',
        'sRating': 3,
        'sSlider': 40.0,
        'sDisabled': 'Non modifiable',
        // Nouvelles capacités fp-4/fp-5 : contenu HTML/markdown fictif (lecture).
        'sHtml': '<p>Contenu <b>HTML</b> fictif (lecture — ZHtmlView).</p>',
        'sInlineHtml': '<i>Étiquette HTML</i>',
        'sInlineMarkdown': '_markdown_ inline',
        'sRichText': 'Texte riche de démonstration',
      };

  static Object? _defaultFor(ZFieldSpec f) {
    switch (f.type) {
      case EditionFieldType.boolean:
      case EditionFieldType.checkbox:
        return false;
      case EditionFieldType.slider:
        return 0.0;
      case EditionFieldType.rating:
        return 0;
      case EditionFieldType.tags:
      case EditionFieldType.rowChips:
      case EditionFieldType.subItems:
      case EditionFieldType.editableTable:
        return const <Object?>[];
      case EditionFieldType.color:
        // `color` multiple ⇒ liste ARGB ; simple ⇒ `null` (int ARGB).
        return f.config is ZColorConfig && (f.config! as ZColorConfig).multiple
            ? const <int>[]
            : null;
      // ignore: no_default_cases
      default:
        return null;
    }
  }

  // ── 2. OSSATURE PAR AXES (AC6) ────────────────────────────────────────────

  /// Formulaire DENSE de l'axe 1, **banc SM-1** ([AxisForm.intensiveFieldName]
  /// non `null`) : frappe intensive sur `a1Text`, granularité prouvée par les
  /// badges de rebuild par champ.
  static const AxisForm _axis1Dense = AxisForm(
    id: 'axis1-dense',
    title: 'Axe 1 — saisie dense (banc SM-1)',
    intensiveFieldName: 'a1Text',
    fields: <ZFieldSpec>[
      ZFieldSpec(name: 'a1Text', type: EditionFieldType.text, label: 'Texte A'),
      ZFieldSpec(name: 'a1Text2', type: EditionFieldType.text, label: 'Texte B'),
      ZFieldSpec(
        name: 'a1Multiline',
        type: EditionFieldType.multiline,
        label: 'Notes',
        config: ZTextConfig(minLines: 2, maxLines: 3),
      ),
      ZFieldSpec(name: 'a1Num', type: EditionFieldType.number, label: 'Montant'),
      ZFieldSpec(name: 'a1Int', type: EditionFieldType.integer, label: 'Quantité'),
      ZFieldSpec(
        name: 'a1Date',
        type: EditionFieldType.dateTime,
        label: 'Échéance',
      ),
      ZFieldSpec(
        name: 'a1Bool',
        type: EditionFieldType.boolean,
        label: 'Prioritaire',
      ),
    ],
    initialValues: <String, Object?>{
      'a1Text': '',
      'a1Text2': '',
      'a1Multiline': '',
      'a1Num': null,
      'a1Int': null,
      'a1Date': null,
      'a1Bool': false,
    },
  );

  /// Formulaire de l'axe 5 (intl/geo) — servi par les satellites via le registre.
  static const AxisForm _axis5Intl = AxisForm(
    id: 'axis5-intl-geo',
    title: 'Axe 5 — intl & géo',
    fields: <ZFieldSpec>[
      ZFieldSpec(
        name: 'a5Phone',
        type: EditionFieldType.phoneNumber,
        label: 'Téléphone',
      ),
      ZFieldSpec(
        name: 'a5Country',
        type: EditionFieldType.country,
        label: 'Pays',
      ),
      ZFieldSpec(
        name: 'a5Location',
        type: EditionFieldType.location,
        label: 'Position',
      ),
    ],
    initialValues: <String, Object?>{
      'a5Phone': null,
      'a5Country': null,
      'a5Location': null,
    },
  );

  /// Formulaire de l'axe 6 (spécialisés / imbriqués).
  static const AxisForm _axis6Special = AxisForm(
    id: 'axis6-specialized',
    title: 'Axe 6 — spécialisés & imbriqués',
    fields: <ZFieldSpec>[
      ZFieldSpec(
        name: 'a6Rating',
        type: EditionFieldType.rating,
        label: 'Note',
        config: ZRatingConfig(max: 5),
      ),
      ZFieldSpec(
        name: 'a6Slider',
        type: EditionFieldType.slider,
        label: 'Intensité',
        config: ZSliderConfig(max: 100, divisions: 10),
      ),
      ZFieldSpec(
        name: 'a6Signature',
        type: EditionFieldType.signature,
        label: 'Signature',
      ),
      ZFieldSpec(
        name: 'a6Color',
        type: EditionFieldType.color,
        label: 'Couleur',
      ),
      ZFieldSpec(
        name: 'a6Sub',
        type: EditionFieldType.subItems,
        label: 'Lignes (réordonnables)',
        config: ZSubListConfig(
          itemFields: <ZFieldSpec>[
            ZFieldSpec(
              name: 'designation',
              type: EditionFieldType.text,
              label: 'Désignation',
            ),
            ZFieldSpec(name: 'qty', type: EditionFieldType.integer, label: 'Qté'),
          ],
        ),
      ),
    ],
    initialValues: <String, Object?>{
      'a6Rating': 0,
      'a6Slider': 0.0,
      'a6Signature': null,
      'a6Color': null,
      'a6Sub': <Object?>[],
    },
  );

  /// Ossature complète : axes MVP 1/5/6 peuplés + axes 2/3/4 « à venir ».
  ///
  /// **fp-3-2** branche les 6 formulaires DODLP complets et les axes 2/3/4 en
  /// ajoutant des [AxisForm] ici — sans réécrire l'ossature (`axis_harness.dart`).
  ///
  /// **fp-3-2** : les 6 axes sont désormais `mvp` (FP-4/FP-5 tous `done`), chacun
  /// peuplé d'AU MOINS un formulaire DODLP répliqué ([DodlpForms], données
  /// fictives). Les axes 2/3/4, jadis `upcoming`, sont peuplés — leurs capacités
  /// riches ne sont plus ABSENTES (cf. [absentCapabilities], réduit aux vrais gaps).
  static const List<ShowcaseAxis> axes = <ShowcaseAxis>[
    ShowcaseAxis(
      id: 'axis-1',
      title: 'Axe 1 — Texte / nombre / date',
      subtitle: 'Saisie dense + banc SM-1 · formulaire Cargaison (pia)',
      status: AxisStatus.mvp,
      forms: <AxisForm>[_axis1Dense, DodlpForms.cargaison],
    ),
    ShowcaseAxis(
      id: 'axis-2',
      title: 'Axe 2 — Sélections riches (modal)',
      subtitle: 'select / radio / relation (ZSmartSelectPresenter) · Demande de dépotage (vido)',
      status: AxisStatus.mvp,
      forms: <AxisForm>[DodlpForms.demandeDepotage],
    ),
    ShowcaseAxis(
      id: 'axis-3',
      title: 'Axe 3 — Média & fichiers',
      subtitle: 'mediaImage / mediaFile / mediaVideo (zcrud_media) · Profil agent (auth)',
      status: AxisStatus.mvp,
      forms: <AxisForm>[DodlpForms.authProfile],
    ),
    ShowcaseAxis(
      id: 'axis-4',
      title: 'Axe 4 — HTML & rich-text',
      subtitle: 'html/inlineHtml (zcrud_html) + markdown · Article & cotation (sse)',
      status: AxisStatus.mvp,
      forms: <AxisForm>[DodlpForms.articleCotation],
    ),
    ShowcaseAxis(
      id: 'axis-5',
      title: 'Axe 5 — Intl & géo',
      subtitle: 'phoneNumber / country / address / location · Consignataire (bmd)',
      status: AxisStatus.mvp,
      forms: <AxisForm>[_axis5Intl, DodlpForms.consignee],
    ),
    ShowcaseAxis(
      id: 'axis-6',
      title: 'Axe 6 — Spécialisés & imbriqués',
      subtitle: 'rating / slider / signature / color / dateRange · Convocation (bmd)',
      status: AxisStatus.mvp,
      forms: <AxisForm>[_axis6Special, DodlpForms.convocation],
    ),
  ];

  // ── 3. CAPACITÉS ABSENTES / À COMBLER (AC2) ───────────────────────────────

  /// Gaps **ASSUMÉS** restants (fp-3-2, AC4) — étiquetés EXPLICITEMENT ABSENT,
  /// jamais masqués, jamais faux-rendus. Les capacités jadis absentes livrées par
  /// FP-4/FP-5 (select modal, média, html, color multiple, pin, autocomplete,
  /// editableTable) ont été **RETIRÉES** de cette liste : elles sont désormais
  /// démontrées LIVE via leur vrai adaptateur (cf. `_richNew` + les 6 formulaires
  /// DODLP). Ne subsistent QUE les vrais gaps (OQ-6/OQ-7, justifiés) :
  static const List<AbsentCapability> absentCapabilities = <AbsentCapability>[
    AbsentCapability(
      kind: 'icon',
      label: 'Sélecteur d\'icône',
      reason: 'Picker d\'icône — hors parité MVP, aucun besoin produit prouvé '
          '(FIELD-PACKAGE-MATRIX #29).',
    ),
    AbsentCapability(
      kind: 'latexSvgFallback',
      label: 'LaTeX fallback SVG (flutter_tex)',
      reason: 'flutter_tex BANNI par le test d\'isolation (FIELD-PACKAGE-MATRIX '
          '#33, D6) → placeholder thémé, jamais de SVG. Gap par architecture.',
    ),
    AbsentCapability(
      kind: 'itemsAreTags',
      label: 'Variante « items = tags »',
      reason: 'Mode natif ZSubListDisplayMode.tags existe (fp-5-1) mais 0 '
          'call-site actif dans DODLP cloné → consigné OQ-6 (non exercé).',
    ),
  ];
}
