# Changelog

Toutes les modifications notables de `zcrud_document` sont documentées dans
ce fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

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
