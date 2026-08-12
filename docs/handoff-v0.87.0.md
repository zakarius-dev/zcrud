# Handoff **v0.87.0** — la documentation devient un produit

> **Tag à épingler : `v0.87.0`** — release **documentation seule** : aucun changement de
> code dans `lib/` (prouvé mécaniquement), aucune API modifiée. 39 paquets.

---

## 1. Ce que vous gagnez

- **39 README français au gabarit unique** (Aperçu / Installation / Démarrage rapide /
  Concepts clés / API principale / Cas limites et invariants / Voir aussi) — 16 paquets
  n'en avaient aucun, 23 étaient en anglais.
- **Dartdoc réécrite orientée consommateur** sur toute l'API publique : les références de
  story internes, le journal d'epic et les comparatifs legacy ont disparu ; les invariants
  et cas limites sont conservés et cités contre une **page canonique unique**
  ([`docs/site/concepts/invariants.md`](site/concepts/invariants.md), AD-1…AD-16).
- **Un site en Markdown pur** (`docs/site/`) : accueil, démarrage rapide, 5 pages de
  concepts (ZFieldSpec, architecture hexagonale, réactivité granulaire, offline-first,
  invariants), guides (migration legacy, cookbook 11 recettes), **catalogue des 39
  paquets** avec fiche par paquet. Front-matter minimal, compatible
  Docusaurus/VitePress/MkDocs — le générateur sera choisi à part.
- `public_member_api_docs` est actif **paquet par paquet** : l'exhaustivité dartdoc est
  désormais un invariant vérifié par l'analyse, pas une promesse.

## 2. Ce que ça ne change PAS

Aucun comportement. La pureté du diff est prouvée par un gate dédié
(`melos run doc:diff-gate`) : chaque `.dart` de `lib/` est comparé à sa version de base
**après retrait des commentaires** — la campagne entière s'est faite sous ce gate, qui a
réellement mordu plusieurs fois (reformatage d'enum, corruption par script de nettoyage,
octet NUL touché — tous revertés avant commit).

## 3. Pour vos propres gardes

Nos gardes de tests qui lisent les sources **strippent désormais les commentaires**
(patron unique répliqué par paquet), à une exception près, volontaire : les **motifs de
vrais secrets restent scannés commentaires inclus**. Si vous répliquez le patron tripwire
chez vous, c'est la bonne partition.

## 4. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **tout hôte** | rien — mise à jour de tag transparente ; profitez des README/fiches |
| **DODLP (pilote)** | les nouveautés v0.86.0 (`ZDeletionSemantics`, `deletedScope`, `ZPdfHeaderSpec`, renderer liste) sont maintenant documentées en bonne place dans les README de `zcrud_firestore`/`zcrud_export_pdf`/`zcrud_list` |

## 5. Vérification

Gate DOC-1 vert sur chaque vague (jusqu'à **473 `.dart` comparés strippés** en une passe,
0 modification de code) · `melos analyze` RC=0 · `melos verify` RC=0 · suites complètes des
39 paquets rejouées (dont core 1751, study 1528, firestore 797, chat 551 — comptes
inchangés : la documentation n'a rien cassé). Greps de propreté finaux montrés dans le
commit de release.

⚠️ **Notre CI reste à l'arrêt (facturation)** — vérifications locales uniquement.
