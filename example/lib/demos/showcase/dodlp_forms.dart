import 'package:zcrud_core/zcrud_core.dart';

import 'axis_harness.dart';

/// **Harnais 6 formulaires DODLP** (fp-3-2, AC5 — FR-39 / SM-3).
///
/// Chaque `AxisForm` réplique **la FORME** d'un formulaire fonctionnel DODLP réel
/// (LECTURE SEULE de `dodlp-otr`), un par axe de risque du `FIELD-PACKAGE-MATRIX`
/// §5.2, sur **données 100 % FICTIVES** (noms/valeurs inventés app-side, AUCUN
/// secret, AUCUN backend DODLP — AD-56/AR-6). Ces schémas `ZFieldSpec[]` pur-données
/// sont montés par le VRAI moteur (`DynamicEdition` → `ZFieldWidget`) via
/// [AxisFormScreen] (présence ≠ association — preuve de parité bout-en-bout).
///
/// **Note HTML (ET-5)** : les champs `html`/`inlineHtml` sont ici en **lecture**
/// (`readOnly: true` ⇒ `ZHtmlView`) pour être montables en `flutter test` headless
/// (la WebView WYSIWYG `html_editor_enhanced` n'est pas montable sans moteur —
/// l'édition WYSIWYG reste exercée au RUNTIME). Le reste du formulaire est éditable.
abstract final class DodlpForms {
  // ── Axe 1 — Cargaison (module `pia`) : dense texte/nombre/date + relation +
  //    subItems conteneurs. ────────────────────────────────────────────────
  static const AxisForm cargaison = AxisForm(
    id: 'dodlp-cargaison',
    title: 'DODLP · Cargaison (pia)',
    sections: <ZEditionSection>[
      ZEditionSection(title: 'Manifeste', fields: <String>[
        'blNumber', 'shipName', 'voyage', 'arrivalDate', 'consigneeRef',
      ]),
      ZEditionSection(title: 'Marchandise', collapsible: true, fields: <String>[
        'description', 'grossWeight', 'packagesCount', 'containers',
      ]),
    ],
    fields: <ZFieldSpec>[
      ZFieldSpec(name: 'blNumber', type: EditionFieldType.text, label: 'N° connaissement'),
      ZFieldSpec(name: 'shipName', type: EditionFieldType.text, label: 'Navire'),
      ZFieldSpec(name: 'voyage', type: EditionFieldType.text, label: 'Voyage'),
      ZFieldSpec(name: 'arrivalDate', type: EditionFieldType.dateTime, label: 'Arrivée'),
      ZFieldSpec(
        name: 'consigneeRef',
        type: EditionFieldType.relation,
        label: 'Consignataire',
        choices: <ZFieldChoice>[
          ZFieldChoice(value: 'c1', label: 'Sahel Transit (fictif)'),
          ZFieldChoice(value: 'c2', label: 'Ocean Lignes (fictif)'),
        ],
      ),
      ZFieldSpec(name: 'description', type: EditionFieldType.multiline, label: 'Désignation', config: ZTextConfig(minLines: 2, maxLines: 4)),
      ZFieldSpec(name: 'grossWeight', type: EditionFieldType.float, label: 'Poids brut (kg)'),
      ZFieldSpec(name: 'packagesCount', type: EditionFieldType.integer, label: 'Nb colis'),
      ZFieldSpec(
        name: 'containers',
        type: EditionFieldType.subItems,
        label: 'Conteneurs',
        config: ZSubListConfig(itemFields: <ZFieldSpec>[
          ZFieldSpec(name: 'number', type: EditionFieldType.text, label: 'N° TC'),
          ZFieldSpec(name: 'size', type: EditionFieldType.integer, label: 'Taille'),
        ]),
      ),
    ],
    initialValues: <String, Object?>{
      'blNumber': 'BL-FICTIF-0042',
      'shipName': 'MV Atlantique (fictif)',
      'voyage': 'V-2026-07',
      'arrivalDate': null,
      'consigneeRef': 'c1',
      'description': 'Fèves de cacao en sacs (données fictives)',
      'grossWeight': 18500.0,
      'packagesCount': 320,
      'containers': <Object?>[],
    },
  );

  // ── Axe 2 — DemandeDepotage (module `vido`) : select/relation + number +
  //    switch. ─────────────────────────────────────────────────────────────
  static const AxisForm demandeDepotage = AxisForm(
    id: 'dodlp-demande-depotage',
    title: 'DODLP · Demande de dépotage (vido)',
    fields: <ZFieldSpec>[
      ZFieldSpec(
        name: 'type',
        type: EditionFieldType.select,
        label: 'Type d\'évènement',
        choices: <ZFieldChoice>[
          ZFieldChoice(value: 'ouverture', label: 'Ouverture'),
          ZFieldChoice(value: 'depotage', label: 'Dépotage'),
          ZFieldChoice(value: 'cloture', label: 'Clôture'),
        ],
      ),
      ZFieldSpec(
        name: 'priority',
        type: EditionFieldType.radio,
        label: 'Priorité',
        choices: <ZFieldChoice>[
          ZFieldChoice(value: 'normal', label: 'Normale'),
          ZFieldChoice(value: 'urgent', label: 'Urgente'),
        ],
      ),
      ZFieldSpec(
        name: 'agent',
        type: EditionFieldType.relation,
        label: 'Agent assigné',
        choices: <ZFieldChoice>[
          ZFieldChoice(value: 'a1', label: 'K. Mensah (fictif)'),
          ZFieldChoice(value: 'a2', label: 'A. Diallo (fictif)'),
        ],
      ),
      ZFieldSpec(name: 'lotCount', type: EditionFieldType.integer, label: 'Nb de lots'),
      ZFieldSpec(name: 'motif', type: EditionFieldType.multiline, label: 'Motif', config: ZTextConfig(minLines: 2, maxLines: 3)),
      ZFieldSpec(name: 'validated', type: EditionFieldType.boolean, label: 'Validé chef division'),
    ],
    initialValues: <String, Object?>{
      'type': 'depotage',
      'priority': 'normal',
      'agent': 'a1',
      'lotCount': 4,
      'motif': 'Contrôle documentaire (fictif)',
      'validated': false,
    },
  );

  // ── Axe 3 — AuthProfile (module `auth`) : média (image/fichier) + texte. ───
  static const AxisForm authProfile = AxisForm(
    id: 'dodlp-auth-profile',
    title: 'DODLP · Profil agent (auth)',
    fields: <ZFieldSpec>[
      ZFieldSpec(name: 'fullName', type: EditionFieldType.text, label: 'Nom complet'),
      ZFieldSpec(name: 'matricule', type: EditionFieldType.text, label: 'Matricule'),
      ZFieldSpec(name: 'avatar', type: EditionFieldType.mediaImage, label: 'Photo de profil'),
      ZFieldSpec(name: 'idCard', type: EditionFieldType.mediaFile, label: 'Pièce d\'identité (fichier)'),
      ZFieldSpec(name: 'introVideo', type: EditionFieldType.mediaVideo, label: 'Vidéo de présentation'),
      ZFieldSpec(name: 'bio', type: EditionFieldType.multiline, label: 'Bio', config: ZTextConfig(minLines: 2, maxLines: 4)),
    ],
    initialValues: <String, Object?>{
      'fullName': 'Agent Fictif',
      'matricule': 'MAT-0007',
      'avatar': null,
      'idCard': null,
      'introVideo': null,
      'bio': 'Profil de démonstration (données fictives).',
    },
  );

  // ── Axe 4 — ArticleBep / Cotation (modules `sse`/`douanes_togolaises`) :
  //    number + select + markdown + html (lecture, ET-5). ──────────────────
  static const AxisForm articleCotation = AxisForm(
    id: 'dodlp-article-cotation',
    title: 'DODLP · Article & cotation (sse)',
    fields: <ZFieldSpec>[
      ZFieldSpec(name: 'hsCode', type: EditionFieldType.text, label: 'Position tarifaire'),
      ZFieldSpec(name: 'unitPrice', type: EditionFieldType.float, label: 'Prix unitaire'),
      ZFieldSpec(
        name: 'currency',
        type: EditionFieldType.select,
        label: 'Devise',
        choices: <ZFieldChoice>[
          ZFieldChoice(value: 'xof', label: 'XOF'),
          ZFieldChoice(value: 'eur', label: 'EUR'),
          ZFieldChoice(value: 'usd', label: 'USD'),
        ],
      ),
      ZFieldSpec(name: 'notes', type: EditionFieldType.markdown, label: 'Notes (markdown)'),
      ZFieldSpec(name: 'summaryInline', type: EditionFieldType.inlineMarkdown, label: 'Résumé (markdown inline)'),
      // ET-5 : lecture HTML (ZHtmlView) montable ; l'édition WYSIWYG est runtime.
      ZFieldSpec(name: 'legalHtml', type: EditionFieldType.html, label: 'Mention légale (HTML, lecture)', readOnly: true),
      ZFieldSpec(name: 'tagInline', type: EditionFieldType.inlineHtml, label: 'Étiquette (HTML inline, lecture)', readOnly: true),
    ],
    initialValues: <String, Object?>{
      'hsCode': '1801.00.00.00',
      'unitPrice': 1250.0,
      'currency': 'xof',
      'notes': '**Cotation** de démonstration (données fictives).',
      'summaryInline': '_Aperçu_ inline.',
      'legalHtml': '<p>Texte <b>légal</b> fictif.</p>',
      'tagInline': '<i>Fragile</i>',
    },
  );

  // ── Axe 5 — Consignee / BoatService (module `bmd`) : phone/country/address/
  //    location + switch + select. ──────────────────────────────────────────
  static const AxisForm consignee = AxisForm(
    id: 'dodlp-consignee',
    title: 'DODLP · Consignataire (bmd)',
    fields: <ZFieldSpec>[
      ZFieldSpec(name: 'name', type: EditionFieldType.text, label: 'Raison sociale'),
      ZFieldSpec(name: 'code', type: EditionFieldType.text, label: 'Code'),
      ZFieldSpec(name: 'phone', type: EditionFieldType.phoneNumber, label: 'Téléphone'),
      ZFieldSpec(name: 'country', type: EditionFieldType.country, label: 'Pays'),
      ZFieldSpec(name: 'address', type: EditionFieldType.address, label: 'Adresse'),
      ZFieldSpec(name: 'berth', type: EditionFieldType.location, label: 'Poste à quai (coords)'),
      ZFieldSpec(
        name: 'serviceType',
        type: EditionFieldType.select,
        label: 'Type de service',
        choices: <ZFieldChoice>[
          ZFieldChoice(value: 'towage', label: 'Remorquage'),
          ZFieldChoice(value: 'pilotage', label: 'Pilotage'),
        ],
      ),
      ZFieldSpec(name: 'isActive', type: EditionFieldType.boolean, label: 'Actif'),
    ],
    initialValues: <String, Object?>{
      'name': 'Consignataire Fictif SARL',
      'code': 'CNS-01',
      'phone': null,
      'country': null,
      'address': null,
      'berth': null,
      'serviceType': 'pilotage',
      'isActive': true,
    },
  );

  // ── Axe 6 — Convocation / Event (modules `bmd`/`workflow`) : dateTime +
  //    dateRange + relation + rating/slider/signature/subItems/color. ────────
  static const AxisForm convocation = AxisForm(
    id: 'dodlp-convocation',
    title: 'DODLP · Convocation & évènement (bmd)',
    fields: <ZFieldSpec>[
      ZFieldSpec(name: 'convocationNumber', type: EditionFieldType.text, label: 'N° convocation'),
      ZFieldSpec(name: 'scheduledDate', type: EditionFieldType.dateTime, label: 'Date programmée'),
      ZFieldSpec(name: 'window', type: EditionFieldType.dateRange, label: 'Fenêtre d\'intervention'),
      ZFieldSpec(
        name: 'boatService',
        type: EditionFieldType.relation,
        label: 'Service navire',
        choices: <ZFieldChoice>[
          ZFieldChoice(value: 's1', label: 'Escale 2026-07 (fictif)'),
        ],
      ),
      ZFieldSpec(name: 'severity', type: EditionFieldType.rating, label: 'Gravité', config: ZRatingConfig(max: 5)),
      ZFieldSpec(name: 'progress', type: EditionFieldType.slider, label: 'Avancement', config: ZSliderConfig(max: 100, divisions: 10)),
      ZFieldSpec(name: 'tagColor', type: EditionFieldType.color, label: 'Couleur d\'étiquette', config: ZColorConfig.multiple()),
      ZFieldSpec(name: 'signature', type: EditionFieldType.signature, label: 'Signature agent'),
      ZFieldSpec(
        name: 'actions',
        type: EditionFieldType.subItems,
        label: 'Actions menées',
        config: ZSubListConfig(itemFields: <ZFieldSpec>[
          ZFieldSpec(name: 'label', type: EditionFieldType.text, label: 'Action'),
          ZFieldSpec(name: 'done', type: EditionFieldType.boolean, label: 'Faite'),
        ]),
      ),
    ],
    initialValues: <String, Object?>{
      'convocationNumber': 'CV-FICTIF-11',
      'scheduledDate': null,
      'window': null,
      'boatService': 's1',
      'severity': 2,
      'progress': 30.0,
      'tagColor': <int>[],
      'signature': null,
      'actions': <Object?>[],
    },
  );
}
