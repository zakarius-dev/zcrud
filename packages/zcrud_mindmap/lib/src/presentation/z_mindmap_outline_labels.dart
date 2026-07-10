/// Libellés a11y **externalisés** de l'éditeur outline (Story E10-3, AD-13/FR-26).
///
/// AD-13 exige des libellés a11y externalisés (jamais de chaîne UI métier codée
/// en dur dans le widget). Cet objet **immuable** porte tous les libellés
/// d'action et hints de champ, avec un **repli neutre non-nul** (aucune valeur
/// `null`) : l'app hôte peut tout surcharger (localisation), mais l'éditeur
/// fonctionne sans configuration. Aucune couleur/dimension ici (layout = thème).
library;

import 'package:flutter/foundation.dart';

/// Bundle **immuable** de libellés a11y pour [ZMindmapOutlineEditor].
///
/// Chaque champ a un **repli neutre non-nul** (AC4). Toutes les chaînes UI de
/// l'éditeur passent par cet objet : le widget ne code **aucune** chaîne en dur.
@immutable
class ZMindmapOutlineLabels {
  /// Construit un bundle de libellés. Toutes les valeurs ont un repli neutre.
  const ZMindmapOutlineLabels({
    this.addChild = 'Ajouter un enfant',
    this.addSibling = 'Ajouter un frère',
    this.delete = 'Supprimer',
    this.indent = 'Indenter',
    this.outdent = 'Désindenter',
    this.moveUp = 'Monter',
    this.moveDown = 'Descendre',
    this.addRoot = 'Ajouter une racine',
    this.save = 'Enregistrer',
    this.labelHint = 'Titre',
    this.contentHint = 'Contenu',
  });

  /// Libellé a11y du bouton « ajouter un enfant ».
  final String addChild;

  /// Libellé a11y du bouton « ajouter un frère ».
  final String addSibling;

  /// Libellé a11y du bouton « supprimer ».
  final String delete;

  /// Libellé a11y du bouton « indenter » (`indentNode`).
  final String indent;

  /// Libellé a11y du bouton « désindenter » (`outdentNode`).
  final String outdent;

  /// Libellé a11y du bouton « monter » (`reorderChild` vers l'index précédent).
  final String moveUp;

  /// Libellé a11y du bouton « descendre » (`reorderChild` vers l'index suivant).
  final String moveDown;

  /// Libellé a11y du bouton « ajouter une racine ».
  final String addRoot;

  /// Libellé a11y du bouton « enregistrer » (émet la forêt mutée via `onSave`).
  final String save;

  /// Hint a11y / placeholder du champ d'édition de `label`.
  final String labelHint;

  /// Hint a11y / placeholder du champ d'édition de `content`.
  final String contentHint;
}
