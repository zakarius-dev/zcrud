/// Décodage **Server-Sent Events** d'un flux d'octets — `ZChatSseLine`,
/// `ZChatSseField`, [zChatSseLines].
///
/// ## Ce que cette couche fait, et rien d'autre
///
/// Un flux SSE arrive en **octets**. Entre ces octets et les événements de
/// conversation (`ZChatStreamEvent`) il y a une mécanique purement
/// transport, identique pour tous les hôtes : décoder l'UTF-8, découper en
/// lignes, reconnaître les champs du protocole (`data:`, `id:`, `event:`,
/// `retry:`), conserver les lignes vides qui séparent les événements,
/// s'arrêter sur la sentinelle `[DONE]`, et **fermer la source** quand la
/// requête est annulée. C'est cette mécanique, et elle seule, que
/// [zChatSseLines] porte.
///
/// Elle ne connaît **ni** l'URL, **ni** l'authentification, **ni** le format
/// de la charge utile : l'ouverture du POST reste à l'hôte (le socle ne tire
/// aucune bibliothèque HTTP), et l'interprétation d'une ligne de données est
/// confiée à un décodeur de l'hôte (`ZChatSseStreamPort`).
///
/// ## Tolérance (invariant AD-10)
///
/// Aucune ligne ne fait échouer le flux : un octet UTF-8 invalide est
/// remplacé (`U+FFFD`), une ligne sans champ connu est rendue telle quelle
/// sous [ZChatSseField.other], un commentaire (`:` en tête) est rendu sous
/// [ZChatSseField.comment]. Seule une **erreur de la source** (socket
/// fermé, réinitialisation) traverse, comme erreur de flux : c'est une
/// condition de transport, que l'adaptateur de port convertit en `Left`.
library;

import 'dart:async';
import 'dart:convert';

import '../../domain/ai/z_chat_request_token.dart';

/// Sentinelle de fin de flux, conventionnelle chez les fournisseurs de
/// streaming : une ligne `data: [DONE]` termine le flux **proprement**.
const String kZChatSseDoneSentinel = '[DONE]';

/// Le champ SSE porté par une ligne.
enum ZChatSseField {
  /// `data:` — une ligne de charge utile ; [ZChatSseLine.value] est le texte
  /// **sans** le préfixe (retiré une seule fois).
  data,

  /// `id:` — position de reprise ; alimente [ZChatSseLine.sequenceId] pour
  /// cette ligne et les suivantes.
  id,

  /// `event:` — nom d'événement du bloc courant, exposé, jamais interprété.
  event,

  /// `retry:` — délai de reconnexion suggéré, exposé, jamais interprété.
  retry,

  /// Ligne commençant par `:` — commentaire (battement de cœur, en général).
  comment,

  /// Ligne **vide** — séparateur d'événements. Conservée : un décodeur en a
  /// besoin pour borner un événement multi-lignes.
  blank,

  /// Toute autre ligne — champ inconnu ou ligne sans `:` — rendue
  /// **verbatim** dans [ZChatSseLine.value].
  other,
}

/// Une ligne du flux SSE, déjà décodée et classée.
///
/// Value object immuable. [sequenceId] est la **dernière** valeur de `id:`
/// vue jusqu'à cette ligne incluse (`null` tant qu'aucune n'a été émise, ou
/// après un `id:` vide) — c'est la position que l'appelant renvoie à
/// `ZChatRequestToken.resumeFrom` pour reprendre après coupure. [eventName]
/// est le dernier `event:` du **bloc courant** (réinitialisé à chaque ligne
/// vide, conformément au protocole).
class ZChatSseLine {
  /// Construit une ligne.
  const ZChatSseLine({
    required this.field,
    required this.value,
    required this.raw,
    this.sequenceId,
    this.eventName,
  });

  /// Le champ reconnu.
  final ZChatSseField field;

  /// La valeur du champ : texte sans préfixe pour [ZChatSseField.data],
  /// l'identifiant pour [ZChatSseField.id], `''` pour
  /// [ZChatSseField.blank], la ligne entière pour [ZChatSseField.other].
  final String value;

  /// La ligne **telle que reçue**, sans son terminateur.
  final String raw;

  /// Position de reprise courante, ou `null`.
  final String? sequenceId;

  /// Nom d'événement du bloc courant, ou `null`.
  final String? eventName;

  /// `true` pour une ligne de données.
  bool get isData => field == ZChatSseField.data;

  /// `true` pour un séparateur d'événements.
  bool get isBlank => field == ZChatSseField.blank;

  /// `true` pour la sentinelle de fin (`data: [DONE]`). Le flux se ferme
  /// **après** l'avoir émise : un décodeur qui veut la voir la voit.
  bool get isDone => isData && value == kZChatSseDoneSentinel;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatSseLine &&
          field == other.field &&
          value == other.value &&
          raw == other.raw &&
          sequenceId == other.sequenceId &&
          eventName == other.eventName;

  @override
  int get hashCode => Object.hash(field, value, raw, sequenceId, eventName);

  @override
  String toString() => 'ZChatSseLine(${field.name}: $value'
      '${sequenceId != null ? ', seq: $sequenceId' : ''})';
}

/// Classe une ligne brute selon le protocole SSE.
///
/// * vide ⇒ [ZChatSseField.blank] ;
/// * `:` en tête ⇒ [ZChatSseField.comment], valeur = le reste ;
/// * `<champ>:<valeur>` avec un champ connu ⇒ ce champ, **un** espace de
///   tête de la valeur retiré (`data: x` et `data:x` rendent `x` ; le préfixe
///   n'est retiré qu'une fois : `data: data: x` rend `data: x`) ;
/// * sinon ⇒ [ZChatSseField.other], valeur = la ligne entière.
///
/// Rendu sans [ZChatSseLine.sequenceId] ni [ZChatSseLine.eventName] : c'est
/// le flux ([zChatSseLines]) qui tient cet état, pas la ligne.
ZChatSseLine zChatClassifySseLine(String raw) {
  if (raw.isEmpty) {
    return ZChatSseLine(field: ZChatSseField.blank, value: '', raw: raw);
  }
  if (raw.startsWith(':')) {
    return ZChatSseLine(
      field: ZChatSseField.comment,
      value: raw.substring(1),
      raw: raw,
    );
  }
  final int colon = raw.indexOf(':');
  if (colon > 0) {
    final String name = raw.substring(0, colon);
    final ZChatSseField? field = _fieldsByName[name];
    if (field != null) {
      String value = raw.substring(colon + 1);
      if (value.startsWith(' ')) value = value.substring(1);
      return ZChatSseLine(field: field, value: value, raw: raw);
    }
  }
  return ZChatSseLine(field: ZChatSseField.other, value: raw, raw: raw);
}

const Map<String, ZChatSseField> _fieldsByName = <String, ZChatSseField>{
  'data': ZChatSseField.data,
  'id': ZChatSseField.id,
  'event': ZChatSseField.event,
  'retry': ZChatSseField.retry,
};

/// Transforme un flux d'octets SSE en flux de [ZChatSseLine].
///
/// * décodage UTF-8 **tolérant** (octets invalides remplacés, jamais une
///   erreur) ; lignes terminées par `\n`, `\r\n` ou `\r` ;
/// * les lignes vides sont **conservées** ; `data: ` est retiré **une** fois ;
/// * `id:` alimente [ZChatSseLine.sequenceId] de la ligne et des suivantes ;
///   un `id:` vide remet la position à `null` ;
/// * `data: [DONE]` est émis, puis le flux se ferme et la source est
///   **libérée** ;
/// * **annulation** : dès que [token] est annulé, l'abonnement à [bytes] est
///   annulé — **sans attendre** une ligne suivante — et le flux rendu se
///   ferme sans erreur. Annuler l'abonnement au flux rendu libère la source de
///   la même façon ;
/// * [onClose] est appelé **exactement une fois**, à la libération de la
///   source, quelle qu'en soit la cause (fin, `[DONE]`, annulation, erreur) :
///   c'est là qu'un hôte coupe ce que l'annulation de l'abonnement ne coupe
///   pas d'elle-même (un jeton d'annulation de sa bibliothèque HTTP, par
///   exemple).
///
/// Le flux rendu est à **abonnement unique** ; la source n'est ouverte
/// (écoutée) qu'à l'abonnement, et la pause est propagée.
Stream<ZChatSseLine> zChatSseLines(
  Stream<List<int>> bytes, {
  ZChatRequestToken? token,
  void Function()? onClose,
}) {
  late final StreamController<ZChatSseLine> controller;
  StreamSubscription<String>? subscription;
  String? sequenceId;
  String? eventName;
  bool released = false;

  void release() {
    if (released) return;
    released = true;
    final StreamSubscription<String>? s = subscription;
    subscription = null;
    // L'annulation de l'abonnement est ce qui coupe réellement la source
    // (un flux de réponse HTTP ferme son socket à `cancel`). `onClose` suit,
    // pour ce que l'hôte doit couper lui-même.
    unawaited(s?.cancel());
    onClose?.call();
  }

  void finish() {
    release();
    if (!controller.isClosed) unawaited(controller.close());
  }

  void onLine(String raw) {
    if (released) return;
    ZChatSseLine line = zChatClassifySseLine(raw);
    switch (line.field) {
      case ZChatSseField.id:
        // Un identifiant contenant un NUL est ignoré par le protocole ; un
        // identifiant vide remet la position à « aucune ».
        if (!line.value.contains('\u0000')) {
          sequenceId = line.value.isEmpty ? null : line.value;
        }
      case ZChatSseField.event:
        eventName = line.value.isEmpty ? null : line.value;
      case ZChatSseField.blank:
        eventName = null;
      case ZChatSseField.data:
      case ZChatSseField.retry:
      case ZChatSseField.comment:
      case ZChatSseField.other:
        break;
    }
    line = ZChatSseLine(
      field: line.field,
      value: line.value,
      raw: line.raw,
      sequenceId: sequenceId,
      eventName: line.field == ZChatSseField.blank ? null : eventName,
    );
    controller.add(line);
    if (line.isDone) finish();
  }

  controller = StreamController<ZChatSseLine>(
    onListen: () {
      if (token?.isCancelled ?? false) {
        finish();
        return;
      }
      subscription = bytes
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen(
            onLine,
            onError: (Object error, StackTrace stackTrace) {
              if (released) return;
              controller.addError(error, stackTrace);
              finish();
            },
            onDone: finish,
            cancelOnError: true,
          );
      if (token != null) {
        unawaited(token.whenCancelled.then((_) => finish()));
      }
    },
    onPause: () => subscription?.pause(),
    onResume: () => subscription?.resume(),
    onCancel: release,
  );
  return controller.stream;
}
