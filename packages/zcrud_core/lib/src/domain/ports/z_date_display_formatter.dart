/// `ZDateDisplayFormatter` — **port neutre** de FORMATAGE D'AFFICHAGE d'une
/// date/heure (CR-DODLP-GAP3BIS).
///
/// ## Le défaut fermé ici
///
/// Une valeur de date est stockée en **ISO-8601** (`ZDateFieldWidget` écrit
/// `DateTime.toIso8601String()`). Toutes les voies de LECTURE du paquet la
/// rendaient telle quelle — `2026-08-09T00:00:00.000` là où le legacy DODLP
/// affiche `Dim. 9 août 2026`. La donnée est bonne ; c'est sa **projection**
/// qui manquait.
///
/// ## Pourquoi un port et pas un formatage en dur
///
/// Un rendu localisé de date exige `package:intl` (noms de mois/jours, ordre
/// des composantes, chiffres). **AD-1 interdit à `zcrud_core` d'en dépendre.**
/// Le cœur pose donc le **seam** ; l'implémentation `intl` vit hors du cœur
/// (`zcrud_intl`) et est injectée par `ZcrudScope(dateDisplayFormatter: …)`.
///
/// **NEUTRALITÉ (NON-NÉGOCIABLE, AD-1)** : ce fichier est **pur-Dart** (aucun
/// import Flutter/`intl`/backend). Aucune implémentation concrète ne vit dans
/// le cœur.
///
/// ## Repli DÉFINI (AD-10) — l'hôte passif ne bouge pas
///
/// Le repli du cœur est **la chaîne brute déjà rendue aujourd'hui**, et c'est
/// délibéré : un repli « mieux » (tronquer l'ISO à `AAAA-MM-JJ`, par ex.)
/// **déplacerait tout hôte passif** qui n'a rien demandé. Le socle retombe donc
/// sur `'$value'` dans **tous** les chemins dégradés :
/// - aucun port injecté ;
/// - valeur non parsable en `DateTime` (chaîne libre, `null`, autre type) ;
/// - port qui retourne `null` (« je ne sais pas rendre ce mode ») ou une chaîne
///   vide ;
/// - port qui **lève** (jamais d'exception propagée dans un `build`).
///
/// ⇒ **Le formatage est visible UNIQUEMENT pour l'hôte qui injecte le port.**
///
/// ## Portée
///
/// Le mode [ZDateMode.time] n'est **pas** routé vers ce port : sa valeur stockée
/// est déjà lisible (`HH:mm`, non ISO, non parsable en `DateTime`). Seuls
/// [ZDateMode.date] et [ZDateMode.dateTime] le sont.
library;

import '../edition/z_field_config.dart';

/// Port **abstrait** (neutre) de formatage d'affichage d'une date.
///
/// Contrat (AD-10) : [format] retourne la représentation lisible de [value], ou
/// `null` pour **déléguer au repli défini du socle** (la chaîne brute). Une impl
/// ne doit pas lever ; si elle lève, le socle replie de la même façon.
abstract class ZDateDisplayFormatter {
  /// Constructeur `const` (impl concrètes immuables si possible).
  const ZDateDisplayFormatter();

  /// Rend [value] pour l'affichage.
  ///
  /// [mode] distingue une date seule d'une date+heure ([ZDateMode.time] n'est
  /// jamais transmis — cf. dartdoc de bibliothèque). [localeTag] est la BCP-47
  /// de la locale ambiante (`fr-FR`, `en`), ou `null` si l'arbre n'en porte pas
  /// — l'impl choisit alors sa locale par défaut.
  ///
  /// Retourner `null` (ou une chaîne vide) ⇒ repli du socle (chaîne brute).
  String? format(
    DateTime value, {
    required ZDateMode mode,
    String? localeTag,
  });
}

/// Mode d'affichage **effectif** d'un champ date (source unique — consommée par
/// le widget d'édition ET par les voies de lecture, jamais recopiée).
///
/// `ZDateConfig.mode` explicite prime ; à défaut le mode est dérivé du type du
/// champ (`time` → [ZDateMode.time] ; tout le reste → [ZDateMode.dateTime]).
ZDateMode zDateModeOf(ZFieldConfig? config, {required bool isTimeType}) {
  if (config is ZDateConfig && config.mode != null) return config.mode!;
  if (isTimeType) return ZDateMode.time;
  return ZDateMode.dateTime;
}
