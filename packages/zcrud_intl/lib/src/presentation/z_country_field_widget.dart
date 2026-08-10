/// `ZCountryFieldWidget` — **champ d'édition pays** (`country`), servi via
/// `ZWidgetRegistry` (E11a-2, AD-2/AD-4/AD-13).
///
/// origine: le dispatcher du cœur (`ZFieldWidget`) route `country` vers le
/// `ZWidgetRegistry` injecté et appelle le builder **dans** la frontière de
/// rebuild de la tranche. Ce champ émet la **valeur de tranche neutre = code ISO
/// alpha-2 `String` opaque** (jamais un modèle enrichi, jamais un type de lib).
///
/// **CR-DODLP-INTL-DECORATION (2026-08-10) — DÉCORATION THÉMÉE DU CŒUR.**
///
/// Le déclencheur du sélecteur est désormais rendu **dans** la décoration du
/// cœur (`zFieldDecoration` → `ZcrudTheme.inputDecoration`), comme le `select`
/// et comme `ZDecoratedFieldTrigger` : cadre/fond/rayon/padding pilotés par les
/// jetons **existants**, libellé flottant enrichi unique. Sont retirés :
///  * le `Text(resolvedLabel)` externe (le nœud sémantique annonçait
///    « Téléphone / Téléphone » puis, sur le déclencheur, « Téléphone ») ;
///  * le `Padding(ZcrudTheme.fieldPadding)` (mesuré : 24 dp de largeur en moins
///    par rapport aux champs voisins du cœur).
/// En `fieldSize == large` (mode `bare`), le libellé est porté par
/// `ZLargeFieldCard` et n'est **ni rendu ni annoncé** par le champ — parité
/// mesurée avec le `select` du cœur.
///
/// **AD-2** : le sélecteur inline ([ZCountryPickerField]) possède un contrôleur/
/// focus de recherche stables (créés 1× en `initState`, disposés) ; aucune
/// reconstruction globale. Le catalogue immuable est **capturé par closure** dans
/// [builder] (aucun slot ajouté à `zcrud_core`, AD-4).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../data/z_country_catalog.dart';
import '../domain/z_country_info.dart';
import '../domain/z_intl_field_config.dart';
import 'z_country_picker_field.dart';

/// Champ d'édition pays (émet un code ISO `String`).
class ZCountryFieldWidget extends StatefulWidget {
  /// Construit le champ pour [ctx]. [catalog] fournit la liste des pays
  /// (injecté par closure de [builder]).
  const ZCountryFieldWidget({
    required this.ctx,
    required this.catalog,
    this.onInit,
    this.onBuild,
    this.openController,
    super.key,
  });

  /// Contexte du champ servi par le registre (`ctx.value` = code ISO courant,
  /// `ctx.onChanged` = écriture de la tranche).
  final ZFieldWidgetContext ctx;

  /// Catalogue pays (paresseux + caché) capturé par closure (AD-4).
  final ZCountryCatalog catalog;

  /// Hook de test : appelé UNE FOIS en `initState` (preuve SM-1).
  @visibleForTesting
  final VoidCallback? onInit;

  /// Hook de test : appelé à chaque (re)build (compteur ciblé SM-1).
  @visibleForTesting
  final VoidCallback? onBuild;

  /// Commande **optionnelle** du déploiement du sélecteur depuis l'hôte (AD-4).
  ///
  /// `null` ⇒ comportement **strictement inchangé**. Fourni ⇒ il devient la
  /// **source de vérité** de l'ouverture : l'hôte peut déplier le sélecteur
  /// (retour de validation pointant ce champ, bouton « choisir » placé ailleurs,
  /// restauration d'état) **et** le replier (navigation).
  ///
  /// ⚠️ Doit être possédé **hors `build`** (`ZDisplayStateOwnerMixin`) et
  /// **propre à ce montage** : c'est pourquoi il n'est PAS exposé par
  /// `builder()`, qui sert *toutes* les instances du même `kind` et partagerait
  /// donc un unique contrôleur entre plusieurs champs.
  final ZToggleController? openController;

  /// Fabrique un [ZFieldWidgetBuilder] enregistrable sous le `kind` `"country"`.
  /// Le [catalog] est **capturé par closure** (immuable, partageable — ce n'est
  /// PAS une ressource disposable) ; chaque montage crée en revanche SON propre
  /// contrôleur de recherche (par-montage, learning MAJEUR-1 E11a-1). Exemple :
  /// `registry.register('country', ZCountryFieldWidget.builder(catalog: cat))`.
  static ZFieldWidgetBuilder builder({
    ZCountryCatalog? catalog,
    VoidCallback? onInit,
    VoidCallback? onBuild,
  }) {
    // LOW-1 : sans `catalog` injecté, partage l'instance par défaut lazy pour
    // que les 3 kinds intl ne lisent l'asset qu'une seule fois (au lieu de 3).
    final cat = catalog ?? sharedDefaultCountryCatalog();
    return (BuildContext context, ZFieldWidgetContext ctx) => ZCountryFieldWidget(
          ctx: ctx,
          catalog: cat,
          onInit: onInit,
          onBuild: onBuild,
        );
  }

  @override
  State<ZCountryFieldWidget> createState() => _ZCountryFieldWidgetState();
}

class _ZCountryFieldWidgetState extends State<ZCountryFieldWidget> {
  @override
  void initState() {
    super.initState();
    widget.onInit?.call();
  }

  /// Config additive intl du champ (`null` → chemin E11a-2, rétro-compat).
  ZIntlFieldConfig? get _config {
    final c = widget.ctx.field.config;
    return c is ZIntlFieldConfig ? c : null;
  }

  /// Lecture défensive (AD-10) : la tranche `country` est un code ISO `String` ;
  /// tout autre type → `null`. AC1 (E11b-2) : si aucune valeur et un défaut de
  /// config est posé, il **amorce l'affichage** (non émis tant que l'utilisateur
  /// n'agit pas). Rétro-compat E11a-2 STRICTE : `config == null` + valeur `null`
  /// → `null` (placeholder, chemin identique).
  String? get _selectedIso {
    final v = widget.ctx.value;
    if (v is String && v.isNotEmpty) return v;
    final def = _config?.defaultCountryIso;
    return (def != null && def.isNotEmpty) ? def : null;
  }

  /// Rendu `bare` — dérivé de la spec **exactement comme le dispatcher du cœur**
  /// et `ZDecoratedFieldTrigger` (`fieldSize == large`).
  bool get _bare => widget.ctx.field.fieldSize == ZFieldSize.large;

  @override
  Widget build(BuildContext context) {
    widget.onBuild?.call();
    final field = widget.ctx.field;
    final resolvedLabel = label(
      context,
      field.label ?? field.name,
      fallback: field.label ?? field.name,
    );
    // CR-DODLP-INTL-DECORATION : décoration THÉMÉE du cœur (même chaîne que
    // `select`). Le libellé externe `Text` et le `Padding(fieldPadding)` sont
    // retirés — cf. dartdoc de bibliothèque.
    return ZCountryPickerField(
      catalog: widget.catalog,
      selectedIso: _selectedIso,
      readOnly: field.readOnly,
      preferredIsos: _config?.preferredCountryIsos ?? const <String>[],
      searchable: _config?.searchable ?? true,
      semanticLabel: resolvedLabel,
      openController: widget.openController,
      decoration: zFieldDecoration(context, field, bare: _bare),
      onSelected: (ZCountryInfo c) =>
          // Voie unique (AD-2) : émet le CODE ISO string neutre.
          widget.ctx.onChanged(c.isoCode),
    );
  }
}
