/// La **feuille de réglages Material** — l'assemblage par défaut des neuf
/// builders de ce satellite sur la feuille du socle (`ZChatSettingsSheet`).
///
/// Ce n'est pas une feuille parallèle : c'est `ZChatSettingsSheet` elle-même,
/// avec ses neuf créneaux remplis par les builders Material. La structure
/// (ordre des familles, sections, entrées d'hôte, règle des trois cas) reste
/// celle du socle ; ce widget ne fait que poser des défauts.
///
/// ## Ce que l'hôte fournit
///
/// * ses **libellés** ([ZChatMaterialSettingsLabels]) — un canal absent
///   retire l'affordance, il ne la remplace jamais par un texte du socle ;
/// * ses **catalogues** (corpus, capacités, préréglages) ;
/// * le geste de **fermeture** ([onClose]) — sans lui, aucun en-tête ;
/// * ses **sections titrées** ([sections]) : un titre de section du socle est
///   rendu hiérarchisé, avec un séparateur entre deux sections.
///
/// Rien d'autre n'est nécessaire : un hôte qui ne passe que son contrôleur
/// obtient la feuille riche. Chaque builder reste **remplaçable** par son
/// paramètre nommé — le builder de l'hôte gagne toujours sur le défaut
/// Material, et rendre `null` retire la tuile (invariant AD-4).
///
/// ## Un seul état par réglage
///
/// Les familles standard lisent et écrivent `ZChatSettingsController`, et
/// rien d'autre. Un hôte n'a pas à redéclarer sa verbosité, son budget ou ses
/// corpus dans un catalogue d'outils pour obtenir une feuille riche : il
/// obtiendrait deux états pour un même réglage, dont un seul partirait dans
/// la requête.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_chat/zcrud_chat.dart';

import 'z_chat_material_budget_slider.dart';
import 'z_chat_material_corpus_chips.dart';
import 'z_chat_material_settings_chips.dart';
import 'z_chat_material_settings_header.dart';
import 'z_chat_material_settings_labels.dart';
import 'z_chat_material_settings_reference.dart';
import 'z_chat_material_settings_switches.dart';

/// Builder prêt-à-brancher sur `ZChatSettingsSheet.unknownEntryBuilder`.
ZChatSettingsEntryTileBuilder zChatMaterialUnknownEntryTile() =>
    (BuildContext context, ZChatSettingsSlot slot, ZChatSettingsEntry entry) =>
        ZChatMaterialUnknownEntryTile(entry: entry);

/// Le repli d'une entrée dont le kind n'a aucun rendu : son titre et son
/// sous-titre, inertes — rien n'est inventé pour un contrôle inconnu.
class ZChatMaterialUnknownEntryTile extends StatelessWidget {
  /// Construit le repli.
  const ZChatMaterialUnknownEntryTile({required this.entry, super.key});

  /// L'entrée sans rendu.
  final ZChatSettingsEntry entry;

  @override
  Widget build(BuildContext context) {
    final ZChatSettingsLabel? subtitle = entry.subtitle;
    return ListTile(
      enabled: false,
      leading: entry.icon,
      title: Text(
        zChatMaterialSettingsLabelText(context, entry.title),
        textAlign: TextAlign.start,
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              zChatMaterialSettingsLabelText(context, subtitle),
              textAlign: TextAlign.start,
            ),
    );
  }
}

/// La feuille de réglages du socle, neuf créneaux remplis en Material.
class ZChatMaterialSettingsSheet extends StatelessWidget {
  /// Construit la feuille.
  const ZChatMaterialSettingsSheet({
    required this.controller,
    this.labels = const ZChatMaterialSettingsLabels(),
    this.onClose,
    this.corpusCatalog = const <ZChatCorpusOption>[],
    this.presetCatalog = const <ZChatSettingsPreset>[],
    this.capabilityCatalog = const <ZChatSettingsHostOption>[],
    this.entries = const <ZChatSettingsEntry>[],
    this.sections = const <ZChatSettingsSection>[],
    this.headerBuilder,
    this.presetsBuilder,
    this.responseLengthBuilder,
    this.lengthBiasBuilder,
    this.computeBudgetBuilder,
    this.revealThinkingBuilder,
    this.capabilitiesBuilder,
    this.corpusBuilder,
    this.unknownEntryBuilder,
    this.entryBuilders = const <String, ZChatSettingsEntryTileBuilder>{},
    this.kindBuilders = const <String, ZChatSettingsEntryTileBuilder>{},
    this.sectionBuilders = const <String, ZChatSettingsTileBuilder>{},
    this.padding,
    this.spacing,
    super.key,
  });

  /// Le contrôleur de réglages — ni créé ni disposé ici.
  final ZChatSettingsController controller;

  /// Les canaux de libellé et de glyphe de l'hôte.
  final ZChatMaterialSettingsLabels labels;

  /// Ferme la feuille. `null` ⇒ aucun en-tête (le conteneur appartient à
  /// l'hôte, donc la fermeture aussi).
  final VoidCallback? onClose;

  /// Catalogue de corpus de l'hôte. Vide ⇒ tuile de portée absente.
  final List<ZChatCorpusOption> corpusCatalog;

  /// Préréglages de l'hôte. Vide ⇒ tuile de préréglages absente.
  final List<ZChatSettingsPreset> presetCatalog;

  /// Capacités supplémentaires de l'hôte, après la recherche web.
  final List<ZChatSettingsHostOption> capabilityCatalog;

  /// Entrées déclaratives de l'hôte — même contrat que sur le socle.
  final List<ZChatSettingsEntry> entries;

  /// Sections déclarées par l'hôte. Les deux sections du socle y reçoivent
  /// leur titre Material ; les sections d'hôte sont transmises au socle.
  final List<ZChatSettingsSection> sections;

  /// Remplace l'en-tête Material. Règle des trois cas.
  final ZChatSettingsTileBuilder? headerBuilder;

  /// Remplace les préréglages Material.
  final ZChatSettingsTileBuilder? presetsBuilder;

  /// Remplace la verbosité Material.
  final ZChatSettingsTileBuilder? responseLengthBuilder;

  /// Remplace le biais de régénération Material.
  final ZChatSettingsTileBuilder? lengthBiasBuilder;

  /// Remplace le curseur de budget Material.
  final ZChatSettingsTileBuilder? computeBudgetBuilder;

  /// Remplace la bascule de raisonnement Material.
  final ZChatSettingsTileBuilder? revealThinkingBuilder;

  /// Remplace les bascules de capacité Material.
  final ZChatSettingsTileBuilder? capabilitiesBuilder;

  /// Remplace les puces de portée documentaire Material.
  final ZChatSettingsTileBuilder? corpusBuilder;

  /// Remplace le repli Material d'une entrée sans rendu.
  final ZChatSettingsEntryTileBuilder? unknownEntryBuilder;

  /// Builders par entrée — transmis au socle.
  final Map<String, ZChatSettingsEntryTileBuilder> entryBuilders;

  /// Builders par kind — transmis au socle.
  final Map<String, ZChatSettingsEntryTileBuilder> kindBuilders;

  /// Builders par section — transmis au socle.
  final Map<String, ZChatSettingsTileBuilder> sectionBuilders;

  /// Marge directionnelle — transmise au socle.
  final EdgeInsetsDirectional? padding;

  /// Interligne — transmis au socle.
  final double? spacing;

  @override
  Widget build(BuildContext context) {
    // Le socle n'expose pas de créneau pour le SEUL en-tête d'une section (le
    // bloc entier, oui — mais le remplacer perdrait les entrées d'hôte de la
    // section). Le titre Material est donc posé au-dessus de la PREMIÈRE
    // tuile rendue de la section, et le suivi « déjà posé » est remis à zéro
    // par le builder d'en-tête — que le socle appelle en premier à chaque
    // construction de son corps.
    final _ZChatMaterialSectionTitles titles = _ZChatMaterialSectionTitles();
    final ZChatSettingsTileBuilder header =
        headerBuilder ??
        zChatMaterialSettingsHeader(labels: labels, onClose: onClose);
    return ZChatSettingsSheet(
      controller: controller,
      onClose: onClose,
      corpusCatalog: corpusCatalog,
      presetCatalog: presetCatalog,
      capabilityCatalog: capabilityCatalog,
      entries: entries,
      // Les sections du socle lui sont transmises SANS titre : il ne rend
      // pas l'en-tête nu, le titre Material le remplace.
      sections: <ZChatSettingsSection>[
        for (final ZChatSettingsSection s in sections)
          _isSocleSection(s.id) ? ZChatSettingsSection(id: s.id) : s,
      ],
      headerBuilder: (BuildContext context, ZChatSettingsSlot slot) {
        titles.reset();
        return header(context, slot);
      },
      presetsBuilder: presetsBuilder ?? zChatMaterialPresetChips(),
      responseLengthBuilder: titles.wrap(
        kZChatSettingsSectionGeneration,
        _titleOf(context, kZChatSettingsSectionGeneration),
        responseLengthBuilder ?? zChatMaterialResponseLengthChips(),
      ),
      lengthBiasBuilder: titles.wrap(
        kZChatSettingsSectionGeneration,
        _titleOf(context, kZChatSettingsSectionGeneration),
        lengthBiasBuilder ?? zChatMaterialLengthBiasChips(),
      ),
      computeBudgetBuilder: titles.wrap(
        kZChatSettingsSectionGeneration,
        _titleOf(context, kZChatSettingsSectionGeneration),
        computeBudgetBuilder ?? zChatMaterialBudgetSlider(),
      ),
      revealThinkingBuilder: titles.wrap(
        kZChatSettingsSectionGeneration,
        _titleOf(context, kZChatSettingsSectionGeneration),
        revealThinkingBuilder ?? zChatMaterialRevealThinkingTile(labels: labels),
      ),
      capabilitiesBuilder:
          capabilitiesBuilder ?? zChatMaterialCapabilityTiles(labels: labels),
      corpusBuilder: titles.wrap(
        kZChatSettingsSectionCorpus,
        _titleOf(context, kZChatSettingsSectionCorpus),
        corpusBuilder ?? zChatMaterialCorpusChips(labels: labels),
        separated: true,
      ),
      unknownEntryBuilder: unknownEntryBuilder ?? zChatMaterialUnknownEntryTile(),
      entryBuilders: entryBuilders,
      kindBuilders: kindBuilders,
      sectionBuilders: sectionBuilders,
      padding: padding,
      spacing: spacing,
    );
  }

  static bool _isSocleSection(String id) =>
      id == kZChatSettingsSectionGeneration || id == kZChatSettingsSectionCorpus;

  /// Le titre résolu d'une section du socle, `null` si l'hôte ne l'a pas
  /// déclarée avec un titre.
  String? _titleOf(BuildContext context, String id) {
    for (final ZChatSettingsSection s in sections) {
      if (s.id == id) {
        final ZChatSettingsLabel? title = s.title;
        return title == null
            ? null
            : zChatMaterialSettingsLabelText(context, title);
      }
    }
    return null;
  }
}

/// Suivi « titre déjà posé » par section, pour une construction du corps.
class _ZChatMaterialSectionTitles {
  final Set<String> _placed = <String>{};

  void reset() => _placed.clear();

  /// Enveloppe [builder] : la première tuile non nulle de la section [id]
  /// reçoit le titre (et le séparateur, si [separated]) au-dessus d'elle.
  ZChatSettingsTileBuilder wrap(
    String id,
    String? title,
    ZChatSettingsTileBuilder builder, {
    bool separated = false,
  }) =>
      (BuildContext context, ZChatSettingsSlot slot) {
        final Widget? tile = builder(context, slot);
        if (tile == null) return null;
        if (!_placed.add(id)) return tile;
        if (title == null && !separated) return tile;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (title != null)
              ZChatMaterialSettingsSectionHeader(
                title: title,
                separated: separated,
              )
            else
              const Divider(
                indent: ZChatMaterialSettingsReference.dividerIndent,
              ),
            const SizedBox(height: ZChatMaterialSettingsReference.blockGap),
            tile,
          ],
        );
      };
}
