/// Entité canonique `ZExam` — **examen daté rattaché à un dossier avec rappels**
/// (ES-2.6, **FR-S9**). `ZEntity` + `ZExtensible`, `@ZcrudModel`.
///
/// origine: lex_core / module « Étude » — entité `Exam` (`{id, folderId, title,
/// date, reminderEnabled, reminderDaysBefore[], reminderTime}`). Le canonique
/// retient la forme lex ; **IFFD est un cas de MIGRATION (ES-11.x), jamais une
/// source de forme** (précédent `ZSmartNote` : IFFD importe `cloud_firestore`,
/// violation NFR-S3). `lex_douane` étant absent de ce poste, la forme est portée
/// depuis le PRD/epics + `docs/canonical-schema.md`.
///
/// ## 🔴 Proximité d'examen — horloge INJECTÉE (D5)
///
/// [daysUntil]/[isPast]/[isApproaching] prennent l'horloge `now` en **PARAMÈTRE**
/// (`DateTime now`) : **AUCUN** `DateTime.now()`/`DateTime()` argless dans ce
/// package. Ces méthodes sont **pures, totales, déterministes** — deux appels avec
/// le même `now` rendent la même valeur, et la sortie ne dépend QUE de `now` +
/// [date]. Un `DateTime.now()` caché serait non déterministe, non testable, et est
/// littéralement banni des scripts de ce repo (prouvé par machine :
/// `no_datetime_now_test.dart`, R5).
///
/// ## 🔴 AD-28 / D2/D3 — `reminderTime` est TYPÉ, jamais une `String` ambiguë
///
/// [reminderTime] est un [ZReminderTime]` ?` (le TYPE dit le format `'HH:mm'`),
/// **CANAL HORS-CODEGEN** persisté sous la clé RÉSERVÉE [kReminderTimeKey]
/// (`reminder_time`), décodé/réémis À LA MAIN (patron `ZSmartNote.content` /
/// `ZDocumentReadingState.learning`). Un `@ZcrudModel` subModel le sérialiserait en
/// map `{hour, minute}`, jamais en `'HH:mm'` (D2).
///
/// ## 🔴 AD-19 / D... — AUCUN horodatage de sync inline
///
/// `ZExam` ne déclare **NI `updatedAt` NI `isDeleted`** : l'autorité Last-Write-Wins
/// et le soft-delete vivent **HORS-ENTITÉ** (`ZSyncMeta`, AD-16/AD-19). Le store
/// écrit `ZSyncMeta` **APRÈS** le corps à chaque `put` ⇒ un champ métier logé sous
/// une clé réservée serait **ÉCRASÉ SILENCIEUSEMENT**. [date] est une clé **MÉTIER**
/// (`date`), DISTINCTE de toute clé de sync (précédent `ZSmartNote.createdAt`).
/// [_reservedKeys] ⊇ `ZSyncMeta.reservedKeys` : ces clés ne polluent jamais [extra]
/// et ne sont jamais réémises par [toMap].
///
/// ## Patron `extra` ES-2.2b INTÉGRAL (jumeau `ZSmartNote`/`ZFlashcardTag`)
///
/// Constructeur `const` qui **ne filtre RIEN** (`: _extra = extra`), slot brut
/// [_extra] **lu nulle part ailleurs**, accesseur [extra] **normalisant**
/// (`zNormalizeExtra`, le SEUL point traversé par TOUTES les voies), garde partagée
/// [_sanitizeExtra] (`fromMap` **ET** `copyWith`), [toMap] étalant l'**accesseur**
/// `...extra`, [copyWith] **à sentinelle** couvrant TOUS les champs, égalité
/// **profonde** `zJsonEquals`/`zJsonHash`.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_reminder_recurrence.dart';
import 'z_reminder_time.dart';

part 'z_exam.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null` (AD-4).
///
/// Fourni par l'app/le satellite (convention `X.fromJsonSafe`) et injecté dans
/// [ZExam.fromMap] : le domaine ne connaît pas les sous-classes concrètes. Toute
/// exception est absorbée en `null` par [ZExtension.guard] (AD-10).
typedef ZExamExtensionParser = ZExtension? Function(Map<String, dynamic> json);

/// Clé persistée du canal **HORS-CODEGEN** [ZExam.reminderTime] (**D3**).
///
/// Déclarée **une seule fois** (patron `kContentKey`), consommée par
/// [ZExam.fromMap], [ZExam.toMap] **et** [ZExam._reservedKeys] : **zéro littéral
/// dupliqué**.
///
/// ⚠️ Elle **DOIT** rester le **snake_case du nom de champ** (`reminderTime` →
/// `reminder_time`) : c'est la **contrainte normative** de la règle **(g1)** du
/// gate `reserved-keys` — le champ `reminderTime` (non annoté `@ZcrudField`) est
/// détecté comme canal de clé `reminder_time`, qui DOIT donc être réservée.
const String kReminderTimeKey = 'reminder_time';

/// Clé persistée du canal **HORS-CODEGEN** [ZExam.reminderRecurrence]
/// (**CR-IFFD-17**, **D3**).
///
/// **RÉSERVÉE** : sans cela elle atterrirait dans [ZExam.extra], serait réémise
/// EN DOUBLE par `toMap()`, et l'`==` entre une instance mémoire et la même
/// relue du store casserait.
///
/// ⚠️ Déclarée **ICI**, aux côtés de [kReminderTimeKey], et non dans le fichier
/// du VO : le gate `reserved-keys` résout la constante dans le fichier de
/// l'entité qui la réserve. Déclarée ailleurs, elle est vue comme une clé
/// littérale non réservée — le gate l'a effectivement refusée.
///
/// Comme [kReminderTimeKey], elle **DOIT** rester le snake_case du nom de champ
/// (`reminderRecurrence` → `reminder_recurrence`) : contrainte normative de la
/// règle **(g1)**.
const String kReminderRecurrenceKey = 'reminder_recurrence';

/// Examen daté rattaché à un dossier, avec rappels — **contenu personnel
/// top-level à identité propre** (AD-14).
@ZcrudModel(kind: 'exam', fieldRename: ZFieldRename.snake)
class ZExam extends ZEntity with ZExtensible {
  /// Construit un examen (primitif `const`).
  ///
  /// ⛔ **AUCUN `assert` ici, volontairement** (AD-10) : le décodeur **généré**
  /// (`_$ZExamFromMap`) appelle ce constructeur avec les valeurs **BRUTES** de la
  /// map persistée. Un `assert` y ferait **échouer la désérialisation d'une donnée
  /// corrompue** — violation frontale d'AD-10. Les gardes vivent **exclusivement
  /// aux frontières** [fromMap] / [copyWith], et la garde `extra` y est **la MÊME
  /// fonction nommée** ([_sanitizeExtra]) — leçon H2 d'ES-2.1 / MAJEUR-3 de
  /// `ZSmartNote`.
  ///
  /// 🟡 **DW-ES24-1 (immuabilité profonde)** : le ctor `const` ne peut pas copier
  /// défensivement [reminderDaysBefore] — la dartdoc ne promet donc **pas** une
  /// copie profonde. Passer une `List` mutable et la muter après coup est un
  /// contrat d'appelant, pas un invariant d'entité (comme `ZSmartNote.content`).
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
    // ⚠️ Le « fix » du lint (`this._extra`) est ILLÉGAL en Dart : un paramètre
    // NOMMÉ ne peut pas être privé (PRIVATE_OPTIONAL_PARAMETER). Or le slot brut
    // DOIT rester privé — c'est l'ACCESSEUR `extra` qui porte la garde (ES-2.2b).
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit **défensivement** depuis une map persistée (AD-10) — **aucun cas
  /// ne throw**, pas même `ZExam.fromMap(const <String, dynamic>{})`.
  ///
  /// Délègue au `_$ZExamFromMap` **généré** pour les champs de schéma (défauts
  /// sûrs : `folder_id`/`title` absents → `''` ; `date` illisible → `null` ;
  /// `reminder_enabled` absent → `false` ; `reminder_days_before` illisible →
  /// `const []`), **puis câble les canaux HORS-CODEGEN** :
  /// - 🔴 [reminderTime] (**D3**) via [ZReminderTime.parse] — `'99:99'` ⇒ `null`,
  ///   jamais un throw ;
  /// - [extension] via [extensionParser] (repli `null`, `ZExtension.guard`) ;
  /// - [extra] = clés **non réservées** de la map (round-trip AD-4).
  ///
  /// ⚠️ Corps **NON NU** obligatoire (`ZExtensible`) : une délégation nue à
  /// `_$ZExamFromMap` laisserait `extra` **VIDE** — le **build la REFUSE**
  /// (`_rejectNakedCodegenDelegation`) et le garde runtime `_$zRequireExtraPreserved`
  /// **lèverait à l'enregistrement**.
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
      // 🔴 CANAL HORS-CODEGEN (D3) — décodé À LA MAIN, défensif (AD-10).
      reminderTime: ZReminderTime.parse(map[kReminderTimeKey] as String?),
      // 🔴 CANAL HORS-CODEGEN (CR-IFFD-17) — décodé À LA MAIN, défensif (AD-10).
      reminderRecurrence:
          ZReminderRecurrence.fromJsonSafe(map[kReminderRecurrenceKey]),
      extension: _decodeExtension(map['extension'], extensionParser),
      extra: _extraFrom(map),
    );
  }

  /// Identité opaque (`null` pour l'éphémère — **jamais attribuée par l'entité** ;
  /// matérialisée au repository, ES-3). AD-14.
  @override
  @ZcrudId()
  final String? id;

  /// Dossier d'appartenance — **clé NEUTRE `String`** (défaut `''`).
  ///
  /// ⚠️ **Aucun symbole de `zcrud_study_kernel` n'est importé** (leçon L2 d'ES-2.1 :
  /// « dépendance DÉCLARÉE, aucun import ») — exactement comme `ZSmartNote.folderId`
  /// et `ZFlashcard.folderId`.
  @ZcrudField()
  final String folderId;

  /// Intitulé de l'examen (défaut `''`).
  @ZcrudField(label: 'Examen')
  final String title;

  /// Date de l'examen — clé MÉTIER `date`, persistée **ISO-8601** (D4/D6),
  /// **nullable** (défaut `null`).
  ///
  /// Nullable car un `DateTime` n'a **aucun constructeur `const`** : un champ
  /// non-nullable exigerait `required` (friction ctor `const`/probe/gate).
  /// Précédent `ZSmartNote.createdAt`. `date` illisible → `null`, jamais un throw.
  /// ⛔ **DISTINCTE de toute clé de sync** (`updated_at`/`is_deleted`, hors-entité).
  @ZcrudField()
  final DateTime? date;

  /// Les rappels sont-ils activés pour cet examen ? (persisté `reminder_enabled`,
  /// défaut `false`).
  @ZcrudField()
  final bool reminderEnabled;

  /// Seuils de rappel en **nombre de jours avant** l'échéance (persisté
  /// `reminder_days_before`, chemin `listScalar` **natif codegen**, défaut
  /// `const <int>[]`, **ordre préservé**).
  ///
  /// 🟡 **DW-ES24-1** : le ctor `const` ne copie pas défensivement cette liste — la
  /// dartdoc ne promet donc pas une immuabilité PROFONDE.
  @ZcrudField()
  final List<int> reminderDaysBefore;

  /// 🔴 Heure de rappel **TYPÉE** ([ZReminderTime]`?`), **CANAL HORS-CODEGEN**
  /// (D2/D3), persistée `reminder_time` en `'HH:mm'`, défaut `null`, **PAS
  /// d'annotation `@ZcrudField`**.
  ///
  /// **Pourquoi hors-codegen** : un `@ZcrudModel` subModel serait sérialisé en map
  /// `{hour, minute}`, jamais en `'HH:mm'` — or la FR-S9 exige `'HH:mm'` (compat
  /// migration). Il est donc décodé/réémis À LA MAIN (patron `ZSmartNote.content`),
  /// et sa clé [kReminderTimeKey] est **RÉSERVÉE** — sinon elle atterrirait dans
  /// [extra] **et** serait réémise en double par [toMap].
  ///
  /// 🟡 **Conséquence assumée** : un canal hors-codegen ne produit **aucun
  /// `ZFieldSpec`** ⇒ `reminderTime` n'apparaît PAS dans un formulaire
  /// `DynamicEdition` **généré** (comme `ZSmartNote.content`). L'éditeur d'examen
  /// (ES-9.2) ajoutera son champ heure **explicitement**.
  final ZReminderTime? reminderTime;

  /// Slot type additif **versionné** (AD-4 pt.1), `null` si absent. Hors-codegen.
  @override
  final ZExtension? extension;

  /// Slot `extra` **BRUT tel que reçu par le constructeur** — lu **NULLE PART**
  /// ailleurs que dans l'accesseur [extra] (ni `toMap`, ni `==`, ni `hashCode`).
  ///
  /// Il peut être **POLLUÉ** : le constructeur nominal est `const`, il ne peut
  /// appeler **aucune** fonction dans son initializer, et AD-10 INTERDIT d'y mettre
  /// un `assert`. C'est l'**ACCESSEUR** [extra] qui porte la garde — le seul point
  /// que TOUTES les voies traversent.
  final Map<String, dynamic> _extra;

  /// Échappatoire non typée (AD-4 pt.2), défaut `const {}` (jamais `null`),
  /// préservant les clés inconnues du cœur au round-trip. Hors-codegen.
  ///
  /// 🔴 **GARDE (ES-2.2b)** : l'accesseur **NORMALISE** ([zNormalizeExtra]) — il ne
  /// rend **JAMAIS** une clé réservée, **quelle que soit la voie d'écriture** (y
  /// compris le constructeur `const`, seule voie incapable de filtrer). La promesse
  /// est **INCONDITIONNELLE**, sans `assert` et sans `throw` (AD-10).
  @override
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  /// Sérialise vers la map persistée **complète** (snake_case), **zéro-perte**.
  ///
  /// Réutilise le `toMap()` **généré** (champs du schéma) puis superpose les canaux
  /// hors-codegen : [extra] (l'**ACCESSEUR** qui NORMALISE, jamais `_extra` brut),
  /// [reminderTime] sous [kReminderTimeKey] **si non `null`** (sinon clé omise,
  /// patron nullable) et [extension].
  ///
  /// ⛔ **Ne réémet NI `updated_at` NI `is_deleted`** sur TOUTES les voies
  /// ([_reservedKeys] ⊇ `ZSyncMeta.reservedKeys` ⇒ ces clés ne peuvent entrer dans
  /// [extra], donc plus en ressortir — AD-16/AD-19).
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      // 🔴 ES-2.2b — étale l'ACCESSEUR (qui NORMALISE), jamais le champ brut
      // `_extra`. Un `_sanitizeExtra(extra)` ICI serait DÉCORATIF : la garde vit à
      // l'accesseur.
      ...extra,
      ...ZExamZcrud(this).toMap(),
    };
    // 🔴 CANAL HORS-CODEGEN — réémis À LA MAIN en `'HH:mm'`. Omis si `null`
    // (round-trip idempotent : `fromMap` d'une map sans la clé rend `null`).
    if (reminderTime != null) {
      map[kReminderTimeKey] = reminderTime!.toHhmm();
    }
    // 🔴 CANAL HORS-CODEGEN (CR-IFFD-17) — omis si `null` OU vide : un slot
    // vide persisté serait indiscernable d'un slot absent au retour, et
    // `fromJsonSafe` rend `null` dans les deux cas (round-trip idempotent).
    final recurrence = reminderRecurrence;
    if (recurrence != null && !recurrence.isEmpty) {
      map[kReminderRecurrenceKey] = recurrence.toJson();
    }
    if (extension != null) {
      map['extension'] = extension!.toJson();
    }
    return map;
  }

  /// Copie **à sentinelle** (un argument omis préserve la valeur, `null` explicite
  /// le remet à `null`) — couvre **TOUS** les champs, y compris [reminderTime],
  /// [extension] et [extra], que le `copyWith` **GÉNÉRÉ** remettrait à leurs
  /// **défauts** (perte silencieuse, finding H3). Masque le `copyWith` de
  /// l'extension.
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
      // 🔴 ES-2.2b : la garde de `extra` est la MÊME FONCTION NOMMÉE qu'en
      // `fromMap` — `copyWith` ne peut plus ROUVRIR le filtre des clés réservées.
      extra: identical(extra, _$undefined)
          ? this.extra
          : _sanitizeExtra(extra as Map<String, dynamic>),
    );
  }

  // ==========================================================================
  // 🔴 Proximité d'examen — PURES, TOTALES, DÉTERMINISTES, horloge INJECTÉE (D5)
  // ==========================================================================

  /// Nombre de jours **calendaires** de [now] jusqu'à [date], ou **`null`** si
  /// [date] est `null` (méthode TOTALE, AD-10).
  ///
  /// Comparaison sur la **date normalisée en UTC** (`year/month/day`), pour éviter
  /// toute dérive DST/fuseau : `DateTime.utc(...).difference(...).inDays` est exact
  /// (aucune heure d'été en UTC). Positif = futur, négatif = passé, `0` = même jour
  /// calendaire.
  ///
  /// 🔴 `now` est un **PARAMÈTRE** : la sortie ne dépend QUE de `now` + [date]
  /// (déterministe). Aucun `DateTime.now()` — prouvé par machine (R5).
  int? daysUntil(DateTime now) {
    final d = date;
    if (d == null) return null;
    final target = DateTime.utc(d.year, d.month, d.day);
    final today = DateTime.utc(now.year, now.month, now.day);
    return target.difference(today).inDays;
  }

  /// `true` si l'examen est **strictement passé** au regard de [now] : il a une
  /// [date] **et** son jour calendaire est **antérieur** à celui de [now].
  ///
  /// `false` si [date] est `null` (rien à comparer) ou si l'échéance est
  /// aujourd'hui/à venir. Méthode TOTALE, pure, déterministe.
  bool isPast(DateTime now) {
    final delta = daysUntil(now);
    return delta != null && delta < 0;
  }

  /// `true` si un rappel est **dû** au regard de [now] : les rappels sont activés
  /// ([reminderEnabled]), l'examen a une [date], il **n'est pas passé**, et
  /// l'échéance approche sous **au moins un** des seuils [reminderDaysBefore]
  /// (`daysUntil(now) <= seuil`).
  ///
  /// Sémantique **documentée et TOTALE** : `false` si [date] est `null`, si
  /// [reminderEnabled] est `false`, ou si [reminderDaysBefore] est vide (aucun
  /// seuil ⇒ aucun rappel). Pure, déterministe.
  ///
  /// Exemple (`date` = J0, `reminderDaysBefore` = `[7, 1]`) : dû dès J-7 (le seuil
  /// 7 déclenche), reste dû à J-1 et J0, **cesse** dès J+1 (passé).
  bool isApproaching(DateTime now) {
    if (!reminderEnabled) return false;
    // CR-IFFD-17 — passe par la récurrence EFFECTIVE, jamais par les champs
    // bruts : c'est ce qui rend le modèle hebdomadaire visible à la logique
    // temporelle du socle. Auparavant, une app hebdomadaire logeait sa donnée
    // dans `extra` et cette méthode rendait TOUJOURS `false` — l'app était
    // muette vis-à-vis d'une fonction que le socle est censé porter.
    //
    // ⚠️ `date == null` ne rend plus `false` d'office : une récurrence
    // hebdomadaire est évaluable SANS échéance (c'est tout son propos). La
    // famille relative, elle, reste inévaluable — cf. `matches`.
    return effectiveReminderRecurrence.matches(now: now, dueDate: date);
  }

  /// Décode défensivement l'extension via [parser] (repli `null`, AD-4/AD-10).
  static ZExtension? _decodeExtension(
    Object? raw,
    ZExamExtensionParser? parser,
  ) {
    if (parser == null) return null;
    final map = _asStringMap(raw);
    if (map == null) return null;
    return ZExtension.guard<ZExtension?>(() => parser(map));
  }

  /// Clés persistées **RÉSERVÉES** (champs générés + `extension` +
  /// **[kReminderTimeKey]** + **clés de sync `ZSyncMeta`**) — dérivées de
  /// `$ZExamFieldSpecs` pour rester synchrones avec le codegen.
  ///
  /// 🔴 **`...ZSyncMeta.reservedKeys` est ESSENTIEL** (AD-19.1) : le store écrit
  /// `updated_at`/`is_deleted` **dans le corps** avant de passer la map à [fromMap].
  /// Sans ce spread, ces clés — propriété du store — atterriraient dans [extra]
  /// (AD-4 violé) et seraient réémises par [toMap] (AD-16 violé).
  ///
  /// 🔴 **[kReminderTimeKey] est ESSENTIEL** (D3, règle (g1)) : le canal
  /// hors-codegen étant réémis à la main par [toMap], sa clé DOIT être réservée —
  /// sinon elle atterrirait **aussi** dans [extra] et serait émise **deux fois**.

  /// 🔴 Récurrence de rappel **GÉNÉRALISÉE** (CR-IFFD-17), **CANAL HORS-CODEGEN**
  /// persisté sous la clé RÉSERVÉE [kReminderRecurrenceKey].
  ///
  /// `null` ⇒ slot **absent** : [reminderDaysBefore] fait alors seul autorité et
  /// le comportement est **exactement** celui d'avant cette CR. Une application
  /// qui n'utilise que les seuils relatifs n'a strictement rien à changer.
  ///
  /// Non-`null` ⇒ **fait autorité** et remplace [reminderDaysBefore] dans le
  /// calcul de proximité (cf. [effectiveReminderRecurrence]). C'est délibéré :
  /// additionner les deux sources ferait déclencher des rappels que l'hôte n'a
  /// pas demandés dès qu'il migre — la récurrence peut d'ailleurs porter
  /// elle-même ses `daysBefore`.
  final ZReminderRecurrence? reminderRecurrence;

  /// Récurrence réellement appliquée : [reminderRecurrence] s'il est renseigné,
  /// sinon la forme relative dérivée de [reminderDaysBefore].
  ///
  /// **Source unique** de la logique de proximité : [isApproaching] passe par
  /// ici, jamais par les champs bruts — sinon les deux modèles divergeraient
  /// silencieusement.
  ZReminderRecurrence get effectiveReminderRecurrence =>
      reminderRecurrence ?? ZReminderRecurrence.relative(reminderDaysBefore);

  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZExamFieldSpecs) spec.name,
    'extension',
    kReminderTimeKey,
    kReminderRecurrenceKey,
    ...ZSyncMeta.reservedKeys,
  };

  /// Extrait `extra` = clés **non réservées** de [map] (round-trip préservé) —
  /// **frontière d'ENTRÉE**. C'est [_sanitizeExtra], la garde **partagée**.
  static Map<String, dynamic> _extraFrom(Map<String, dynamic> map) =>
      _sanitizeExtra(map);

  /// 🔴 **LA GARDE PARTAGÉE de `extra`** (ES-2.2b) — appelée par les voies CAPABLES
  /// de filtrer : [fromMap] **et** [copyWith] (jamais divergentes — leçon H2).
  /// Délègue à [zSanitizeExtra] (`zcrud_core`, implémentation UNIQUE du repo).
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
          // Égalité PROFONDE : `extra` porte du JSON ARBITRAIRE (donc IMBRIQUÉ) —
          // une égalité superficielle casserait `fromMap(m) == fromMap(m)` dès
          // qu'une clé legacy porte une `Map`/`List` (DW-ES22-4).
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

/// Égalité **ordonnée** de deux `List<int>` (identité de `List` en Dart sinon).
bool _intListEquals(List<int> a, List<int> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Coerce défensive vers `Map<String, dynamic>` (repli `null`).
Map<String, dynamic>? _asStringMap(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) {
    return <String, dynamic>{for (final e in v.entries) '${e.key}': e.value};
  }
  return null;
}
