/// Requête **neutre** de zone de dépôt NATIVE (AD-57).
///
/// « Natif » signifie ici : recevoir des données venues du **système** ou d'une
/// **autre application** — un fichier glissé depuis l'explorateur, une image
/// déposée depuis un navigateur. C'est une capacité **distincte** du
/// réordonnancement interne d'une collection (`ZReorderRenderer`), et les deux
/// ne doivent pas être confondues : les mélanger imposerait une chaîne de
/// compilation native à des hôtes qui veulent seulement réordonner.
///
/// Imports limités à `package:flutter/widgets.dart` : AUCUNE dépendance lourde
/// (garde `presentation_purity_test.dart`).
library;

import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// Nature d'une donnée déposée, exprimée **sans** vocabulaire de plateforme.
enum ZDropKind {
  /// Fichier (existant ou produit à la demande par la source).
  file,

  /// Texte brut.
  text,

  /// Adresse (URL, URI de ressource).
  uri,

  /// Image bitmap.
  image,

  /// Type non reconnu par le socle — l'hôte décide (AD-10 : jamais un rejet
  /// silencieux, jamais un throw).
  unknown,
}

/// Élément déposé, **neutre** : aucun type de plateforme ni de paquet tiers.
@immutable
class ZDroppedItem {
  /// Construit un élément déposé.
  const ZDroppedItem({
    required this.kind,
    this.name,
    this.mimeType,
    this.text,
    this.readBytes,
  });

  /// Nature de la donnée.
  final ZDropKind kind;

  /// Nom lisible (nom de fichier), si la source en fournit un.
  final String? name;

  /// Type MIME annoncé par la source, si connu.
  final String? mimeType;

  /// Contenu textuel, pour [ZDropKind.text] / [ZDropKind.uri].
  final String? text;

  /// Lecture **paresseuse** du contenu binaire.
  ///
  /// Volontairement une fonction et non des octets : sur plusieurs plateformes
  /// le contenu n'existe pas au moment du dépôt (fichier « virtuel » produit à
  /// la demande), et le matérialiser d'office chargerait en mémoire des données
  /// que l'hôte ne veut peut-être pas. `null` ⇒ contenu binaire indisponible.
  final Future<Uint8List> Function()? readBytes;
}

/// Description neutre d'une zone de dépôt.
@immutable
class ZDropRegionRequest {
  /// Construit une requête de zone de dépôt.
  const ZDropRegionRequest({
    required this.child,
    required this.onDrop,
    this.accepts = const <ZDropKind>{ZDropKind.file},
    this.onHoverChanged,
  });

  /// Contenu de la zone — rendu **inchangé** lorsqu'aucun backend natif n'est
  /// installé (cf. le défaut zéro-dépendance d'AD-57).
  final Widget child;

  /// Notifié avec les éléments déposés. Le socle ne les interprète jamais.
  final void Function(List<ZDroppedItem> items) onDrop;

  /// Natures acceptées. Un dépôt hors de cet ensemble est **ignoré**, jamais
  /// une erreur (AD-10).
  final Set<ZDropKind> accepts;

  /// Notifié quand un glissement acceptable entre ou sort de la zone, pour
  /// l'affordance visuelle. `null` ⇒ aucune affordance.
  final void Function(bool isHovering)? onHoverChanged;
}
