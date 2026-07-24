# Handoff → session `lex_douane` · zcrud **v0.14.0** — apurement des CR anciennes

> **Tag à épingler : `v0.14.0`**
> Audit des CR anciennes encore ouvertes, puis livraison des cinq les plus
> structurantes. Aucune n'était neuve — certaines dormaient depuis la Story 3.2.

| CR | Sévérité | État |
|---|---|---|
| **CR-20** — contrôleur remplacé ignoré | MAJEUR | ✅ **LIVRÉE** |
| **CR-26** — méta inaccessible depuis le PORT | MAJEUR | ✅ **LIVRÉE** |
| **CR-32** — aucune surface LECTURE SEULE | MAJEUR | ✅ **LIVRÉE** |
| **CR-23** — aucun `ZFailure` ne porte un quota | MAJEUR | ✅ **LIVRÉE** |
| **CR-31** — `toMap()` émet `updated_at` | mineure | ✅ **LIVRÉE** |

📌 **Deux corrections à votre registre**, vérifiées par exécution chez nous :
**CR-25 est déjà satisfaite** (`zcrud_study_kernel` porte `ZStudyRepository` et
ne dépend que de `zcrud_core` + `zcrud_annotations` + `meta` — aucune arête de
présentation) ; **CR-37 est livrée** en `v0.13.0`.

---

## 1. CR-20 — le défaut AD-2 était chez nous

`ZMindmapOutlineEditor` capturait son contrôleur en `initState` (`late final`)
sans `didUpdateWidget` : un contrôleur **remplacé** était ignoré, l'éditeur
continuant d'écouter et de muter l'ancien — **sans erreur ni signal**.

Vérifié avant correction : `didUpdateWidget` avait **0 occurrence** dans ce
fichier. C'est exactement la classe de bug que ce socle existe pour éliminer
(objectif produit n° 1), dans l'un de nos propres widgets. Vous l'aviez vu ;
nous ne l'avions pas.

La règle de propriété est explicite et gardée : **on ne libère que ce qu'on
possède**. Un contrôleur injecté appartient à l'appelant — le libérer parce
qu'il en fournit un autre détruirait un objet dont nous n'avons pas la charge.
Passer d'injecté à `null` recrée un contrôleur possédé, sans toucher à l'ancien.

---

## 2. CR-26 — la méta est lisible depuis le PORT

```dart
final entries = await repo.getAllWithMeta();   // ZSyncEntry<T> : entité + ZSyncMeta
```

**Inclut les tombstones**, contrairement à `getAll` — c'est tout l'intérêt :
savoir qu'une entité est supprimée, et depuis quand, **est** l'information
demandée. Défaut du port : `Left` explicite, jamais une liste vide (qui serait
indiscernable de « l'utilisateur n'a rien »).

Vos **cinq réécritures du même contournement** étaient le signal qu'il manquait
au contrat, pas à vous.

---

## 3. CR-32 — la lecture seule est une surface, plus un décorateur

```dart
Future<void> migrerVague(ZReadOnlyRepository<ZStudyFolder> source) async { … }
// `save`, `softDelete`, `restore` : INEXPRIMABLES — le compilateur refuse.
```

`ZRepository` **implémente** `ZReadOnlyRepository` : aucun adaptateur n'a changé,
et tout dépôt se passe déjà là où une lecture seule est attendue. **Vous n'avez
plus de décorateur à écrire — ni à tester.**

La garde ne recopie pas une liste de membres : elle **lit le fichier source** et
vérifie qu'aucun membre d'écriture n'a rejoint l'interface, avec un contrôle
positif. Un futur `save` ajouté là ferait rougir.

---

## 4. CR-23 — `ZQuotaExceededFailure`

```dart
const ZQuotaExceededFailure('quota IA épuisé', retryAfter: Duration(minutes: 30));
```

La distinction change **ce que l'appelant doit faire** : une panne se réessaie,
un quota non. Elle était aplatie dans le `message` d'un `ZServerFailure` — vous
deviez **parser du texte** pour décider, ou traiter les deux pareil.

⚠️ `retryAfter` **absent ≠ réessayable tout de suite** : son absence est le cas
courant (peu de backends la fournissent) et ne doit jamais être lue comme une
autorisation. C'est asserté.

Au passage, une rectification à notre message de `v0.11.0` : nous vous disions
qu'il y avait **5** sous-types `ZFailure` et non 4. Il y en a **6** désormais.

---

## 5. CR-31 — le bruit disparaît, le signal reste

Corrigé **dans le générateur**, pas dans l'entité — sinon la prochaine entité
reproduirait le défaut. Deux étaient concernées (`ZStudyFolder`, `ZFlashcard`).

Un miroir de clé réservée n'est désormais émis **que s'il porte réellement une
valeur** :

| Cas | Avant | Après |
|---|---|---|
| miroir `null` (votre cas, 100 % des écritures) | clé émise ⇒ **avertissement** | clé omise ⇒ **silence** |
| miroir renseigné | clé émise ⇒ avertissement | clé émise ⇒ **avertissement conservé** |

**Nous n'avons pas retenu votre préférence** (« `toMap()` cesse d'émettre
`updated_at` ») après l'avoir essayée : elle **cassait le round-trip** d'un
miroir renseigné (nos tests de round-trip zéro-perte ont rougi). Supprimer la
clé aurait détruit une valeur réelle ; l'omettre quand elle est nulle supprime
exactement le bruit que vous avez mesuré, sans rien perdre — et **conserve
l'avertissement là où il est légitime** : une valeur métier qui *sera* écrasée
par la méta hors-entité.

Aucun test existant n'a eu à être modifié.

---

## 6. Vérification

`melos run generate` OK · `melos run analyze` RC=0 · `melos run verify` RC=0 ·
`zcrud_core` **1078/1078** · `zcrud_firestore` **726/726** · `zcrud_study_kernel`
**370/370** · `zcrud_mindmap` **191/191** · `zcrud_flashcard` **560/560**.

**14 gardes R3** prouvées mordantes — dont, pour CR-31, une mutation du
**générateur suivie d'une régénération complète** (muter le `.g.dart` seul
n'aurait rien prouvé : il est régénéré).

---

## 7. Ce qui reste OUVERT, sans faux-semblant

**CR-1** (recette de consommation git), **CR-19** (`isEphemeral` peu consulté),
**CR-21** (`deleteNode` sans confirmation), **CR-22** (pas de slot source typé
sur la génération mindmap), **CR-24** (pas de `depth`), **CR-27** (asymétrie
`Timestamp` — que vous avez mesurée **hors de votre chemin d'étude**),
**CR-28** (pas d'inventaire `$ZFooPersistedKeys`), **CR-30** (pas de fabrique
`flatTopLevel(userScoped:)`).

Nous les avons **vérifiées ouvertes**, pas oubliées. Dites-nous lesquelles
comptent pour vos prochaines stories.
