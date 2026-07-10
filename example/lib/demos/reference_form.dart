import 'package:zcrud_core/zcrud_core.dart';

/// Schéma de RÉFÉRENCE de la démo d'édition (EX-1, AC4/AC5) : ≥ 30 champs sur
/// ≥ 3 sections, exerçant les familles E3 servies par le cœur (texte/nombre/
/// date/booléen/select/relation, tags/rowChips, rating/slider/color, signature,
/// file/image/document, sous-liste inline `subItems`), avec ≥ 1 champ
/// CONDITIONNEL (`premiumCode` visible seulement si `active` est vrai) et une
/// grille responsive. C'est le formulaire canonique du profiling SM-1 (frappe
/// de 100 caractères → un seul champ reconstruit).
///
/// PUR-DONNÉES (`const`) — aucune closure, aucun widget (AD-2/AD-3). Réutilisé à
/// l'identique par [DynamicEdition] (mode plat), [ZStepperEdition] (mode étapes)
/// et par CHAQUE binding (parité AD-15) : le schéma est manager-agnostique.
abstract final class ReferenceForm {
  /// Champs de la section « Identité ».
  static const List<ZFieldSpec> _identity = <ZFieldSpec>[
    ZFieldSpec(
      name: 'fullName',
      type: EditionFieldType.text,
      label: 'Nom complet',
      validators: <ZValidatorSpec>[
        ZValidatorSpec.required(),
        ZValidatorSpec.minLength(2),
      ],
      searchable: true,
    ),
    ZFieldSpec(name: 'nickname', type: EditionFieldType.text, label: 'Surnom'),
    ZFieldSpec(
      name: 'bio',
      type: EditionFieldType.multiline,
      label: 'Biographie',
      config: ZTextConfig(minLines: 2, maxLines: 4),
    ),
    ZFieldSpec(
      name: 'email',
      type: EditionFieldType.text,
      label: 'Courriel',
      validators: <ZValidatorSpec>[ZValidatorSpec.email()],
    ),
    ZFieldSpec(
      name: 'website',
      type: EditionFieldType.text,
      label: 'Site web',
      validators: <ZValidatorSpec>[ZValidatorSpec.url()],
    ),
    ZFieldSpec(name: 'age', type: EditionFieldType.integer, label: 'Âge'),
    ZFieldSpec(
      name: 'heightCm',
      type: EditionFieldType.number,
      label: 'Taille (cm)',
    ),
    ZFieldSpec(name: 'ratio', type: EditionFieldType.float, label: 'Ratio'),
    ZFieldSpec(
      name: 'birthDate',
      type: EditionFieldType.dateTime,
      label: 'Date de naissance',
    ),
    ZFieldSpec(name: 'wakeTime', type: EditionFieldType.time, label: 'Réveil'),
    // Champ de GARDE du conditionnel `premiumCode`.
    ZFieldSpec(
      name: 'active',
      type: EditionFieldType.boolean,
      label: 'Compte actif',
    ),
    ZFieldSpec(
      name: 'newsletter',
      type: EditionFieldType.checkbox,
      label: 'Infolettre',
    ),
  ];

  /// Champs de la section « Préférences ».
  static const List<ZFieldSpec> _preferences = <ZFieldSpec>[
    ZFieldSpec(
      name: 'country',
      type: EditionFieldType.select,
      label: 'Pays',
      choices: <ZFieldChoice>[
        ZFieldChoice(value: 'ne', label: 'Niger'),
        ZFieldChoice(value: 'fr', label: 'France'),
        ZFieldChoice(value: 'ca', label: 'Canada'),
      ],
    ),
    ZFieldSpec(
      name: 'gender',
      type: EditionFieldType.radio,
      label: 'Genre',
      choices: <ZFieldChoice>[
        ZFieldChoice(value: 'f', label: 'Femme'),
        ZFieldChoice(value: 'm', label: 'Homme'),
        ZFieldChoice(value: 'x', label: 'Autre'),
      ],
    ),
    ZFieldSpec(
      name: 'manager',
      type: EditionFieldType.relation,
      label: 'Responsable',
      choices: <ZFieldChoice>[
        ZFieldChoice(value: 'u1', label: 'A. Diallo'),
        ZFieldChoice(value: 'u2', label: 'B. Moussa'),
      ],
    ),
    ZFieldSpec(
      name: 'department',
      type: EditionFieldType.relation,
      label: 'Département',
      choices: <ZFieldChoice>[
        ZFieldChoice(value: 'd1', label: 'Douane'),
        ZFieldChoice(value: 'd2', label: 'Finances'),
      ],
    ),
    ZFieldSpec(name: 'skills', type: EditionFieldType.tags, label: 'Compétences'),
    ZFieldSpec(
      name: 'interests',
      type: EditionFieldType.rowChips,
      label: 'Centres d\'intérêt',
      choices: <ZFieldChoice>[
        ZFieldChoice(value: 'sport', label: 'Sport'),
        ZFieldChoice(value: 'musique', label: 'Musique'),
        ZFieldChoice(value: 'lecture', label: 'Lecture'),
      ],
    ),
    ZFieldSpec(name: 'languages', type: EditionFieldType.tags, label: 'Langues'),
    ZFieldSpec(
      name: 'priority',
      type: EditionFieldType.select,
      label: 'Priorité',
      choices: <ZFieldChoice>[
        ZFieldChoice(value: 'low', label: 'Basse'),
        ZFieldChoice(value: 'high', label: 'Haute'),
      ],
    ),
    ZFieldSpec(
      name: 'satisfaction',
      type: EditionFieldType.rating,
      label: 'Satisfaction',
      config: ZRatingConfig(max: 5),
    ),
    ZFieldSpec(
      name: 'volume',
      type: EditionFieldType.slider,
      label: 'Volume',
      config: ZSliderConfig(max: 100, divisions: 10),
    ),
    ZFieldSpec(
      name: 'favoriteColor',
      type: EditionFieldType.color,
      label: 'Couleur préférée',
    ),
    // Champ CONDITIONNEL : visible seulement si `active` est vrai (AC5-b).
    ZFieldSpec(
      name: 'premiumCode',
      type: EditionFieldType.text,
      label: 'Code premium',
      condition: ZCondition.truthy('active'),
    ),
  ];

  /// Champs de la section « Chiffres ».
  static const List<ZFieldSpec> _figures = <ZFieldSpec>[
    ZFieldSpec(name: 'quantity', type: EditionFieldType.integer, label: 'Quantité'),
    ZFieldSpec(
      name: 'unitPrice',
      type: EditionFieldType.number,
      label: 'Prix unitaire',
      config: ZNumberConfig(isCurrency: true),
    ),
    ZFieldSpec(name: 'discount', type: EditionFieldType.float, label: 'Remise'),
    ZFieldSpec(
      name: 'notes',
      type: EditionFieldType.multiline,
      label: 'Notes',
      config: ZTextConfig(minLines: 2, maxLines: 3),
    ),
  ];

  /// Champs de la section « Documents & signature ».
  static const List<ZFieldSpec> _documents = <ZFieldSpec>[
    ZFieldSpec(name: 'avatar', type: EditionFieldType.image, label: 'Avatar'),
    ZFieldSpec(
      name: 'idScan',
      type: EditionFieldType.document,
      label: 'Pièce d\'identité',
    ),
    ZFieldSpec(
      name: 'attachment',
      type: EditionFieldType.file,
      label: 'Pièce jointe',
    ),
    ZFieldSpec(
      name: 'signature',
      type: EditionFieldType.signature,
      label: 'Signature',
    ),
  ];

  /// Champs de la section « Lignes de commande » (sous-liste inline `subItems`).
  static const List<ZFieldSpec> _lines = <ZFieldSpec>[
    ZFieldSpec(
      name: 'orderLines',
      type: EditionFieldType.subItems,
      label: 'Lignes de commande',
      config: ZSubListConfig(
        itemFields: <ZFieldSpec>[
          ZFieldSpec(
            name: 'designation',
            type: EditionFieldType.text,
            label: 'Désignation',
          ),
          ZFieldSpec(name: 'qty', type: EditionFieldType.integer, label: 'Qté'),
          ZFieldSpec(
            name: 'linePrice',
            type: EditionFieldType.number,
            label: 'Prix',
          ),
        ],
      ),
    ),
    ZFieldSpec(
      name: 'acceptTerms',
      type: EditionFieldType.boolean,
      label: 'J\'accepte les conditions',
      validators: <ZValidatorSpec>[ZValidatorSpec.required()],
    ),
  ];

  /// Ensemble PLAT des champs de référence (34 champs), dans l'ordre canonique.
  static const List<ZFieldSpec> fields = <ZFieldSpec>[
    ..._identity,
    ..._preferences,
    ..._figures,
    ..._documents,
    ..._lines,
  ];

  /// Sections repliables (AC5-a) pour le mode plat [DynamicEdition].
  static const List<ZEditionSection> sections = <ZEditionSection>[
    ZEditionSection(
      title: 'Identité',
      fields: <String>[
        'fullName', 'nickname', 'bio', 'email', 'website', 'age', 'heightCm',
        'ratio', 'birthDate', 'wakeTime', 'active', 'newsletter',
      ],
    ),
    ZEditionSection(
      title: 'Préférences',
      collapsible: true,
      fields: <String>[
        'country', 'gender', 'manager', 'department', 'skills', 'interests',
        'languages', 'priority', 'satisfaction', 'volume', 'favoriteColor',
        'premiumCode',
      ],
    ),
    ZEditionSection(
      title: 'Chiffres',
      collapsible: true,
      initiallyExpanded: false,
      fields: <String>['quantity', 'unitPrice', 'discount', 'notes'],
    ),
    ZEditionSection(
      title: 'Documents & signature',
      collapsible: true,
      fields: <String>['avatar', 'idScan', 'attachment', 'signature'],
    ),
    ZEditionSection(
      title: 'Lignes de commande',
      collapsible: true,
      fields: <String>['orderLines', 'acceptTerms'],
    ),
  ];

  /// Grille responsive 12 colonnes (AC5-c) : quelques champs en demi/tiers de
  /// largeur selon le breakpoint.
  static const Map<String, ZResponsiveSpan> layout = <String, ZResponsiveSpan>{
    'age': ZResponsiveSpan(xs: 12, sm: 4),
    'heightCm': ZResponsiveSpan(xs: 12, sm: 4),
    'ratio': ZResponsiveSpan(xs: 12, sm: 4),
    'birthDate': ZResponsiveSpan(xs: 12, sm: 6),
    'wakeTime': ZResponsiveSpan(xs: 12, sm: 6),
    'quantity': ZResponsiveSpan(xs: 12, sm: 4),
    'unitPrice': ZResponsiveSpan(xs: 12, sm: 4),
    'discount': ZResponsiveSpan(xs: 12, sm: 4),
  };

  /// Découpage en étapes pour la variante [ZStepperEdition] (AC5-d) — MÊMES
  /// champs, MÊME contrôleur, validation par étape.
  static const List<ZEditionStep> steps = <ZEditionStep>[
    ZEditionStep(
      title: 'Identité',
      fields: <String>[
        'fullName', 'nickname', 'bio', 'email', 'website', 'age', 'heightCm',
        'ratio', 'birthDate', 'wakeTime', 'active', 'newsletter',
      ],
    ),
    ZEditionStep(
      title: 'Préférences',
      fields: <String>[
        'country', 'gender', 'manager', 'department', 'skills', 'interests',
        'languages', 'priority', 'satisfaction', 'volume', 'favoriteColor',
        'premiumCode',
      ],
    ),
    ZEditionStep(
      title: 'Documents & lignes',
      fields: <String>[
        'quantity', 'unitPrice', 'discount', 'notes', 'avatar', 'idScan',
        'attachment', 'signature', 'orderLines', 'acceptTerms',
      ],
    ),
  ];

  /// Valeurs initiales (une entrée par champ → crée toutes les tranches et fixe
  /// `visibleFields` en ordre canonique). Défauts sûrs par famille.
  static Map<String, Object?> initialValues() => <String, Object?>{
        for (final f in fields) f.name: _defaultFor(f),
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
        return const <Object?>[];
      default:
        return null;
    }
  }
}
