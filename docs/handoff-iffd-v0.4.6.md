# Handoff → session `IFFD` · zcrud **v0.4.6** — réponse à CR-IFFD-12 → CR-IFFD-16

> **Tag à épingler : `v0.4.6`**
> **Les cinq CR ouvertes sont livrées.** Aucune CR ouverte.

| CR | Sévérité | État |
|---|---|---|
| CR-IFFD-12 | mineur | ✅ **LIVRÉE** — `preserveAbsenceUnder`, côté migration uniquement |
| CR-IFFD-13 | majeur | ✅ **LIVRÉE** — `ZTextConfig.textTransform` |
| CR-IFFD-14 | majeur | ✅ **LIVRÉE** — la collision de clé réservée n'est plus muette |
| CR-IFFD-15 | majeur | ✅ **LIVRÉE** — grille multi-colonnes réordonnable, sans paquet tiers |
| CR-IFFD-16 | majeur | ✅ **LIVRÉE** — `ZStudyToolsItemCard` (voie B) |

---

## 0. Rectification d'une chose que nous avons écrite dans le handoff `v0.4.5`

Nous y disions que l'arbitrage entre « ouvrir AD-1 à un paquet tiers » et « implémenter maison »
**appartenait à l'owner** et restait à rendre. Il était **déjà rendu** — vos CR-15 et CR-16
portent l'arbitrage en toutes lettres (voie A/C et voie B, owner du 2026-07-22). Nous avons
donc annoncé comme en attente une décision qui était prise dans le document que nous lisions.

C'est la même famille de défaut que celle qui revient dans cette série : **affirmer sans avoir
vérifié**. Le fait qu'elle porte cette fois sur votre propre document ne la rend pas moins
gênante.

---

## 1. CR-IFFD-15 — grille réordonnable : livrée, et l'exclusivité disparaît

Ce que nous avions refusé en `v0.4.5` est implémenté. L'`assert` d'exclusivité est **supprimé**,
et le commentaire qui le justifiait a été réécrit — le laisser aurait fait mentir le code sur
lui-même.

```dart
ZStudyToolsSectionSpec(
  itemIds: ids,
  onReorder: (oldIndex, newIndex) => …,
  crossAxisMinItemWidth: 300,   // ✅ les deux ENSEMBLE, désormais
)
```

**Activation implicite, comme vous le demandiez** : aucun changement d'API côté hôte, la
coexistence des deux suffit.

Nouvelle primitive publique dans `zcrud_responsive` :
`ZReorderableAdaptiveGrid`. Elle **délègue** le calcul de colonnes, la gouttière, le ratio et
les replis à `ZAdaptiveGrid` / `computeCrossAxisCount` — aucun second calcul (une
réimplémentation de primitive existante a déjà été un défaut relevé ici en `v0.4.1`).

**Les trois points que nous vous avions demandé de préciser, et ce qui a été fait :**

| Point | Implémentation |
|---|---|
| Appui long | `LongPressDraggable` sur la cellule entière, sans poignée |
| Autoscroll | `onDragUpdate` → viewport `Scrollable`, pas de 24 px toutes les 16 ms, borné aux extents, arrêté sur fin/annulation/`dispose` |
| Inter-lignes | ordre **linéaire**, la grille n'est qu'une projection : déposer en position *k* ⇒ index *k* |

**Alternative accessible (AD-13)** — l'appui long est inatteignable au lecteur d'écran, comme
vous l'aviez relevé. Chaque cellule expose deux **actions sémantiques** « déplacer avant » /
« déplacer après », dont les libellés sont **injectés** :

```dart
ZStudyToolsSectionSpec(
  reorderMoveBeforeSemanticLabel: 'Move before',  // repli : 'Déplacer avant'
  reorderMoveAfterSemanticLabel:  'Move after',   // repli : 'Déplacer après'
)
```

**AD-10** — un `onReorder` qui lève **restaure l'ordre affiché** et l'exception est absorbée
(la relancer ferait crasher le rendu pendant un geste) ; un échec **asynchrone** se resynchronise
par `didUpdateWidget`.

⚠️ **Une exclusivité subsiste, et elle est documentée, pas silencieuse** : réordonner et
`crossAxisVirtualized` restent incompatibles — une cellule non construite ne peut pas être
cible de dépôt. La réordonnabilité l'emporte et le rendu est *eager*. Si vos sections sont
volumineuses, c'est un arbitrage à faire en connaissance de cause.

⚠️ **Point d'honnêteté sur AD-1** : `zReorderIds` (dans `zcrud_study`) n'est pas atteignable
depuis `zcrud_responsive` — l'arête est interdite. La primitive porte donc 7 lignes de
déplacement d'index qui lui sont propres. C'est une duplication assumée, et sa **symétrie avec
`zReorderIds` est verrouillée par un test** plutôt que laissée à la vigilance.

---

## 2. CR-IFFD-16 — carte d'item : `ZStudyToolsItemCard`

Tous les slots sont **optionnels et neutres par défaut** ; une carte réduite à son `title` rend
ce qu'un `ListTile` rendait.

```dart
ZStudyToolsItemCard(
  leading: const Icon(Icons.description_outlined),
  title: 'Cours de chimie.pdf',
  subtitle: 'Modifié hier',
  badge: const Text('PDF'),     // widget OPAQUE — le socle ne l'interprète jamais
  trailing: votreMenu,          // vos actions, vos droits
  progress: null,               // si non-null, ÉVINCE `trailing`
  onTap: () => ouvrir(doc),
)
```

**Ce que le socle apporte** : la structure, la mise en forme, et l'accessibilité **une fois pour
toutes** (cible ≥ 48 dp, `Semantics` de conteneur, RTL par `EdgeInsetsDirectional`).
**Ce qu'il ignore, et doit ignorer** : vos types d'items, vos permissions, votre nomenclature
d'extensions. Un test de frontière vérifie que le `badge` reste un widget arbitraire.

**Une décision que nous avons prise sans que vous la demandiez** : `progress` **évince**
`trailing`. Offrir des actions sur une ressource en cours de téléversement ou de conversion
invite à lancer une opération concurrente dessus. Si votre écran a besoin des deux
simultanément, dites-le — c'est réversible.

### Deux défauts que nous avons commis en écrivant cette carte

Ils valent d'être connus parce qu'ils touchent exactement ce que la CR demandait :

1. Le libellé était annoncé **deux fois** au lecteur d'écran (le conteneur *et* les textes).
2. Notre première correction — exclure **tout** le contenu de la sémantique — rendait votre
   **menu contextuel inatteignable au lecteur d'écran**. Autrement dit : retirer d'une main
   l'accessibilité que cette carte existe pour apporter.

L'exclusion est maintenant **ciblée sur les seuls libellés** ; `leading`, `badge` et `trailing`
gardent leur sémantique propre. Une garde vérifie que votre `trailing` conserve son action.
Sans elle, le défaut serait passé : notre premier test tapait le menu **au pointeur**, ce qu'un
`ExcludeSemantics` global n'empêche pas.

---

## 3. CR-IFFD-14 — la collision de clé réservée cesse d'être muette

Vous demandiez explicitement de **ne pas** toucher au contrat de clé réservée, seulement de
signaler. C'est ce qui a été fait — le contrat est **inchangé**.

```dart
final collided = ZSyncMeta.collidingReservedKeys(monEntite.toMap());
if (collided.isNotEmpty) { /* renommer, ou porter dans `extra` */ }
```

- **En debug** : `ZSyncMeta.stripReserved` journalise la collision, en nommant les clés et le
  remède.
- **En release** : `collidingReservedKeys()` permet de **vérifier avant d'écrire** plutôt que
  de découvrir la perte en production.

Traité comme une **classe** et non comme le cas `updated_at` : `is_deleted` court le même
risque, et vos hôtes futurs en auront d'autres.

---

## 4. CR-IFFD-12 — l'absence survit à la migration, sans assouplir le domaine

Votre révision était juste, et nous l'avons suivie : **aucune entité ne change de nullabilité**.
Le domaine strict reste strict. C'est la **couche de migration** qui préserve la distinction —
exactement comme `preserveLegacyUnder` préserve la granularité de `status`.

```dart
ZStudyLegacyCodec(
  preserveAbsenceUnder: {'folderId', 'title', 'storagePath'},
)
```

- **À l'aller** : tout champ déclaré qui est **manquant OU `null`** est listé dans une clé de
  survie unique `_legacy_absent_fields`. Décodée, elle retombe dans `extra` — vous y lisez la
  distinction.
- **Au retour** : `toLegacy` rend `null` aux champs marqués. **Restitution conservatrice** :
  seule une valeur devenue `''` est rendue à `null` — si l'utilisateur a renseigné le champ
  depuis, sa saisie l'emporte sur un marqueur périmé, sinon la migration écraserait une donnée
  réelle.
- **Une liste, pas N clés** : empreinte nulle sur un document complet.
- **Cumulatif entre passages** : au 2ᵉ passage le champ vaut `''` et non plus `null` ; un
  recalcul seul effacerait le marqueur au moment précis où on le relit.

> ## 🔴 RECTIFICATION (CR-IFFD-18) — NE SUIVEZ PAS LA RECOMMANDATION CI-DESSOUS
>
> Le paragraphe qui suit vous disait de retirer vos cinq contournements
> `extra['<prefixe>_<champ>']`. **C'était FAUX, et le retrait aurait détruit de la donnée en
> production, silencieusement.**
>
> `preserveAbsenceUnder` n'existe **qu'au codec** (`ZStudyLegacyCodec`) — vérifié : deux
> fichiers dans tout le dépôt, aucun dans une entité. Or vos cutovers d'entités ne construisent
> **aucun codec** : leur chemin est `entité hôte → constructeur → toMap() → store`, et il ne
> traverse jamais `toCanonical`. La sémantique est de surcroît **inverse** — le codec marque
> l'absence sur la map *legacy* (`null`/clé manquante), alors que sur la map *runtime* le champ
> vaut déjà `''` : le marqueur ne se serait jamais posé.
>
> Vous avez eu raison de ne pas nous suivre, et votre témoin positif écartait bien l'hypothèse
> d'une mauvaise configuration de votre part.
>
> **Ce qu'il faut faire à la place** : `zcrud_core` fournit désormais la même capacité **sur le
> chemin entité** (`zMarkAbsent` / `zNullFieldsOf` / `zRestoreAbsentString`, même clé de survie
> que le codec). Voir `docs/handoff-iffd-v0.5.2.md` §1. **Migrez d'abord vos documents porteurs
> du marqueur app-side** — les deux conventions ne se connaissent pas.

**Vous pouvez retirer vos cinq contournements** (`extra['<prefixe>_<champ>']` sur
`ZStudyDocument`, `ZSmartNote`, `ZFlashcard`, `ZMindmap`, `ZStudyFolder`) — mais **migrez les
documents déjà porteurs du marqueur app-side avant**, les deux conventions ne se connaissent pas.

### ⚠️ Une garde à nous qui ne mordait pas

Notre premier test d'idempotence restait **vert avec la régression injectée** : la clé de survie
était déjà préservée par un autre chemin, donc le test ne prouvait rien de ce qu'il annonçait.
Le cas qui discrimine réellement est différent — *un champ matérialisé ne doit pas faire tomber
les absences des autres* — et il a été vérifié rouge avec la régression, vert sans.

C'est la troisième fois dans cette série qu'un test vert masque une garde inerte. Votre discipline
de contre-preuve (« la garantie anti-collision dépend de l'ordre ») est ce qui l'attrape ; nous
la généralisons.

---

## 5. CR-IFFD-13 — transformation de saisie injectable

Votre révision — une primitive extensible plutôt qu'un mode `first` de plus — est retenue.

```dart
ZTextConfig(
  capitalization: ZTextCapitalization.none,
  textTransform: (s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1),
)
```

Votre contre-exemple exact est une garde : `example.com` → `Example.com` (là où `sentences`
rendait `Example.Com`).

⚠️ **Un choix de conception à connaître** : c'est une **fonction pure `String → String`**, pas
une `List<TextInputFormatter>`. `z_field_config.dart` est délibérément **sans dépendance
Flutter** — `keyboardType` y est un `String` opaque pour la même raison. Accepter des
`TextInputFormatter` y ferait entrer `flutter/services` dans le domaine (AD-1). La
transformation est appliquée **après** la capitalisation (vous avez le dernier mot), jamais sur
un mot de passe, et une transformation qui lève **ne casse pas la saisie** (AD-10, repli sur le
texte non transformé).

---

## 6. Vérification

`melos run analyze` RC=0 · `melos run verify` RC=0 (11 gates) ·
`zcrud_core` **1035/1035** · `zcrud_firestore` **697/697** · `zcrud_study` **525/525** ·
`zcrud_responsive` **117/117**.

**Rétro-compatibilité stricte** : `textTransform`, `preserveAbsenceUnder`, les libellés de
réordonnancement et tous les slots de la carte ont un défaut neutre ; `collidingReservedKeys`
est purement additif ; le comportement de `stripReserved` est **inchangé** (seule la détection
s'ajoute). Aucun paquet tiers introduit — vérifié par diff des `pubspec.yaml`.

**Preuves R3** — la régression a été injectée puis retirée, et le test a été vu rouge, pour :
l'index linéaire inter-lignes, l'ordre optimiste local, le repli AD-10 du réordonnancement, et
l'idempotence du marqueur d'absence. Nous avons rejoué nous-mêmes la première plutôt que de
nous fier au rapport de l'agent qui l'avait écrite.

---

## 7. Ce que cette série de seize CR aura produit

Elle a corrigé cinq affirmations que nous avions écrites sans les vérifier — dont deux dans nos
propres handoffs, et une dans celui-ci même (§0). Le motif est constant : **ce qui n'a pas été
exécuté n'est pas su**, et un artefact qui l'affirme quand même est un défaut à part entière,
pas une imprécision.

Continuez à éprouver par exécution. Cette livraison contient une exclusivité résiduelle
(réordonnable × virtualisé), une duplication assumée de 7 lignes, et une décision d'ergonomie
que vous n'aviez pas demandée (`progress` évince `trailing`) : les trois méritent d'être
confrontés à votre usage réel avant d'être tenus pour acquis.
