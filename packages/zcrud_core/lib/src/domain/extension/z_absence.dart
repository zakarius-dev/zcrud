/// Préservation de l'**absence** sur le chemin ENTITÉ (CR-IFFD-18).
///
/// ## Pourquoi ce fichier existe — et l'erreur qui l'a rendu nécessaire
///
/// CR-IFFD-12 avait livré `ZStudyLegacyCodec.preserveAbsenceUnder` : un moyen de
/// préserver, à la migration, la distinction que le domaine strict ne porte pas
/// (un champ **absent** vs un champ valant `''`). Le handoff `v0.4.6` en avait
/// conclu que les hôtes pouvaient retirer leurs contournements app-side.
///
/// **C'était faux, et la recommandation aurait détruit de la donnée.** Cette
/// option n'existe **qu'au codec**, or les hôtes qui consomment les entités
/// *directement* ne construisent aucun codec : leur chemin est
/// `entité hôte → constructeur → toMap() → store`, et il ne traverse jamais
/// `toCanonical`. La sémantique est de surcroît **inverse** — le codec marque
/// l'absence dans la map *legacy* (`null`/clé manquante), alors que sur la map
/// *runtime* le champ vaut déjà `''` : le marqueur ne se poserait jamais.
///
/// Ces helpers portent donc la **même capacité sur le chemin entité**, avec la
/// **même clé de survie** que le codec — pour qu'un document migré par le codec
/// et relu par le chemin entité s'accordent, au lieu de porter deux conventions
/// qui s'ignorent.
///
/// ## Usage
///
/// Au moment de construire l'entité canonique depuis le modèle de l'hôte —
/// **le seul moment où l'information existe encore** :
///
/// ```dart
/// ZStudyDocument(
///   fileName: src.fileName ?? '',
///   folderId: src.folderId ?? '',
///   extra: zMarkAbsent(const <String, dynamic>{}, zNullFieldsOf(<String, Object?>{
///     'file_name': src.fileName,
///     'folder_id': src.folderId,
///   })),
/// )
/// ```
///
/// Au retour, pour rendre la distinction au modèle de l'hôte :
///
/// ```dart
/// final fileName = zRestoreAbsentString(doc.extra, 'file_name', doc.fileName);
/// // → `null` si le champ était absent ET vaut toujours `''`
/// ```
library;

/// Clé de survie listant les champs **absents** à l'origine.
///
/// ⚠️ **Valeur volontairement identique** à `ZStudyLegacyCodec.kAbsentFieldsKey`
/// (`_legacy_absent_fields`). Le préfixe `_legacy_` est un héritage du chemin
/// migration ; le renommer pour l'esthétique romprait l'accord entre les deux
/// chemins sur les corpus **déjà migrés** — un coût réel pour un gain nul.
const String kZAbsentFieldsKey = '_legacy_absent_fields';

/// Noms des champs dont la valeur source est `null`.
///
/// Passer une map `nom canonique → valeur source nullable` ; rend l'ensemble des
/// noms à marquer. Sépare le **constat** de l'absence (ici) de son
/// **enregistrement** ([zMarkAbsent]), pour que l'hôte puisse composer les deux
/// librement.
Set<String> zNullFieldsOf(Map<String, Object?> sourceFields) => <String>{
      for (final e in sourceFields.entries)
        if (e.value == null) e.key,
    };

/// Enregistre [absentFields] dans [extra] et rend la map résultante.
///
/// **CUMULATIF** : fusionne avec un marqueur déjà présent au lieu de l'écraser.
/// C'est la même leçon que CR-IFFD-7 et que l'idempotence du codec — au second
/// passage le champ vaut `''` et non plus `null`, donc un recalcul seul
/// effacerait l'absence au moment précis où on la relit.
///
/// N'écrit **rien** si l'ensemble résultant est vide : un marqueur vide serait
/// indiscernable d'un marqueur absent au retour (round-trip idempotent).
Map<String, dynamic> zMarkAbsent(
  Map<String, dynamic> extra,
  Iterable<String> absentFields,
) {
  final merged = <String>{...zAbsentFields(extra), ...absentFields};
  if (merged.isEmpty) return extra;
  return <String, dynamic>{
    ...extra,
    kZAbsentFieldsKey: merged.toList()..sort(),
  };
}

/// Lit les champs marqués absents. **DÉFENSIF** (AD-10) : ne throw jamais, quel
/// que soit l'état de [extra] — une entrée corrompue est écartée sans emporter
/// les autres.
Set<String> zAbsentFields(Map<String, dynamic> extra) {
  final raw = extra[kZAbsentFieldsKey];
  if (raw is! List) return const <String>{};
  return <String>{
    for (final e in raw)
      if (e is String && e.isNotEmpty) e,
  };
}

/// `true` si [field] était absent à l'origine.
bool zIsAbsent(Map<String, dynamic> extra, String field) =>
    zAbsentFields(extra).contains(field);

/// Rend `null` si [field] était marqué absent **et** vaut toujours la chaîne
/// vide ; sinon rend [value] tel quel.
///
/// **Restitution CONSERVATRICE**, identique à celle du codec : si l'utilisateur
/// a renseigné le champ depuis, sa saisie l'emporte sur un marqueur devenu
/// périmé. Sans cette garde, relire écraserait une donnée réelle par `null`.
String? zRestoreAbsentString(
  Map<String, dynamic> extra,
  String field,
  String value,
) =>
    value.isEmpty && zIsAbsent(extra, field) ? null : value;
