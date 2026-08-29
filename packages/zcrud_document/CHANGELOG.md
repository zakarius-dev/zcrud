# Changelog

Toutes les modifications notables de `zcrud_document` sont documentées dans
ce fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 3.32.0 — 2026-08-29

### Garde
- **Garde de style durcie contre six écritures de couleur invisibles** (`test/z_document_style_purity_test.dart`). Le jeu de motifs du paquet était la copie exacte du jeu d'avant durcissement du patron `zcrud_core` : mesuré par injection dans `lib/`, **six formes y passaient sans un mot** — `Color(4280391411)` (entier décimal), la même en **multi-ligne**, `Color.from(red: 0.2, …)` à composantes littérales, `0x2196F3` (hexadécimal 6 chiffres hors `Color(`), `0x80112233` (alpha 50 % hors `Color(`), et un entier décimal nu dans la plage ARGB opaque. Chacune est désormais prouvée mordante, rouge **par assertion** nommant le fichier fautif.
- **Second scan sur contenu joint** : le scan ligne à ligne ne peut pas voir une forme répartie sur plusieurs lignes. Les trois motifs neufs (`Color(<décimal>)`, `Color.from(` à composante littérale, entier `42[789]…`) s'appliquent au code entier du fichier, commentaires retirés — la numérotation de ligne restant préservée, aucune forme ne se reconstitue à cheval sur une dartdoc supprimée.
- **Contre-preuves de non-faux-positif** figées par le test : masque RGB `0x00FFFFFF`, graines FNV `0x811C9DC5` / `0x01000193`, `Color.from` à composantes **calculées** (voie légitime de composition), décalage d'alpha, octets de signature de fichier. Toutes vérifiées silencieuses, avant comme après.
- **Renoncement documenté** : un hexadécimal de 8 chiffres dont l'octet de tête n'est ni `F…` ni `80` n'est pas distinguable textuellement d'un masque de bits ou d'une graine de hachage. Le coin est laissé non couvert plutôt que de rendre la garde bruyante — donc désactivable.
- **Aucun défaut exhumé** : les motifs neufs rejoués sur tout `lib/` du paquet ne désignent que `z_annotation_palette_reference.dart`, seul fichier exempté nominativement. Le durcissement est une garde pour l'avenir, sans impact sur le code livré ni sur les hôtes.

## 3.29.0 — 2026-08-28

### Ajouté
- **Palette d'annotation de référence auditée** `ZAnnotationPaletteReference` — 40 teintes (`colors`) plus une rangée compacte de 7 (`compact`), relevées teinte par teinte sur la palette d'annotation historique, avec leur `fichier:ligne` en commentaire. C'est le **seul** fichier du paquet autorisé à écrire une couleur ; les deux gardes anti-couleurs l'exemptent **nominativement par chemin exact**, et lui seul.
- **`onColor` mesuré, jamais décrété** : `ZAnnotationPaletteReference.foregroundFor` départage blanc et noir par contraste WCAG (`zContrastRatio`). Le plancher réellement atteint sur les 40 teintes est **4.58:1**, bien au-dessus des 3.0:1 exigés — recalculé par une garde, pas affirmé.
- **Chaîne de résolution totale** `zResolveAnnotationColor` : paramètre → résolveur d'hôte et rôles Material 3 → référence (profil `legacy`) → slot de `ColorScheme` indexé (profil `neutral`). Jamais nulle, jamais de levée.
- **Référence scalaire du chrome** `ZDocumentViewerReference` — hauteur de barre, taille de glyphe, côté de pastille, épaisseur de filet, rayon de panneau, plancher tactile — **sans aucune couleur** (elle n'est pas exemptée et n'a pas à l'être). Arbitrage par `zDocumentLegacyOrNeutral` : la référence sous `legacy`, la valeur historique sous `neutral`.
- **Six paramètres additifs nullables** : `ZAnnotationToolbar.swatchColors` / `.swatchSize`, `ZAnnotationPanel.swatchColors` / `.entryCornerRadius`, `ZDocumentViewerChrome.navigationBarMinHeight` / `.navigationIconSize`. Un paramètre posé l'emporte **dans les deux profils**.

### Attention
- 🔴 **Rupture voulue pour un hôte passif**, sous le profil par défaut (`legacy`) : une `colorKey` qui n'est **ni** connue du résolveur de l'hôte **ni** un rôle Material 3 (`primary`, `secondary`, `tertiary`, `error`, `neutral`) prend désormais une teinte de la palette de référence au lieu d'un rôle de `ColorScheme` indexé. Avec `ZColorPalette.defaultStudy()`, cela concerne **quatre** clés sur huit : `success`, `warning`, `danger`, `info`. Changent aussi : la pastille de `ZAnnotationToolbar` (48 → 40 dp, **la cible reste à 48**), le glyphe de navigation de `ZDocumentViewerChrome` (24 → 20 dp), le rayon d'encre d'une entrée de `ZAnnotationPanel` (aucun → 12), et l'épaisseur explicite des filets du chrome.
- **Échappatoire, une ligne** : `ZcrudScope(theme: const ZcrudTheme(referenceProfile: ZReferenceProfile.neutral), …)` restitue **exactement** l'arbre d'avant — prouvé par égalité de chaîne sur l'arbre entier, pas affirmé. Un hôte qui a déjà un `ZcrudScope` ajoute le jeton à **son** `ZcrudTheme` plutôt que d'en empiler un second.
- **Hôte ayant compensé** — celui qui posait déjà ses couleurs d'annotation à la main, par `ZcrudScope.colorKeyResolver` : **rien à faire**, son résolveur passe avant la référence. S'il veut adopter la référence, il retire son résolveur pour ces clés ; s'il la veut par paramètre, il passe `swatchColors`.

### Garde
- **Garde de style dédiée** (`z_document_style_purity_test.dart`, `@TestOn('vm')`) : aucun littéral de couleur dans **tout** `lib/` — domaine compris — hors le fichier de référence exempté. Trois contre-preuves tiennent l'exemption étroite : un chemin exempté inexistant rougit, un chemin exempté sans littéral rougit, et le même contenu placé sous un autre chemin rougit.
- La garde de couleur préexistante (`source_policy_test.dart`, AC13(d)) et la neuve consomment la **même** liste d'exemption : il n'y a pas deux listes à faire dériver.
- Les deux gardes scannent le **code**, jamais la prose : une couleur citée dans une dartdoc pour **expliquer** l'interdit ne la déclenche pas — un test le fige.
- **Inertie du profil `neutral`** mesurée par **égalité stricte de l'arbre entier** à une chaîne littérale relevée avant le lot, pour le chrome, le panneau et les huit fonds de pastille de la barre.
- Tables figées, avec leur `fichier:ligne`, pour les 40 + 7 teintes et pour les six scalaires — relevées à la main, jamais relues depuis la référence qu'elles surveillent.

## 3.28.0 — 2026-08-28

### Ajouté
- **Deux ports neutres de texte** : `ZDocumentTextExtractionPort.extract(...)` — le texte que le document porte déjà — et `ZDocumentOcrPort.recognize(...)` — la reconnaissance optique. Tous deux rendent `Future<ZResult<ZDocumentText>>` et exposent `isAvailable`. Le socle ne connaît ni format, ni moteur, ni transport : la `source` de la requête est **opaque**, le port seul la résout.
- **Valeurs immuables et comparables** `ZDocumentTextRequest` (alias `ZDocumentOcrRequest`), `ZDocumentPageText`, `ZDocumentText` : `==`/`hashCode` par valeur, `toMap`/`fromMap` **tolérants** (AD-10), collections figées. Une page illisible est sautée sans faire perdre les pages valides ; une confiance non finie retombe à `null`.
- **Ports inertes `const`** `ZInertDocumentTextExtractionPort` / `ZInertDocumentOcrPort` : indisponibles, et `Left(ZUnsupportedOperationFailure)` sur tout appel — jamais une levée, jamais un succès vide.
- **Geste « reconnaître le texte » sur `ZDocumentViewerChrome`** : `ocrPort`, `documentId`, `source`, `onTextRecognized`, `onTextRecognitionFailed`, `recognizeTextIcon`, `recognizeTextLabelKey`. Libellé résolu par `ZcrudScope.labels` via la clé exportée `kZDocumentRecognizeTextLabelKey` ; icône remplaçable ; cible tactile ≥ 48 dp ; alignement directionnel.

### Attention
- 🔴 **Un hôte qui avait ajouté SON PROPRE bouton d'OCR** dans le slot `topBar` (ou `bottomBar`) de `ZDocumentViewerChrome` en aura **deux** dès qu'il fournira aussi `ocrPort` : le sien et celui du socle. Retirer le sien, ou ne pas passer le port.
- Un hôte **passif** — qui ne fournit pas `ocrPort` — ne voit **aucun changement** : l'arbre produit est strictement identique, y compris son nombre de nœuds.

### Contrat
- L'action n'est montée **que** si un port est fourni **et** que son `isAvailable` vaut `true` ; un port indisponible n'est jamais appelé.
- `Left` ⇒ `onTextRecognized` n'est **pas** appelé ; l'échec part à `onTextRecognitionFailed`, ou à `FlutterError.onError` si l'hôte n'a pas fourni ce canal. Un port qui **lève** viole son contrat : la levée est capturée, relayée à `FlutterError` avec sa pile, puis présentée comme un `ZDomainFailure`. La coque ne propage jamais d'exception à l'arbre de widgets.
- La coque ne touche **ni** `loadState` **ni** le slot `error` : l'affichage d'un échec d'OCR reste une décision de l'hôte.

### Garde
- L'inertie du chemin passif est mesurée par **égalité stricte de l'arbre entier** à une chaîne littérale — pas par un `contains`.
- Une garde de source interdit aux deux fichiers de port de nommer Flutter, `dart:ui`, un moteur (`ml_kit`, `tesseract`, `vision`…), un plugin ou une URL.

## 3.22.0 — 2026-08-26

### Ajouté
- **Trois natures d'annotation** — souligné, barré, ondulé — en **queue** d'énumération, les natures existantes gardant leur rang. Une apparence canonique par nature, deux à deux distinctes.
- **Jeu d'outils déclarable** sur la barre d'annotation (`kinds:`).

### Attention
- 🔴 **Un hôte qui montait la barre d'annotation voit ses outils passer de deux à cinq** sans avoir touché son code. Le paramètre `kinds:` fige le jeu ; à défaut, fournir les libellés de localisation des trois natures neuves, faute de quoi les boutons afficheront les noms bruts.
- Une nature **inconnue** — d'une version future, ou d'une casse divergente — retombe sur la première valeur **sans lever**, et la valeur est **consommée**.

### Garde
- Les trois `switch` de rendu sont **exhaustifs sans `default`** : une nature future ne compile pas tant qu'elle n'a pas d'apparence.

## 3.3.1 — 2026-08-21

### Modifié — un seul calculateur de contraste dans tout le dépôt

La barre d'annotation portait un calculateur WCAG privé, bâti sur la luminance du
SDK ; elle consomme désormais celui de `zcrud_core`.

**Rendu strictement inchangé** — et mesuré, pas supposé : les deux
implémentations rendent le même nombre à **0.0 près** sur 1 257 couleurs et
5 028 couples teinte/surface, et classent tous ces couples du même côté des
planchers 3:1 et 4,5:1.

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet (absent jusqu'ici), au gabarit de la charte
  documentaire : aperçu, installation, démarrage rapide, concepts clés, API
  principale, cas limites et invariants.
- Fiche `docs/site/paquets/zcrud_document.md` (rôle, quand l'utiliser, types
  clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` (fichier créé
  — absent jusqu'ici) : l'exhaustivité de la documentation de l'API publique
  devient un invariant vérifié par l'analyse statique.
- `CHANGELOG.md` (ce fichier).

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel (domaine et présentation) : première phrase autonome, invariants
  d'architecture cités par leur nom stable (`docs/site/concepts/invariants.md`).
  Purge des références de story et d'epic, des emoji de journal, des
  codenames de remédiation internes et des comparatifs à des applications
  legacy utilisés comme justification — conservation des invariants, cas
  limites et avertissements de contrat. Aucun changement de code — la revue
  ne porte que sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_document/`.
