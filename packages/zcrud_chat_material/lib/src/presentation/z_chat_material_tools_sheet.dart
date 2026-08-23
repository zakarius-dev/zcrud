/// La **feuille d'outils Material** — l'assemblage des tuiles.
///
/// La feuille est construite à partir de la structure que le domaine résout :
/// des sections **déjà ordonnées**, **déjà purgées** de celles qui n'ont plus
/// d'entrée visible. Elle les rend par un `ListView.builder` et pose un
/// séparateur **entre** deux sections. Aucun index n'y a de signification
/// particulière : ajouter un outil ne demande de toucher ni un aiguillage ni
/// un compteur.
///
/// De haut en bas :
///
/// 1. l'**en-tête** — titre, badge du comptage agrégé, remise à zéro, et la
///    fermeture quand l'hôte en fournit une ;
/// 2. les **outils actifs**, en puces retirables : la feuille s'ouvre sur ce
///    qui est activé, au lieu de le faire chercher ;
/// 3. la **recherche**, proposée seulement quand le catalogue est assez large
///    pour qu'elle serve et que l'hôte en a nommé l'invite ;
/// 4. les **sections** et leurs tuiles.
///
/// La hauteur est **négociable** : la feuille s'ouvre à une fraction de la
/// hauteur disponible et se replie ou se déplie au doigt
/// ([ZChatToolSheetReference]).
///
/// ## Ce que la feuille ne décide pas
///
/// Ni la visibilité, ni le grisage, ni l'ordre, ni le comptage, ni la liste
/// des actifs, ni le filtre de recherche : tout cela est résolu par le
/// domaine, publié par `ZChatToolController`, et seulement rendu ici. Une
/// seconde implémentation divergerait de la première.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_chat/zcrud_chat.dart';

import 'z_chat_material_badge.dart';
import 'z_chat_material_tool_labels.dart';
import 'z_chat_material_tool_tile.dart';

/// La feuille d'outils, rendue en Material.
class ZChatMaterialToolsSheet extends StatelessWidget {
  /// Construit la feuille.
  const ZChatMaterialToolsSheet({
    required this.controller,
    this.labels = const ZChatMaterialToolLabels(),
    this.kindBuilders = const <String, ZChatMaterialToolTileBuilder>{},
    this.unknownBuilder,
    this.onClose,
    this.onCommand,
    this.draggable = true,
    super.key,
  });

  /// Le contrôleur d'outils.
  final ZChatToolController controller;

  /// Les canaux de libellé et de glyphe de l'hôte.
  final ZChatMaterialToolLabels labels;

  /// Rendus d'hôte par `kind`.
  final Map<String, ZChatMaterialToolTileBuilder> kindBuilders;

  /// Rendu d'une nature que personne ne sait rendre.
  final ZChatMaterialToolTileBuilder? unknownBuilder;

  /// Fermeture de la feuille. `null` ⇒ **aucune affordance de fermeture** —
  /// c'est l'hôte qui sait comment sa feuille est présentée.
  final VoidCallback? onClose;

  /// Geste d'une action ponctuelle.
  final void Function(String key)? onCommand;

  /// `false` rend la feuille à la hauteur que son parent lui donne, sans
  /// poignée de redimensionnement.
  final bool draggable;

  @override
  Widget build(BuildContext context) {
    if (!draggable) return _content(context, null);
    return DraggableScrollableSheet(
      initialChildSize: ZChatToolSheetReference.sheetInitialSize,
      minChildSize: ZChatToolSheetReference.sheetMinSize,
      maxChildSize: ZChatToolSheetReference.sheetMaxSize,
      expand: false,
      builder: (BuildContext context, ScrollController scroll) =>
          _content(context, scroll),
    );
  }

  Widget _content(BuildContext context, ScrollController? scroll) => Padding(
        padding: const EdgeInsetsDirectional.all(
          ZChatToolSheetReference.sheetPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _header(context),
            _activeHeader(context),
            _search(context),
            Expanded(child: _sections(context, scroll)),
          ],
        ),
      );

  Widget _header(BuildContext context) {
    final String title =
        labels.title ?? zChatLabel(context, kZChatLabelTools);
    final String reset =
        labels.reset ?? zChatLabel(context, kZChatLabelSettingsReset);
    final String close =
        labels.close ?? zChatLabel(context, kZChatLabelSettingsClose);
    return Row(
      children: <Widget>[
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, textAlign: TextAlign.start),
          ),
        ),
        ZChatMaterialToolCatalogBadge(controller: controller),
        TextButton(onPressed: controller.reset, child: Text(reset)),
        if (onClose != null)
          IconButton(
            onPressed: onClose,
            tooltip: close,
            icon: const Icon(Icons.close),
          ),
      ],
    );
  }

  /// Les outils actifs, en puces retirables. Retirer une puce ramène l'outil à
  /// sa forme inactive — le même geste que la tuile elle-même, jamais un
  /// second chemin d'écriture.
  Widget _activeHeader(BuildContext context) {
    final String? title = labels.active;
    if (title == null) return const SizedBox.shrink();
    // Abonné à la seule tranche du comptage : régler un outil qui n'entre ni
    // ne sort de la liste ne reconstruit pas cet en-tête.
    return ValueListenableBuilder<List<String>>(
      valueListenable: controller.activeKeys,
      builder: (BuildContext context, List<String> keys, Widget? _) {
        if (keys.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(title, textAlign: TextAlign.start),
            ),
            Wrap(
              spacing: ZChatToolSheetReference.chipGap,
              runSpacing: ZChatToolSheetReference.chipGap,
              children: <Widget>[
                for (final String key in keys) ?_activeChip(context, key),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget? _activeChip(BuildContext context, String key) {
    final String? label = controller.catalog.entry(key)?.label;
    if (label == null) return null;
    return InputChip(
      label: Text(label),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      onDeleted: () => controller.clearEntry(key),
    );
  }

  Widget _search(BuildContext context) {
    final String? hint = labels.search;
    if (hint == null || !controller.searchRecommended) {
      return const SizedBox.shrink();
    }
    return _ZChatMaterialToolSearchField(controller: controller, hint: hint);
  }

  Widget _sections(BuildContext context, ScrollController? scroll) =>
      ValueListenableBuilder<ZChatToolSheetStructure>(
        valueListenable: controller.sheetStructure,
        builder: (
          BuildContext context,
          ZChatToolSheetStructure structure,
          Widget? _,
        ) => ListView.builder(
          controller: scroll,
          itemCount: structure.sections.length,
          itemBuilder: (BuildContext context, int index) => _section(
            context,
            structure.sections[index],
            // Le séparateur s'insère ENTRE deux sections : il appartient à la
            // section qui suit, jamais à une position magique de la liste.
            separated: index > 0,
          ),
        ),
      );

  Widget _section(
    BuildContext context,
    ZChatToolSectionSlice slice, {
    required bool separated,
  }) {
    final String? label = slice.label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (separated)
          const Divider(indent: ZChatToolSheetReference.dividerIndent),
        // Une section que l'hôte n'a pas nommée n'a pas d'en-tête : le socle
        // n'invente pas de titre.
        if (label != null)
          Semantics(
            header: true,
            child: Text(label, textAlign: TextAlign.start),
          ),
        for (final String key in slice.entryKeys)
          ZChatMaterialToolTile(
            key: ValueKey<String>(key),
            controller: controller,
            toolKey: key,
            labels: labels,
            kindBuilders: kindBuilders,
            unknownBuilder: unknownBuilder,
            onCommand: onCommand,
          ),
      ],
    );
  }
}

/// La barre de recherche : elle écrit dans le contrôleur, qui refiltre la
/// structure. Le champ ne garde aucun état de rendu à lui.
class _ZChatMaterialToolSearchField extends StatefulWidget {
  const _ZChatMaterialToolSearchField({
    required this.controller,
    required this.hint,
  });

  final ZChatToolController controller;
  final String hint;

  @override
  State<_ZChatMaterialToolSearchField> createState() =>
      _ZChatMaterialToolSearchFieldState();
}

class _ZChatMaterialToolSearchFieldState
    extends State<_ZChatMaterialToolSearchField> {
  // Le champ possède son `TextEditingController` et ne le recrée JAMAIS au
  // rebuild (invariant AD-2, symptôme historique : la perte de sélection).
  late final TextEditingController _text = TextEditingController(
    text: widget.controller.query.value,
  )..addListener(_publish);

  void _publish() => widget.controller.setQuery(_text.text);

  @override
  void dispose() {
    _text
      ..removeListener(_publish)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kZChatMinTapTarget),
        child: TextField(
          controller: _text,
          textAlign: TextAlign.start,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: const Icon(Icons.search),
          ),
        ),
      );
}
