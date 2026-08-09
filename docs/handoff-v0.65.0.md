# Handoff **v0.65.0** — l'adaptateur Firestore des fichiers, la valeur orpheline, et 11 cascades déjà couvertes

> **Tag à épingler : `v0.65.0`**
> 🔴 **Changement visible** : une valeur sélectionnée puis absente des options ne se rend plus au
> hasard de la famille — et le **mode lecture** cesse d'afficher des identifiants bruts (§ 2), y
> compris sur des écrans **sans aucune cascade**.
> Aucune signature cassée, aucun paquet nouveau (38).

---

## 1. L'adaptateur Firestore — le bloquant de migration est complet

Le port livré en v0.64.0 a désormais son implémentation : `ZFirestoreAppFileResolver`.
Une ligne à câbler chez vous, et vos champs fichier **cessent d'afficher du vide** sur des documents
existants.

### Ce que la lecture de votre code a donné, et ce qu'elle n'a pas donné
Vos références sont des **identifiants de documents** générés côté client, dans une collection
**racine** dont le nom vient d'un repli `FIREBASE_COLLECTION_NAMES[T] ?? T.toString()` — 🔵 **il
n'existe en littéral nulle part**. Nous n'avons donc **pas** codé de convention : le chemin de
collection est **requis, sans défaut**. Le reste est paramétrable (emplacements essayés dans l'ordre,
alias de champs, mapper complet).

🔵 Et il y a **deux** champs de ce motif, pas un : `shipDocumentsIds` **et** `bondStorePhotosIds`.

**Trois assimilations refusées**, parce que chacune aurait fabriqué une donnée que la source n'a pas :
la longueur de contenu **n'est pas** une taille en octets, le chemin distant **n'est pas** un chemin
local (préservé à part), le type **n'est pas** un type MIME.

### Trois décisions, avec leur raison
| Décision | Pourquoi |
|---|---|
| **Lots de 30** | limite **mesurée** dans la version épinglée (`query.dart`), pas supposée. 200 références ⇒ 7 lots, gardés en longueurs exactes. Une sonde vérifie que le faux Firestore lève au-delà — **sans elle, la garde des 200 aurait été vacante** |
| **Un échec réseau fait échouer TOUT le lot** | une réponse partielle ferait passer 30 références pour *introuvables* — une panne déguisée en donnée manquante, c'est-à-dire le silence qu'on vient de fermer |
| **Un corps corrompu produit quand même un fichier** | le document **existe** ; un corps illisible ne doit pas se déguiser en absence |

Référence manquante ⇒ **absente** du retour (« introuvable » visible côté rendu, contrat du port) ;
doublon ⇒ dédoublonné avant la requête ; ordre ⇒ première apparition, déterministe.
`on Object` délibéré, `timeout` du port honoré. **Aucun type `cloud_firestore` ne fuit** (AD-16).

### 🔴 La ligne à vérifier chez vous
Le résolveur cherche par **identifiant de document** ; vous lisez par **champ `id`**. Chez vous les
deux coïncident (vous générez l'identifiant côté client et l'utilisez aux deux endroits), donc le
défaut fonctionne. **Un hôte dont les deux diffèrent obtiendrait de nouveau un champ vide** — il doit
déclarer l'emplacement `field('id')`. C'est une configuration d'une ligne, et nous préférons vous le
dire que vous laisser le découvrir.

## 2. 🔴 La valeur orpheline — dix voies qui divergeaient, une seule règle

**Le défaut** : une valeur sélectionnée, puis absente des options (cascade, période révolue,
population changée) se rendait **différemment selon la famille**. Le balayage a trouvé **dix** voies,
pas les deux signalées :

| Avant | Voies |
|---|---|
| **identifiant brut à l'écran** | multi chips (`select` et `relation`), **fiche de lecture** |
| **valeur effacée visuellement** | les deux dropdowns |
| **rien de coché** | radios, cases, `rowChips` |
| **placeholder anglais « Select »** | les deux modales mono |

### La règle, et pourquoi ce n'était pas un choix entre deux maux
Les deux réponses évidentes sont **toutes deux des défauts établis ici** : effacer visuellement une
valeur qui **sera soumise** est un mensonge d'affichage (famille CR-IFFD-77) ; afficher la clé
technique viole la règle inverse, déjà écrite dans le socle.

**La troisième voie dissocie présence et identité** : la valeur est **rendue à sa place**, à l'état
désactivé, sous un libellé localisé — on montre **qu'une valeur est là** sans montrer **laquelle**.

Deux mesures la fondent, et l'une renverse une prémisse :
1. le patron **existe déjà** dans le paquet (« Fichier indisponible » applique littéralement la
   règle) ;
2. 🔴 **la contrainte du dropdown n'existait pas.** Le `?: null` était commenté comme un repli imposé
   par Flutter — c'est faux : Flutter n'exige pas que la valeur soit une option **offerte**, seulement
   qu'elle figure une fois dans les items. C'est ce qui débloque la voie la plus contrainte des dix.

**Accessibilité** : l'état est porté par du **texte** (œil **et** lecteur d'écran), jamais par une
couleur, doublé du `disabled` natif. **Surchargeable par la l10n**, pas par un jeton — mesuré : aucune
chaîne de `ZcrudTheme` n'est un texte affiché, y loger un libellé créerait un canal concurrent.

🔵 **Un défaut jumeau refermé au passage** : la voie multi de `relation` affichait déjà la clé brute
**pendant le chargement**, hors de toute cascade. Rien n'est annoté tant que la source n'a pas émis.

🔴 **La donnée n'est pas touchée** — et les gardes qui l'affirment ont dû être **réordonnées** :
elles assertaient d'abord le rendu, donc sous injection de purge elles rougissaient sur le rendu et
**n'atteignaient jamais** l'assertion de valeur.

### ⚠️ Le rayon le plus large est en mode LECTURE
La fiche de lecture ne connaît que les choix **statiques**. Un champ à source dynamique y affichait
son identifiant pour **toute** valeur, et affichera désormais « option indisponible » pour toutes —
**sur des écrans sans aucune cascade**. C'est une amélioration (plus de clé technique à l'écran),
mais c'est visible : si vous voulez le libellé, la fiche a besoin d'une source résolue.

## 3. 🟢 Les 11 cascades de choix : **11 sur 11 déjà couvertes**

Un sondage avait mesuré que **11 trappes `EditionFieldTypes.widget`** de votre application sont des
cascades (options filtrées par un autre champ : agents par date, postes par type, dossiers par
statut…). Les onze ont été relues une par une **dans votre code**.

**Verdict : `ZSelectConfig.filterKeys` + `ZChoicesSource` les couvrent toutes**, y compris les cas
multi-clés et l'exclusion de soi. **Vous pouvez supprimer ces onze trappes aujourd'hui** — aucune
ligne n'a été écrite dans notre `lib/` pour cela.

🔵 **Mais la vérification a trouvé un vrai trou, ailleurs** : **la dynamique n'était gardée nulle
part.** Aucune garde ne faisait changer un `filterKey` — le mécanisme fonctionnait sans que rien ne le
prouve. Neuf gardes écrites.

**La sélection devenue invalide est CONSERVÉE**, et c'est une décision mesurée : ni votre moteur ni le
nôtre ne purge (recherches négatives des deux côtés). Le socle ne peut pas décider seul qu'un
identifiant absent de la population du jour est faux — chez vous il est souvent simplement
hors-période.
🔵 **Et ce refus garde la circularité sûre** : une dépendance `a↔b` est inoffensive **parce que
recomputer n'écrit pas**. Une purge écrirait — et refermerait la boucle.

## 4. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **DODLP** | ① câblez `ZcrudScope(appFileResolver: ZFirestoreAppFileResolver(collectionPath: …))` — vos champs fichier cessent d'être vides ② **supprimez vos 11 trappes de cascade** ③ vos écrans en **lecture** cessent d'afficher des identifiants bruts |
| **tous** | une valeur orpheline est désormais **visible et inerte**, jamais une clé. Visible surtout en **mode lecture**, y compris sans cascade |
| **hôte à présentateur riche** | **non couvert** : il reçoit les options non augmentées et rend ce qu'il veut — le lui imposer serait décider à sa place |
| **hôte passif** | rien d'autre : sans résolveur injecté, le champ fichier se comporte comme avant |

## 5. Vérification

`melos generate` **RC=0**, aucun `.g.dart` modifié · `melos analyze` **RC=0** · `melos verify`
**RC=0** — rejoués **après** le bump.

`zcrud_core` **1486** (+27) · `zcrud_firestore` **770** (+37) · `zcrud_select` 135 · `zcrud_study`
1521 · `zcrud_flashcard` 586 · `zcrud_markdown` 504 · `zcrud_intl` 183 · `zcrud_geo` 174 ·
`example` 97. **0 erreur, 0 avertissement.** Les gardes préexistantes sont passées **sans une seule
retouche**, dès le premier run.

**R3 — 27 injections**, sha **avant et après** chacune, restauration par copie, résidus : greps
négatifs montrés.

🟢 **Quatre pièges attrapés par les campagnes elles-mêmes** :
* une garde **vacante** dont le fabricant de test imposait lui-même la valeur mesurée — le défaut
  n'était donc jamais exercé ;
* une garde dont la première version **omettait un compteur** et aurait comparé `null` à `null` ;
* un **pendu** d'infrastructure et une **exception échappée**, convertis en valeurs distinctes plutôt
  que laissés en rouges d'infrastructure ;
* des gardes de donnée qui **n'atteignaient jamais leur assertion**, masquées par une assertion de
  rendu placée avant.

⚠️ **Notre CI reste à l'arrêt (facturation).** Vérifications locales uniquement.

## 6. Non couvert

* Le câblage hôte du résolveur (`ZcrudScope(appFileResolver:)`) — c'est votre geste.
* Aucun test contre un vrai Firestore : les index composites restent à confirmer au déploiement.
* La fiche de **lecture** ne résout pas les sources dynamiques (§ 2) — c'est le prochain lot naturel.
* Les hôtes à présentateur riche pour la valeur orpheline.
* Le **stepper vertical à rail numéroté** de votre CR du jour : en cours, livraison suivante.
* Dettes antérieures : cf. v0.64.0, v0.63.0, v0.62.0, v0.61.0, v0.60.0.
