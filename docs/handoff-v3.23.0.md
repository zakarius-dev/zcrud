# Handoff v3.23.0 — ce qui se voit, et ce qui reste visible quand le clavier monte

> **Date** : 2026-08-26. **Portée** : `zcrud_core`, `zcrud_navigation`, `zcrud_get`, plus la
> recette de consommation et son gate.
> **Traite** : CR-IFFD-121 ② · CR-IFFD-122 · la première CR de **DLCFTI** (recette périmée).

## 1. Un champ en lecture seule se voit enfin (CR-IFFD-121 ②)

**Le défaut.** `ZFieldSpec.readOnly` **agissait** — le champ n'était pas éditable — mais **ne se
voyait pas** : rendu comme un champ de saisie ordinaire. Le symptôme, mesuré au doigt sur appareil :
le champ prend le focus, la bordure passe au bleu de focus, **et le clavier ne s'ouvre pas**. Rien
ne l'annonce. Un champ non éditable qui ressemble à un champ éditable est un mensonge d'interface :
l'utilisateur tape, rien ne se passe, et il ne sait pas si l'application est bloquée ou s'il s'y
prend mal.

**La capacité existait déjà** — la fiche de consultation et ses six jetons — mais sous une condition
**globale** : un formulaire entier en lecture obtenait les fiches, un champ seul non. Il manquait un
second déclencheur, pas une capacité.

**Deux découvertes en cours de lot, chacune évitant une livraison fausse** :
- La première version traitait un mode lecture explicitement faux comme un **veto**. Or le moteur
  d'édition, le stepper et la sous-liste passent tous ce mode à chaque champ : le déclencheur aurait
  été **inerte partout**. Une garde l'a arrêté au premier rouge.
- En consultation, le moteur rabat la lecture seule sur la spec **effective** de chaque champ : la
  spec ne dit alors plus si le verrou vient du schéma ou de la surface. Sans la clause ajoutée, un
  mode lecture explicitement faux aurait cessé de primer sur un scope ambiant. C'est une garde d'un
  autre chantier qui l'a signalé.

**L'échappatoire est argumentée par élimination** : ni un jeton de thème — la décision se prend au
montage, où le thème n'est pas lisible, le jeton serait donc mort pour un hôte passant par une
extension de thème — ni le scope de lecture, que chaque formulaire re-pose et qui masquerait un
réglage racine.

## 2. La feuille d'édition réserve la place du clavier (CR-IFFD-122)

**Le défaut**, constaté par la QA sur appareil : le champ qui prend le focus passe **sous le
clavier**, le défilement ne le ramène pas, on saisit à l'aveugle — et le message de validation est
invisible lui aussi. Comme la feuille est le défaut adaptatif sur mobile, **tout formulaire mobile
était concerné**.

**Le savoir-faire existait cinq fois dans le dépôt** — choisir dans une liste, piquer une relation,
éditer un élément de sous-liste, éditer des flashcards — et manquait au seul endroit où l'on tape le
plus.

**La voie proposée par la demande ne résolvait rien, et la mesure l'a établi** : retrancher l'encart
de la hauteur maximale est **inerte**, parce que la feuille est ancrée au bas de l'écran entier —
une feuille plus courte reste sous le clavier. Cumuler les deux voies compte l'encart **deux fois**
(débordement de 224 px mesuré). Seul le rembourrage du corps résout le cas : le champ passe de
`y=736` à `y=436` sous un clavier de 300.

🔴 **Le nœud est inconditionnel, et c'est le cœur du correctif.** La variante évidente — ne
rembourrer que si l'encart n'est pas nul — est géométriquement correcte **et détruit la saisie** :
le champ est reconstruit et le texte déjà tapé disparaît. Le prix est de deux lignes dans l'arbre de
la seule voie feuille.

**Un second paquet a été mesuré, puis épargné** : le présentateur GetX a la même forme apparente
mais **pas le défaut** — son châssis borne déjà la feuille aux encarts près. La réservation y a été
posée, mesurée **nuisible** (zone utile 288 → 200 dp), puis retirée ; une garde interdit le double
comptage.

## 3. La recette de consommation ne peut plus dériver (CR de DLCFTI)

**Le défaut, signalé par un primo-intégrant.** La recette épinglait `v0.14.0` (6 fois) et `v0.18.0`
(41 fois) alors que le dépôt était à `v3.22.0`, et annonçait 38 paquets là où il y en a 41. Un hôte
qui recopie ce bloc obtient **ce socle-là**, et rien ne l'en avertit : la résolution réussit, le code
compile, les écrans s'affichent. Il découvre l'écart en cherchant un symbole documenté dans un
handoff récent que le barrel n'exporte pas.

**Le document n'était pas oublié** : il a été relu, amendé et corrigé **deux fois sur son
mécanisme** par deux CR antérieures — pendant que ses valeurs dérivaient de trois majeures. Ce n'est
pas un fichier mort, c'est un fichier vivant **dont une dimension n'était gardée par rien**.

**Le gate de recette vérifiait la présence des paquets, jamais la valeur des tags.** Il exige
désormais que tous les `ref:` valent la version de `zcrud_core` — la version du `pubspec` et non le
dernier tag git, parce que pendant une publication le bump précède le tag, et un gate calé sur le
tag refuserait précisément la version qu'on publie.

## 4. Ce qui change pour un hôte

- 🔴 **Lecture seule** : un hôte qui déclarait `readOnly` comme simple **verrou fonctionnel** verra
  son rendu changer — bordure, libellé flottant et ornements cèdent la place à la fiche, mot de
  passe compris. Remède en une ligne : `ZcrudScope(readOnlyFieldsAsCards: false)`.
- 🔴 **Clavier** : un hôte qui compensait par son propre rembourrage doit le **retirer**, sinon la
  réservation est double. Un `maxHeight` posé reste prioritaire et borne la feuille entière : un
  corps défilable est recommandé. Sous GetX : **rien à faire, et surtout rien à ajouter**.
- **Recette** : tout hôte doit vérifier la valeur de son `ref:`. Un socle antérieur à `v3.10` n'a
  aucun des canaux livrés depuis, et son absence est silencieuse.

## 5. Vérification

Rejouée par l'orchestrateur, lots au repos.

| Paquet | Tests |
|---|---|
| `zcrud_core` | **2 561** |
| `zcrud_navigation` | **197** |
| `zcrud_get` | **153** |

`melos run generate` : 0 `.g.dart` · `melos run analyze` repo-wide : RC=0 · `melos run verify`
(12 gates, dont le gate de recette étendu) : RC=0 · balayage des **41 paquets** : **40 verts** (`zcrud_generator` rouge **environnemental** de signature inchangée) ·
résidus d'injection R3 : **0**.

**Discipline R3** : gate de recette prouvé mordant (`RC=1` sur un tag périmé, `RC=0` après
restauration, sha256 identique) ; 7 injections pour le clavier, toutes rouges par assertion, avec
une **discrimination nette** — l'injection « nœud conditionnel » ne rougit que la garde de saisie,
l'injection « avant-lot » rougit les gardes d'effet et laisse l'inertie verte.

## 6. Ce qui reste ouvert, et dit franchement

- Sur les familles que la fiche de consultation ne couvre pas, l'écart entre l'état d'un champ et son
  apparence **subsiste** : il faudrait un lecteur par famille.
- Un corps **non défilable** sous une hauteur maximale serrée reste un cas non traité — il relève du
  réglage d'ajustement du corps, pas du défilement.
- Une injection R3 du lot de lecture seule s'est révélée **inerte**, l'état dérivé ne repassant pas
  par la reconstruction visée : elle a été rejetée et remplacée, pas comptée comme une preuve.
