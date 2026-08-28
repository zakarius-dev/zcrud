# Handoff v3.27.0 — le menu qui trouve sa place, la carte qui se détache, le satellite qui relaie

> **Date** : 2026-08-28. **Portée** : `zcrud_chat`, `zcrud_chat_material`.
> **Traite** : CR-IFFD-127 (ancrage du menu, élévation de la carte) et CR-IFFD-128 (relais des
> créneaux par le composer Material).

## 1. Le menu d'artefact trouve sa place (CR-127 ❶)

**Le défaut.** Le menu s'ouvrait **toujours vers le bas** — ancrage codé en dur. Or la rangée
d'artefacts est en bas de la carte, suivie du composer : le menu recouvrait la zone de saisie et,
sur les derniers messages, sortait du viewport. Le constructeur de menu de l'hôte n'y pouvait
rien : il gouverne le contenu, pas la position de l'overlay, décidée avant qu'il ne soit appelé.

**Décision du propriétaire** : ancrage **paramétrable, adaptatif par défaut**. Trois valeurs —
`adaptive` (défaut), `below` (l'ancrage historique, à l'octet), `above`.

**La règle adaptative, et ses arbitrages** : le menu est mesuré à sa taille naturelle ; il s'ouvre
vers le bas s'il tient, vers le haut sinon ; si aucun côté ne suffit, le plus vaste l'emporte (règle
Material) — jamais sur l'ancre. **La place est mesurée dans le viewport défilable ∩ l'overlay** :
mesurer l'overlay seul aurait laissé le menu recouvrir le composer, précisément le symptôme de la
demande. Décision **synchrone**, au tap, avec les boîtes de rendu disponibles. RTL préservé par les
ancres résolues.

**Une régression attrapée par sept gardes de lots antérieurs.** Le premier jet peignait le menu
correctement, mais la boîte du suiveur ne couvrait qu'**une hauteur d'overlay** : le test de frappe
refusait les taps sous le glyphe. Sept gardes écrites pour d'autres raisons — le menu s'ouvre, une
question précède un verbe destructeur — ont rougi ensemble. **Aucune n'a été relevée** : le code a
été corrigé. C'est la valeur d'une suite qui mesure des propriétés plutôt que des structures.

## 2. La carte de message se détache du fond (CR-127 ❷)

`ZChatTileShell` portait marge, rembourrage, bordure, rayon, fond — **pas d'élévation** : une
bordure seule aplatit le fil. Livré : `elevation` et `shadowColor`, ombres à trois couches
calibrées sur la table Material, référence dans le fichier audité. **`null` ⇒ arbre identique nœud
pour nœud** : l'ombre vit dans la même décoration, aucune surface n'est intercalée pour un `null`.

## 3. Le composer Material relaie enfin ses créneaux (CR-128)

**Le défaut.** Le composer neutre porte des créneaux de remplacement ; le satellite Material —
celui que tout hôte Material monte — n'en relayait qu'**un**. Pour habiller un seul contrôle, un
hôte devait remonter le neutre et **recopier les vingt lignes de glyphes** du satellite : une copie
qu'il nommait lui-même comme dette, vouée à diverger en silence.

**Le constat était plus large que la demande.** La CR comptait neuf créneaux ; le chantier du
composer en avait ajouté huit depuis — **dix-sept**. Livrer les neuf aurait laissé l'hôte
découvrir les autres à sa prochaine tentative. Les dix-sept sont relayés, `null` par défaut,
précédence builder d'hôte > glyphe du satellite. Trois relais annexes se sont imposés à la mesure :
sans eux, deux créneaux visaient un rang jamais monté.

**La demande suggérait une pièce que l'hôte possède déjà.** La « puce d'outil optionnelle » qu'elle
propose — pour que trois hôtes ne réinventent pas la même pilule — est `ZChatComposerToolChip`,
livrée en v3.24.0 et exportée. Aucun doublon n'a été créé. Le style « pilule » reste, comme la
demande le dit elle-même, une décision d'apparence propre à chaque produit : le socle ne le
tranche pas, il laisse l'hôte le faire.

## 4. Ce qui change pour un hôte

- 🔴 **L'ancrage du menu est un changement de DÉFAUT.** Tout hôte dont un menu manquait de place en
  dessous verra son menu s'ouvrir vers le haut. Un hôte qui **compensait** — en réservant de la
  place sous la liste, ou en décalant sa rangée — retire sa compensation. `.below` rend l'ancien
  comportement à l'octet.
- **Élévation** : additive. Un hôte qui enveloppait la tuile dans une `Card` peut la retirer.
- **Relais Material** : additif. Un hôte qui avait **recopié les glyphes** retire sa copie,
  remonte `ZChatMaterialComposer`, et pose son seul builder.
- **Hôte passif** : rien ne bouge — prouvé par des gardes d'inertie en absolu, dont une rejouée
  contre le code d'avant le lot.

## 5. Vérification

Rejouée par l'orchestrateur, lots au repos.

| Paquet | Tests |
|---|---|
| `zcrud_chat` | **1 057** (1 045 + 12) |
| `zcrud_chat_material` | **113** (96 + 17) |

`melos run generate` : 0 `.g.dart` · `analyze` repo-wide : RC=0 · `verify` (12 gates) :
RC=0, avant **et** après le bump · balayage des **41 paquets** : **40 verts** (`zcrud_generator` rouge **environnemental** de signature inchangée) · résidus d'injection R3 : **0**.

**Discipline R3** : 6 + 5 + 4 injections, toutes rouges par assertion, restaurations par copie,
empreintes publiées. Un vert **justifié** : un négatif doublement défendu qu'une seule injection ne
peut atteindre — son injection sœur, elle, mord.

## 6. Un signal pour les émetteurs de demandes

Deux fois en deux jours, une demande a suggéré ou réclamé une pièce **déjà livrée** — la puce
d'outil ici, une partie du composer assemblé dans CR-125. Dans les deux cas l'hôte était à jour du
socle. La cause est la même : un saut de plusieurs versions lu sans ses handoffs. Ce document nomme
donc la pièce, son paquet et sa version, pour qu'un lecteur pressé la trouve sans chercher.
