/// **Export du listing** d'un `ZCrudScreen` : ce que l'utilisateur voit, rendu
/// en fichier.
///
/// Un écran n'exporte rien par défaut, et n'en sait rien faire : produire un
/// `.xlsx` ou un `.pdf` demande des bibliothèques lourdes, qu'aucun hôte ne
/// doit payer sans les avoir demandées. L'écran ne connaît donc que le port
/// `ZListExporter` du cœur ; les formats sont **déclarés** par l'application,
/// et leurs implémentations vivent dans les paquets d'export.
///
/// Sans [ZExportPolicy], l'écran est exactement celui d'avant : aucune entrée
/// d'export dans l'app-bar, aucune dépendance supplémentaire.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZExportedBytes, ZListExporter;

/// Remise du fichier produit à l'application.
///
/// L'écran ne sait pas où va un fichier : enregistrer, partager, imprimer,
/// téléverser sont des décisions de plateforme et de produit. Il produit les
/// octets, puis appelle ce rappel — c'est l'application qui conclut le geste.
///
/// Le `BuildContext` est celui de l'écran, encore monté au moment de l'appel :
/// il permet d'ouvrir une feuille de partage ou d'afficher un message.
typedef ZCrudExportDelivery = FutureOr<void> Function(
  BuildContext context,
  ZExportedBytes file,
);

/// Politique d'**export** d'un écran CRUD.
///
/// ```dart
/// ZCrudScreen<Consignataire>(
///   title: 'Consignataires',
///   source: ZCrudSource.repository(repo),
///   registry: registry,
///   export: ZExportPolicy(
///     exporters: const <ZListExporter>[ZCsvListExporter(), ZPdfListExporter()],
///     onExported: (context, file) => monPartage(file),
///   ),
/// )
/// ```
///
/// ## Ce que l'écran offre
///
/// Un format déclaré = une entrée dans le menu de débordement de l'app-bar
/// (« Exporter (CSV) »), dans l'ordre de déclaration. Une liste d'exporteurs
/// **vide** n'offre aucune entrée : déclarer la politique sans format ne fait
/// donc rien apparaître, plutôt que d'ouvrir un menu vide.
///
/// ## Ce qui est exporté
///
/// **Ce que l'écran affiche, et rien d'autre** : les lignes réellement listées
/// — tri, filtres, recherche et vue (vivants ou corbeille) déjà appliqués —,
/// avec les colonnes dérivées du schéma et leurs valeurs **formatées**, telles
/// qu'elles sont peintes. Quand une **sélection** est en cours, ce sont les
/// seuls éléments cochés qui partent : c'est la lecture attendue d'un geste
/// d'export lancé sélection faite.
///
/// N'en font pas partie : la colonne de numéro d'ordre, les cases à cocher de
/// sélection et les boutons d'action. Ce sont des ornements de l'écran, pas des
/// données.
///
/// ## Droits
///
/// L'export est une **lecture** : il ne montre rien de plus que le listing déjà
/// affiché, et n'est donc offert que là où l'écran affiche ce listing —
/// c'est-à-dire quand `ZCrudAction.view` est accordée. Aucun droit propre à
/// l'export n'est introduit : une application qui veut le restreindre plus
/// finement déclare (ou non) sa politique selon son profil d'utilisateur.
@immutable
class ZExportPolicy {
  /// Déclare l'export de l'écran.
  ///
  /// [exporters] : les formats offerts, dans l'ordre où ils apparaîtront. Deux
  /// exporteurs de même `id` désignent le même format : seul le premier est
  /// offert.
  ///
  /// [onExported] : reçoit le fichier produit. **Requis** — un export dont les
  /// octets n'iraient nulle part serait un geste sans effet, et le silence
  /// serait indiscernable d'une panne.
  ///
  /// [fileBaseName] : radical du nom de fichier, sans extension. Omis, le titre
  /// de l'écran est employé, réduit à des caractères sûrs.
  const ZExportPolicy({
    required this.exporters,
    required this.onExported,
    this.fileBaseName,
  });

  /// Formats offerts, dans l'ordre d'affichage. Vide ⇒ aucune entrée d'export.
  final List<ZListExporter> exporters;

  /// Remise du fichier produit à l'application.
  final ZCrudExportDelivery onExported;

  /// Radical du nom de fichier (sans extension), ou `null` pour le dériver du
  /// titre de l'écran.
  final String? fileBaseName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZExportPolicy &&
          other.onExported == onExported &&
          other.fileBaseName == fileBaseName &&
          _sameExporters(other.exporters, exporters);

  @override
  int get hashCode => Object.hash(
        onExported,
        fileBaseName,
        Object.hashAll(exporters),
      );

  static bool _sameExporters(List<ZListExporter> a, List<ZListExporter> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
