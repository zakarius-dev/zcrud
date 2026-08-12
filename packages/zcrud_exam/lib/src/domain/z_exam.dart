/// Entité canonique `ZExam` — un examen daté rattaché à un dossier, avec
/// rappels. `ZEntity` + `ZExtensible`, `@ZcrudModel`.
///
/// ## Proximité d'examen — horloge injectée
///
/// [daysUntil]/[isPast]/[isApproaching] prennent l'horloge courante en
/// **paramètre** (`DateTime now`) : aucun `DateTime.now()`/`DateTime()` sans
/// argument dans ce paquet. Ces méthodes sont **pures, totales,
/// déterministes** — deux appels avec le même `now` rendent la même valeur,
/// et la sortie ne dépend que de `now` et de [date]. Un `DateTime.now()`
/// caché rendrait ce calcul non déterministe et non testable.
///
/// ## `reminderTime` est typé, jamais une chaîne ambiguë
///
/// [reminderTime] est un [ZReminderTime]`?` — le type porte le format
/// `'HH:mm'` — persisté sous la clé réservée [kReminderTimeKey]
/// (`reminder_time`), décodé et réémis explicitement dans [fromMap] et
/// [toMap]. Un sous-modèle généré par le codegen sérialiserait cette valeur
/// en map `{hour, minute}`, jamais en `'HH:mm'`.
///
/// ## Aucun horodatage de synchronisation inline
///
/// `ZExam` ne déclare **ni `updatedAt` ni `isDeleted`** : l'autorité
/// Last-Write-Wins et la suppression logique vivent hors de l'entité
/// (`ZSyncMeta`), conformément à l'invariant AD-9. [date] est une clé
/// **métier**, distincte de toute clé de synchronisation — un champ métier
/// logé sous une clé réservée au store serait écrasé silencieusement à
/// chaque écriture.
///
/// ## Extension et `extra`
///
/// Le constructeur ne filtre rien (`extra` brut est conservé tel quel) ; seul
/// l'accesseur [extra] normalise en retirant les clés réservées — c'est le
/// seul point traversé par toutes les voies de lecture. [fromMap] et
/// [copyWith] partagent la même garde pour rester en accord (invariant
/// AD-4).
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_reminder_recurrence.dart';
import 'z_reminder_time.dart';

part 'z_exam.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou rend `null`
/// (invariant AD-4).
///
/// Fourni par l'application appelante et injecté dans [ZExam.fromMap] : le
/// domaine ne connaît pas les sous-classes concrètes d'extension. Toute
/// exception levée par le parseur est absorbée en `null` par
/// [ZExtension.guard] (invariant AD-10).
typedef ZExamExtensionParser = ZExtension? Function(Map<String, dynamic> json);

/// Clé persistée du canal hors schéma [ZExam.reminderTime].
///
/// Déclarée une seule fois, consommée par [ZExam.fromMap], [ZExam.toMap] et
/// [ZExam._reservedKeys] : aucun littéral dupliqué.
const String kReminderTimeKey = 'reminder_time';

/// Clé persistée du canal hors schéma [ZExam.reminderRecurrence].
///
/// Réservée : sans cela, elle atterrirait dans [ZExam.extra], serait réémise
/// en double par [ZExam.toMap], et l'égalité entre une instance en mémoire et
/// la même relue du store casserait.
const String kReminderRecurrenceKey = 'reminder_recurrence';

/// Examen daté rattaché à un dossier, avec rappels — contenu personnel à
/// identité propre (invariant AD-14).
@ZcrudModel(kind: 'exam', fieldRename: ZFieldRename.snake)
class ZExam extends ZEntity with ZExtensible {
  /// Construit un examen.
  ///
  /// Ce constructeur ne porte volontairement aucun `assert` de validation
  /// (invariant AD-10) : le décodeur généré (`_$ZExamFromMap`) l'appelle avec
  /// les valeurs brutes d'une map persistée, et un `assert` y ferait échouer
  /// la désérialisation d'une donnée corrompue. Les gardes de validation
  /// vivent exclusivement aux frontières [fromMap] et [copyWith], qui
  /// partagent la même garde pour `extra` ([_sanitizeExtra]).
  ///
  /// Le constructeur `const` ne peut pas copier défensivement
  /// [reminderDaysBefore] — passer une liste mutable puis la modifier après
  /// coup engage l'appelant, pas l'entité.
  const ZExam({
    this.id,
    this.folderId = '',
    this.title = '',
    this.date,
    this.reminderEnabled = false,
    this.reminderDaysBefore = const <int>[],
    this.reminderTime,
    this.reminderRecurrence,
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // Un paramètre nommé ne peut pas être privé en Dart
    // (PRIVATE_OPTIONAL_PARAMETER) — le slot brut doit pourtant rester privé,
    // c'est l'accesseur `extra` qui porte la garde.
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit défensivement un examen depuis une map persistée (invariant
  /// AD-10) — aucun cas ne lève, pas même `ZExam.fromMap(const {})`.
  ///
  /// Délègue au décodeur généré pour les champs de schéma (défauts sûrs :
  /// `folder_id`/`title` absents → `''` ; `date` illisible → `null` ;
  /// `reminder_enabled` absent → `false` ; `reminder_days_before` illisible →
  /// `const []`), puis câble les canaux hors schéma :
  /// - [reminderTime] via [ZReminderTime.parse] — une valeur invalide comme
  ///   `'99:99'` rend `null`, jamais une exception ;
  /// - [extension] via [extensionParser] (repli `null`, [ZExtension.guard]) ;
  /// - [extra] = les clés non réservées de la map (round-trip préservé).
  factory ZExam.fromMap(
    Map<String, dynamic> map, {
    ZExamExtensionParser? extensionParser,
  }) {
    final base = _$ZExamFromMap(map);
    return ZExam(
      id: base.id,
      folderId: base.folderId,
      title: base.title,
      date: base.date,
      reminderEnabled: base.reminderEnabled,
      reminderDaysBefore: base.reminderDaysBefore,
      // Canal hors schéma — décodé à la main, défensivement (invariant
      // AD-10).
      reminderTime: ZReminderTime.parse(map[kReminderTimeKey] as String?),
      // Canal hors schéma — décodé à la main, défensivement (invariant
      // AD-10).
      reminderRecurrence:
          ZReminderRecurrence.fromJsonSafe(map[kReminderRecurrenceKey]),
      extension: _decodeExtension(map['extension'], extensionParser),
      extra: _extraFrom(map),
    );
  }

  /// Identité opaque (`null` pour l'éphémère — jamais attribuée par
  /// l'entité elle-même ; matérialisée au repository). Invariant AD-14.
  @override
  @ZcrudId()
  final String? id;

  /// Dossier d'appartenance — clé neutre `String` (défaut `''`), qui ne
  /// référence aucun symbole d'un paquet d'organisation d'étude : l'arête de
  /// dépendance vers un tel paquet, si nécessaire un jour, ne doit pas passer
  /// par un import ici.
  @ZcrudField()
  final String folderId;

  /// Intitulé de l'examen (défaut `''`).
  @ZcrudField(label: 'Examen')
  final String title;

  /// Date de l'examen — clé métier `date`, persistée en ISO-8601, nullable
  /// (défaut `null`).
  ///
  /// Nullable car `DateTime` n'a aucun constructeur `const` : un champ
  /// non-nullable exigerait `required`, ce qui entre en friction avec un
  /// constructeur `const`. `date` illisible → `null`, jamais une exception.
  /// Distincte de toute clé de synchronisation (`updated_at`/`is_deleted`,
  /// hors entité).
  @ZcrudField()
  final DateTime? date;

  /// Les rappels sont-ils activés pour cet examen ? (persisté
  /// `reminder_enabled`, défaut `false`).
  @ZcrudField()
  final bool reminderEnabled;

  /// Seuils de rappel en nombre de jours avant l'échéance (persisté
  /// `reminder_days_before`, défaut `const <int>[]`, ordre préservé).
  ///
  /// Le constructeur `const` ne copie pas défensivement cette liste — cette
  /// dartdoc ne promet donc pas une immuabilité profonde.
  @ZcrudField()
  final List<int> reminderDaysBefore;

  /// Heure de rappel typée ([ZReminderTime]`?`), canal hors schéma, persistée
  /// `reminder_time` au format `'HH:mm'`, défaut `null`, sans annotation de
  /// champ.
  ///
  /// Un sous-modèle généré par le codegen serait sérialisé en map
  /// `{hour, minute}`, jamais en `'HH:mm'` — c'est pourquoi il est décodé et
  /// réémis explicitement, et sa clé [kReminderTimeKey] est réservée : sinon
  /// elle atterrirait dans [extra] et serait réémise en double par [toMap].
  ///
  /// Conséquence assumée : un canal hors schéma ne produit aucune spec de
  /// champ ⇒ `reminderTime` n'apparaît pas dans un formulaire généré
  /// automatiquement ; un éditeur d'examen ajoute son champ heure
  /// explicitement.
  @ZcrudIgnore()
  final ZReminderTime? reminderTime;

  /// Emplacement d'extension typée et versionnée (invariant AD-4), `null` si
  /// absente. Hors schéma généré.
  @override
  final ZExtension? extension;

  /// Emplacement `extra` brut tel que reçu par le constructeur — lu nulle
  /// part ailleurs que dans l'accesseur [extra] (ni `toMap`, ni `==`, ni
  /// `hashCode`).
  ///
  /// Il peut être pollué : le constructeur nominal est `const`, il ne peut
  /// appeler aucune fonction dans son initialiseur, et l'invariant AD-10
  /// interdit d'y placer un `assert`. C'est l'accesseur [extra] qui porte la
  /// garde — le seul point que toutes les voies traversent.
  final Map<String, dynamic> _extra;

  /// Échappatoire non typée (invariant AD-4), défaut `const {}` (jamais
  /// `null`), qui préserve au round-trip les clés inconnues du domaine. Hors
  /// schéma généré.
  ///
  /// L'accesseur normalise la valeur brute : il ne rend jamais une clé
  /// réservée, quelle que soit la voie d'écriture — y compris le
  /// constructeur `const`, seule voie incapable de filtrer. Cette promesse
  /// est inconditionnelle, sans `assert` ni exception (invariant AD-10).
  @override
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  /// Sérialise vers la map persistée complète (snake_case), sans perte.
  ///
  /// Réutilise le `toMap()` généré pour les champs de schéma, puis superpose
  /// les canaux hors schéma : [extra] (l'accesseur qui normalise, jamais le
  /// champ brut), [reminderTime] sous [kReminderTimeKey] si non `null`
  /// (sinon la clé est omise), et [extension].
  ///
  /// Ne réémet ni `updated_at` ni `is_deleted` sur aucune voie ([_reservedKeys]
  /// inclut les clés réservées de `ZSyncMeta` : ces clés ne peuvent entrer
  /// dans [extra], donc ne peuvent plus en ressortir — invariant AD-9).
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      // Étale l'accesseur (qui normalise), jamais le champ brut `_extra`.
      ...extra,
      ...ZExamZcrud(this).toMap(),
    };
    // Canal hors schéma — réémis explicitement en `'HH:mm'`. Omis si `null`
    // (round-trip idempotent : `fromMap` d'une map sans la clé rend `null`).
    if (reminderTime != null) {
      map[kReminderTimeKey] = reminderTime!.toHhmm();
    }
    // Canal hors schéma — omis si `null` ou vide : un emplacement vide
    // persisté serait indiscernable d'un emplacement absent au retour.
    final recurrence = reminderRecurrence;
    if (recurrence != null && !recurrence.isEmpty) {
      map[kReminderRecurrenceKey] = recurrence.toJson();
    }
    if (extension != null) {
      map['extension'] = extension!.toJson();
    }
    return map;
  }

  /// Copie à sentinelle (un argument omis préserve la valeur, `null`
  /// explicite la remet à `null`) — couvre tous les champs, y compris
  /// [reminderTime], [extension] et [extra], que le `copyWith` généré par le
  /// codegen remettrait à leurs défauts (perte silencieuse). Masque le
  /// `copyWith` de l'extension générée.
  ZExam copyWith({
    Object? id = _$undefined,
    Object? folderId = _$undefined,
    Object? title = _$undefined,
    Object? date = _$undefined,
    Object? reminderEnabled = _$undefined,
    Object? reminderDaysBefore = _$undefined,
    Object? reminderTime = _$undefined,
    Object? reminderRecurrence = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) {
    return ZExam(
      id: identical(id, _$undefined) ? this.id : id as String?,
      folderId:
          identical(folderId, _$undefined) ? this.folderId : folderId as String,
      title: identical(title, _$undefined) ? this.title : title as String,
      date: identical(date, _$undefined) ? this.date : date as DateTime?,
      reminderEnabled: identical(reminderEnabled, _$undefined)
          ? this.reminderEnabled
          : reminderEnabled as bool,
      reminderDaysBefore: identical(reminderDaysBefore, _$undefined)
          ? this.reminderDaysBefore
          : reminderDaysBefore as List<int>,
      reminderTime: identical(reminderTime, _$undefined)
          ? this.reminderTime
          : reminderTime as ZReminderTime?,
      reminderRecurrence: identical(reminderRecurrence, _$undefined)
          ? this.reminderRecurrence
          : reminderRecurrence as ZReminderRecurrence?,
      extension: identical(extension, _$undefined)
          ? this.extension
          : extension as ZExtension?,
      // La garde de `extra` est la même fonction nommée qu'en `fromMap` —
      // `copyWith` ne peut pas rouvrir le filtre des clés réservées.
      extra: identical(extra, _$undefined)
          ? this.extra
          : _sanitizeExtra(extra as Map<String, dynamic>),
    );
  }

  // ==========================================================================
  // Proximité d'examen — pures, totales, déterministes, horloge injectée.
  // ==========================================================================

  /// Nombre de jours calendaires de [now] jusqu'à [date], ou `null` si [date]
  /// est `null` (méthode totale, invariant AD-10).
  ///
  /// Comparaison sur la date normalisée en UTC (`year/month/day`), pour
  /// éviter toute dérive de fuseau ou d'heure d'été : la différence entre
  /// deux `DateTime.utc` est exacte. Positif = futur, négatif = passé, `0` =
  /// même jour calendaire.
  ///
  /// `now` est un **paramètre** : la sortie ne dépend que de `now` et [date]
  /// — aucun `DateTime.now()` implicite.
  int? daysUntil(DateTime now) {
    final d = date;
    if (d == null) return null;
    final target = DateTime.utc(d.year, d.month, d.day);
    final today = DateTime.utc(now.year, now.month, now.day);
    return target.difference(today).inDays;
  }

  /// `true` si l'examen est strictement passé au regard de [now] : il a une
  /// [date] et son jour calendaire est antérieur à celui de [now].
  ///
  /// `false` si [date] est `null` (rien à comparer) ou si l'échéance est
  /// aujourd'hui ou à venir. Méthode totale, pure, déterministe.
  bool isPast(DateTime now) {
    final delta = daysUntil(now);
    return delta != null && delta < 0;
  }

  /// `true` si un rappel est dû au regard de [now] : les rappels sont
  /// activés ([reminderEnabled]), l'examen a une [date], il n'est pas passé,
  /// et l'échéance approche sous au moins un des seuils
  /// [reminderDaysBefore] (`daysUntil(now) <= seuil`).
  ///
  /// Sémantique totale et documentée : `false` si [date] est `null`, si
  /// [reminderEnabled] est `false`, ou si [reminderDaysBefore] est vide
  /// (aucun seuil ⇒ aucun rappel). Pure, déterministe.
  ///
  /// Exemple (`date` = J0, `reminderDaysBefore` = `[7, 1]`) : dû dès J-7 (le
  /// seuil 7 déclenche), reste dû à J-1 et J0, cesse dès J+1 (passé).
  bool isApproaching(DateTime now) {
    if (!reminderEnabled) return false;
    // Passe par la récurrence effective, jamais par les champs bruts : c'est
    // ce qui rend le modèle hebdomadaire visible à la logique de proximité.
    //
    // `date == null` ne rend plus `false` d'office : une récurrence
    // hebdomadaire est évaluable sans échéance (c'est son propos). La
    // famille relative, elle, reste inévaluable — voir [ZReminderRecurrence.matches].
    return effectiveReminderRecurrence.matches(now: now, dueDate: date);
  }

  /// Décode défensivement l'extension via [parser] (repli `null`, invariants
  /// AD-4 et AD-10).
  static ZExtension? _decodeExtension(
    Object? raw,
    ZExamExtensionParser? parser,
  ) {
    // Un hôte sans parseur ne détruit pas le payload : comme `extension` est
    // une clé connue (donc exclue d'`extra`), le contenu d'un autre hôte est
    // préservé verbatim, quel que soit le résultat du parseur.
    return zDecodeExtension(raw, parser);
  }

  /// Clés persistées réservées (champs générés, `extension`,
  /// [kReminderTimeKey], [kReminderRecurrenceKey] et les clés de
  /// synchronisation) — dérivées des spécifications de champs générées pour
  /// rester synchrones avec le codegen.
  ///
  /// Inclure les clés réservées de `ZSyncMeta` est essentiel (invariant
  /// AD-9) : le store écrit `updated_at`/`is_deleted` dans le corps avant de
  /// passer la map à [fromMap]. Sans cela, ces clés — propriété du store —
  /// atterriraient dans [extra] et seraient réémises par [toMap].
  ///
  /// Réserver [kReminderTimeKey] est également essentiel : le canal hors
  /// schéma étant réémis à la main par [toMap], sa clé doit être réservée —
  /// sinon elle atterrirait aussi dans [extra] et serait émise deux fois.

  /// Récurrence de rappel généralisée, canal hors schéma persisté sous la clé
  /// réservée [kReminderRecurrenceKey].
  ///
  /// `null` ⇒ emplacement absent : [reminderDaysBefore] fait alors seul
  /// autorité, exactement comme avant l'introduction de ce champ. Une
  /// application qui n'utilise que les seuils relatifs n'a rien à changer.
  ///
  /// Non-`null` ⇒ fait autorité et remplace [reminderDaysBefore] dans le
  /// calcul de proximité (voir [effectiveReminderRecurrence]). C'est
  /// délibéré : additionner les deux sources ferait déclencher des rappels
  /// que l'hôte n'a pas demandés dès qu'il migre — la récurrence peut
  /// d'ailleurs porter elle-même ses propres seuils.
  @ZcrudIgnore()
  final ZReminderRecurrence? reminderRecurrence;

  /// Récurrence réellement appliquée : [reminderRecurrence] si renseignée,
  /// sinon la forme relative dérivée de [reminderDaysBefore].
  ///
  /// Source unique de la logique de proximité : [isApproaching] passe par
  /// ici, jamais par les champs bruts — sinon les deux modèles
  /// divergeraient silencieusement.
  ZReminderRecurrence get effectiveReminderRecurrence =>
      reminderRecurrence ?? ZReminderRecurrence.relative(reminderDaysBefore);

  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZExamFieldSpecs) spec.name,
    'extension',
    kReminderTimeKey,
    kReminderRecurrenceKey,
    ...ZSyncMeta.reservedKeys,
  };

  /// Extrait `extra` = les clés non réservées de [map] (round-trip préservé)
  /// — frontière d'entrée. Délègue à [_sanitizeExtra], la garde partagée.
  static Map<String, dynamic> _extraFrom(Map<String, dynamic> map) =>
      _sanitizeExtra(map);

  /// La garde partagée de `extra`, appelée par les deux voies capables de
  /// filtrer : [fromMap] et [copyWith] (jamais divergentes). Délègue à
  /// [zSanitizeExtra] (`zcrud_core`), l'implémentation unique du dépôt.
  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZExam &&
          id == other.id &&
          folderId == other.folderId &&
          title == other.title &&
          date == other.date &&
          reminderEnabled == other.reminderEnabled &&
          // Ordre-sensible (les seuils sont réémis dans l'ordre).
          _intListEquals(reminderDaysBefore, other.reminderDaysBefore) &&
          reminderTime == other.reminderTime &&
          reminderRecurrence == other.reminderRecurrence &&
          extension == other.extension &&
          // Égalité profonde : `extra` porte du JSON arbitraire (donc
          // potentiellement imbriqué) — une égalité superficielle casserait
          // `fromMap(m) == fromMap(m)` dès qu'une clé legacy porte une `Map`
          // ou une `List`.
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll(<Object?>[
        id,
        folderId,
        title,
        date,
        reminderEnabled,
        Object.hashAll(reminderDaysBefore),
        reminderTime,
        reminderRecurrence,
        extension,
        zJsonHash(extra),
      ]);
}

/// Égalité ordonnée de deux `List<int>` (identité de `List` en Dart sinon).
bool _intListEquals(List<int> a, List<int> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
