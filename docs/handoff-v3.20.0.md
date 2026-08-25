# Handoff v3.20.0 — le résumé d'un `select` multiple ne mange plus l'écran

> **Date** : 2026-08-25. **Portée** : `zcrud_core`, `zcrud_select`. **Traite** : CR-IFFD-112.
> CR-IFFD-113 a été **retirée par l'hôte avant émission** : le canal qu'elle allait demander
> existait déjà (la famille `boolean` consulte le registre de widgets avant son rendu natif).

## 1. Le défaut

Le déclencheur d'un `select` **multiple** affichait **toutes** les valeurs sélectionnées. Une
matrice d'autorisations en porte couramment quinze : la tuile s'étirait sur un demi-écran et
**poussait hors de vue les champs suivants**. Le compte lui-même se perdait — « treize étiquettes »
ne se lit pas, « +10 autres » se lit.

Vérifié avant délégation : `ZSelectPresentation` porte treize champs, **aucun** pour le déclencheur ;
les huit jetons `select*` habillent la tuile et le modal, jamais le résumé des valeurs ; et le
présentateur passe la totalité des titres au rendu.

## 2. Ce que le socle livre

**Un palier de coupure et les jetons de forme** : `selectSummaryMaxChips`, plus les jetons de
rembourrage, de rayon et de typographie de l'étiquette. Au-delà du palier, une ligne « +N … »
remplace les valeurs restantes. **Un palier non positif signifie « aucune coupure »** — c'est
l'échappatoire documentée, et elle ne lève pas (AD-10).

**Une clé de localisation** pour le débordement, servie dans les deux tables. Aucun moteur de
substitution n'a été introduit : la clé porte un **fragment suffixe**, composé comme les clés à
quantité déjà en place. Le libellé ne peut donc pas être un littéral.

🔴 **La coupure est ACTIVE PAR DÉFAUT**, au palier de trois — la valeur du legacy. C'est un
changement de rendu voulu, et il concerne **tous** les hôtes, y compris ceux qui n'ont rien demandé.
Un hôte qui veut son affichage intégral pose un palier non positif, en une ligne.

## 3. Ce qui change pour un hôte

- **Hôte affichant plus de trois valeurs dans un `select` multiple** : son résumé est désormais
  coupé. C'est l'objet même de la version.
- **Hôte qui compensait** (troncature maison, hauteur forcée sur la tuile) : **retirer la
  compensation**, sinon les deux coupures se cumulent.
- **Hôte réglant ses puces par `ThemeData.chipTheme`** : ce canal ne porte plus sur le résumé. Le
  résumé n'est plus rendu par une puce Material mais par une **étiquette compacte** — une étiquette
  de résumé n'est pas actionnable, elle n'a donc pas à porter le plancher tactile de 48 dp qu'imposait
  la puce ; treize valeurs occupaient 268 dp de hauteur. Les jetons de forme prennent le relais.
- **L'annonce accessible ne perd rien** : elle porte toujours la **totalité** des valeurs, coupure ou
  non. La coupure est une accommodation de hauteur, dont une annonce audio ne consomme aucune ; et la
  ligne « +N » vit sous exclusion sémantique, si bien qu'un lecteur d'écran tronqué n'aurait eu ni la
  donnée ni l'indice. Le legacy n'exposait aucune sémantique sur ce déclencheur : il n'y avait rien à
  imiter, la règle est tranchée sur l'invariant.

## 4. Ce que la mesure a corrigé dans la CR elle-même

- **« Le dégradé du chip est déjà servi par le résolveur » est faux.** Aucune occurrence de dégradé
  dans tout `zcrud_select` : le résolveur ne sert que l'ornement de tête, et sous forme de couleur
  normalisée, jamais d'un dégradé peint. Le point n'a pas été traité, et le chemin exact qui manque
  est décrit dans le rapport de lot plutôt que promis ici.
- **Une valeur de référence était fausse** : l'espacement inter-rangées valait 4 là où la source
  héritée pose 6. Corrigée — avec les deux gardes qui assertaient consciencieusement l'erreur.

## 5. Vérification

Rejouée par l'orchestrateur, lot au repos.

| Contrôle | Résultat |
|---|---|
| `zcrud_core` | **2 544 tests verts** |
| `zcrud_select` | **169 tests verts** |
| Paquets dont les gardes lisent ces sources (`chat_kernel`, `chat_syncfusion`, `firestore`, `get`, `study`) | verts |
| `melos run generate` | SUCCESS — 0 `.g.dart` modifié |
| `melos run analyze` repo-wide | RC=0 |
| `melos run verify` (12 gates) | RC=0, avant **et** après le bump |
| Balayage des **41 paquets** | **40 verts** ; `zcrud_generator` rouge **environnemental** de signature inchangée |
| Résidus d'injection R3 | **0** |

**Discipline R3** : 15 injections, 15 rouges **par assertion**, restauration par copie, sha256
identiques, grep négatif montré.

## 6. Un défaut mesuré pendant cette version, corrigé dans la suivante

`ZRichTextToolbarConfig.themedBarBackground` est **inerte** en affichage sur une seule ligne :
basculer le drapeau change **0 pixel sur 1 823 500**. Quill peint son propre conteneur, aux bornes
exactes de la décoration posée par le socle et **après** elle — fond et liseré compris. Or la barre
en flux est **toujours** en une ligne, et **les deux applications hôtes posent ce drapeau** : elles
configurent aujourd'hui quelque chose qui n'a aucun effet. Les sept tests qui citent le drapeau
montent un carré de 10 dp à la place de la vraie barre — ils resteraient verts si le défaut
persistait. Correctif et garde asserttant un **pixel** : version suivante.
