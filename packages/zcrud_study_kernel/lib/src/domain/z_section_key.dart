/// `zSectionKey` — constructeur CANONIQUE et UNIQUE d'une clé de section (SU-1,
/// AC3 — AD-38).
///
/// ## Pourquoi un point de composition unique
///
/// `ZFolderContentsOrder.sectionOrders` est un **canal PERSISTÉ** (clé réservée
/// `section_orders`) : ses clés sont **déjà en base** chez les consommateurs.
/// `applyOrder` est **TOTAL** — il n'échoue jamais : une clé qui ne correspond à
/// rien est **ignorée en silence**, sans erreur, sans test rouge. Une clé
/// composée à la main qui divergerait ne serait donc **jamais détectée** ;
/// l'ordre persisté deviendrait simplement **orphelin** et l'utilisateur verrait
/// son classement « oublié » sans le moindre signal. C'est exactement le
/// `Prevents` d'AD-38, d'où : **une seule fonction compose les clés**, en
/// lecture COMME en écriture.
///
/// ## Forme canonique — RÉTRO-COMPATIBLE, à ne JAMAIS modifier
///
/// - `subfolderId == null || subfolderId.isEmpty` ⇒ **`contentType` VERBATIM**
///   (`'flashcards'` — **jamais** `'flashcards/'`, jamais `'section:flashcards'`) ;
/// - sinon ⇒ **`'<contentType>/<subfolderId>'`**.
///
/// ⚠️ **Tout préfixe, suffixe ou renommage orphelinerait SILENCIEUSEMENT l'ordre
/// déjà persisté.** Le test de rétro-compatibilité `z_section_key_test.dart`
/// verrouille ce point : il n'est pas décoratif, il protège des données réelles.
///
/// ## `contentType` est un `String` OPAQUE — jamais un enum
///
/// Les apps consommatrices (IFFD, lex_douane) apportent **leurs propres** types
/// de contenu (`'flashcards'`, `'docs'`, …). Un enum fermé casserait l'ouverture
/// AD-4 et les apps. Le kernel ne valide donc **pas** le vocabulaire : il compose.
///
/// Fonction **PURE** : déterministe, sans horloge, sans I/O (`z_kernel_purity_test`
/// et `no_datetime_now_test` s'appliquent).
library;

/// Compose la clé canonique de la section `(contentType, subfolderId)`.
///
/// **Unique** point de composition d'une clé de `sectionOrders` (AD-38) — à
/// utiliser en **lecture comme en écriture**, jamais réimplémenté à la main
/// (la garde de source `z_section_key_single_composition_test.dart` ROUGIT sinon).
///
/// - [contentType] : type de contenu **opaque**, apporté par l'app
///   (`'flashcards'`, `'docs'`…) — jamais un enum fermé (AD-4) ;
/// - [subfolderId] : sous-dossier optionnel. `null` **ou vide** ⇒ section
///   racine du type ⇒ la clé est [contentType] **VERBATIM** (rétro-compat du
///   persisté : c'est la forme déjà en base — cf. dartdoc de bibliothèque).
///
/// ```dart
/// zSectionKey(contentType: 'flashcards');                        // 'flashcards'
/// zSectionKey(contentType: 'flashcards', subfolderId: 'sub1');   // 'flashcards/sub1'
/// zSectionKey(contentType: 'flashcards', subfolderId: '');       // 'flashcards'
/// ```
String zSectionKey({required String contentType, String? subfolderId}) {
  final sub = subfolderId;
  // Dégénérescence EXPLICITE du sous-dossier vide : un `''` produirait
  // `'flashcards/'` par simple interpolation — une clé fantôme, distincte de
  // `'flashcards'`, qui orphelinerait l'ordre persisté sans aucun signal.
  if (sub == null || sub.isEmpty) return contentType;
  return '$contentType/$sub';
}
