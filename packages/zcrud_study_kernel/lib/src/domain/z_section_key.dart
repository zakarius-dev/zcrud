/// `zSectionKey` — constructeur canonique et unique d'une clé de section.
///
/// ## Pourquoi un point de composition unique
///
/// `ZFolderContentsOrder.sectionOrders` est un canal **persisté** (clé
/// réservée `section_orders`) : ses clés sont déjà en base chez les
/// consommateurs. `applyOrder` est total — il n'échoue jamais : une clé qui
/// ne correspond à rien est ignorée en silence, sans erreur, sans test
/// rouge. Une clé composée à la main qui divergerait ne serait donc jamais
/// détectée ; l'ordre persisté deviendrait simplement orphelin et
/// l'utilisateur verrait son classement « oublié » sans le moindre signal.
/// D'où une règle simple : **une seule fonction compose les clés, en
/// lecture comme en écriture.**
///
/// ## Forme canonique — rétro-compatible, à ne jamais modifier
///
/// - `subfolderId == null || subfolderId.isEmpty` ⇒ `contentType` verbatim
///   (`'flashcards'` — jamais `'flashcards/'`, jamais `'section:flashcards'`) ;
/// - sinon ⇒ `'<contentType>/<subfolderId>'`.
///
/// Tout préfixe, suffixe ou renommage orphelinerait silencieusement l'ordre
/// déjà persisté : ce point est verrouillé par un test de rétro-compatibilité
/// dédié — il n'est pas décoratif, il protège des données réelles.
///
/// ## `contentType` est un `String` opaque — jamais un enum
///
/// Les applications consommatrices apportent leurs propres types de contenu
/// (`'flashcards'`, `'docs'`, …). Un enum fermé casserait l'ouverture
/// (invariant AD-4) et ces applications. Le kernel ne valide donc pas le
/// vocabulaire : il compose.
///
/// Fonction pure : déterministe, sans horloge, sans I/O.
library;

/// Compose la clé canonique de la section `(contentType, subfolderId)`.
///
/// Unique point de composition d'une clé de `sectionOrders` — à utiliser en
/// lecture comme en écriture, jamais réimplémenté à la main.
///
/// - [contentType] : type de contenu opaque, apporté par l'application
///   (`'flashcards'`, `'docs'`…) — jamais un enum fermé (invariant AD-4) ;
/// - [subfolderId] : sous-dossier optionnel. `null` ou vide ⇒ section
///   racine du type ⇒ la clé est [contentType] verbatim (rétro-compatibilité
///   du persisté : c'est la forme déjà en base — voir la dartdoc de
///   bibliothèque).
///
/// ```dart
/// zSectionKey(contentType: 'flashcards');                        // 'flashcards'
/// zSectionKey(contentType: 'flashcards', subfolderId: 'sub1');   // 'flashcards/sub1'
/// zSectionKey(contentType: 'flashcards', subfolderId: '');       // 'flashcards'
/// ```
String zSectionKey({required String contentType, String? subfolderId}) {
  final sub = subfolderId;
  // Dégénérescence explicite du sous-dossier vide : un `''` produirait
  // `'flashcards/'` par simple interpolation — une clé fantôme, distincte de
  // `'flashcards'`, qui orphelinerait l'ordre persisté sans aucun signal.
  if (sub == null || sub.isEmpty) return contentType;
  return '$contentType/$sub';
}
