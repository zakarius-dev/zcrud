/// Profil de référence d'apparence : quelle valeur DOMINE quand ni le
/// paramètre d'appel ni le jeton de thème ne disent rien.
library;

import 'package:flutter/widgets.dart';

import 'z_theme.dart';

/// Ce que le socle peint quand **rien** n'a été déclaré.
///
/// Le socle porte une **référence auditée** de couleurs (palette signature,
/// bande d'accent d'en-tête de section, tuile d'icône). Ce profil décide si
/// cette référence s'applique — c'est l'unique échappatoire globale, à poser
/// une seule fois, à la racine :
///
/// ```dart
/// ZcrudScope(
///   theme: const ZcrudTheme(referenceProfile: ZReferenceProfile.neutral),
///   child: …,
/// )
/// ```
///
/// La priorité reste **paramètre > jeton > référence** : un profil neutre
/// n'efface que la RÉFÉRENCE. Une couleur passée en paramètre (par exemple
/// `ZEditionSectionStyle.topAccent`) ou posée en jeton
/// ([ZcrudTheme.signaturePalette]) continue de s'appliquer, dans les deux
/// profils.
enum ZReferenceProfile {
  /// Les membres COULEUR non déclarés prennent la valeur de la référence
  /// auditée. C'est le **défaut** quand le jeton
  /// [ZcrudTheme.referenceProfile] est nul.
  legacy,

  /// Les membres COULEUR non déclarés valent `null` : aucune couleur de
  /// référence n'est peinte, et la géométrie qui n'existait que pour la porter
  /// (bande d'accent, tuile d'icône) n'est pas montée.
  ///
  /// Les **scalaires** ne sont pas concernés : ils restent remplaçables jeton
  /// par jeton dans les deux profils.
  neutral,
}

/// Arbitre un membre COULEUR entre la référence auditée et le profil neutre,
/// à partir d'un profil **déjà résolu**.
///
/// Rend [legacyValue] si [profile] vaut [ZReferenceProfile.legacy] **ou est
/// nul** (le défaut est la référence), sinon [neutralValue] (`null` par
/// défaut).
///
/// Fonction **pure** : elle ne lit aucun contexte, ce qui la rend testable et
/// utilisable hors arbre de widgets.
T? zLegacyOrIn<T>(
  ZReferenceProfile? profile,
  T legacyValue, [
  T? neutralValue,
]) =>
    (profile ?? ZReferenceProfile.legacy) == ZReferenceProfile.legacy
        ? legacyValue
        : neutralValue;

/// Même arbitrage que [zLegacyOrIn], en lisant le profil du thème CRUD résolu
/// pour [context] (`ZcrudScope.theme` → extension de `Theme` → repli).
///
/// À appeler au **dernier maillon** d'une chaîne de résolution — c'est-à-dire
/// une fois que le paramètre d'appel et le jeton de thème ont déjà été
/// consultés et se sont tus.
T? zLegacyOr<T>(
  BuildContext context,
  T legacyValue, [
  T? neutralValue,
]) =>
    zLegacyOrIn<T>(
      ZcrudTheme.of(context).referenceProfile,
      legacyValue,
      neutralValue,
    );
