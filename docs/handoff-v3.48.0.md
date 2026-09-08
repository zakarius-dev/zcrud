# Handoff v3.48.0 — les seams de notation traversent enfin l'assemblage

Origine : une demande mesurée par une application hôte dans le pub-cache résolu de
v3.47.0. Elle a deux volets — un relais manquant, et une question de doctrine posée
honnêtement, à laquelle elle demandait une **réponse écrite** plutôt qu'un arbitrage.
Les deux constats ont été vérifiés sur disque avant traitement ; les deux étaient exacts.

## Clés de schéma ajoutées

**Aucune.** Aucune entité persistée n'est touchée ; aucune migration n'est requise.

## Le relais manquant

`ZSrsQualityButtons` — la rangée des paliers de notation — expose des seams de
personnalisation : couleur par cran, clé de libellé, aperçu d'intervalle (« ↺ 1 j »),
emphase. **Aucun n'était relayé par l'assemblage.** Le site de montage ne passait que
l'échelle, le seuil, le cran suggéré et le rappel de notation.

Conséquence, et la formulation de l'hôte était juste : la seule voie ouverte était de
fournir `gradingBuilder` — donc de **réimplémenter la saisie entière** (champ de réponse,
choix, correction, indices, évaluation, soumission) pour changer la couleur de cinq
boutons. Notre propre documentation dit pourtant que « la saisie **est** la session ».

Livré : quatre paramètres additifs, à défaut neutre, relayés de bout en bout —
`qualityLabelKeyFor`, `qualityColorKeyFor`, `qualityPreviewLabelFor`, `qualityEmphasis`.

🔴 **Et un défaut plus grave, que la demande ne pouvait pas voir.** La rangée de paliers
n'est montée que si un rappel de sélection est fourni — et l'assemblage n'en fournissait
**aucun** : au tag précédent, `onQualitySelected` n'apparaissait nulle part dans
`ZStudySessionHost`. **La rangée que ces seams peignent n'entrait donc jamais dans
l'arbre de l'assemblage.** Relayer les quatre seams seuls aurait livré quatre commandes
mortes, et la demande aurait été close sans rien changer à l'écran.

`ZStudySessionHost.onQualitySelected` est donc livré avec eux. Défaut `null` ⇒ rangée
absente, comme aujourd'hui (AD-4). Ce rappel **notifie, il n'écrit rien** : la voie
d'écriture SRS reste unique et inchangée (AD-9/AD-33), vérifié par compteur avant et
après un appui.

⚠️ La demande en nommait **trois** ; il y en avait **quatre**. `labelKeyFor` relevait de
la même classe de défaut et n'avait pas été repéré. Une demande qui cite trois symptômes
désigne souvent une famille entière.

**Ce qui n'est délibérément PAS relayé**, et pourquoi — c'est une réponse, pas un oubli :
- `scale` et `passThreshold` sont dérivés de la configuration SRS. Les exposer créerait
  une **seconde source d'échelle**, qui divergerait silencieusement du planificateur ;
- `selectedQuality` est la suggestion issue de la correction, pas un réglage de style ;
- `onQualitySelected` est déjà exposé — c'est la voie unique de notation ;
- `bottomInset` : la surface possède déjà le sien et le **consomme** ; un second inset
  imbriqué rendrait la gouttière double que la version précédente venait de supprimer.

**Aucune valeur chromatique n'entre dans le socle** : ce sont des seams de *clé*, traduits
en couleurs par le résolveur de l'application.

### Ce que vous écrivez chez vous

```dart
ZFlashcardAnswerInput(
  card: card, mode: mode, srsConfig: srsConfig,
  onQualitySelected: (q) => engine.grade(q),
  qualityColorKeyFor: (q) => switch (q) {          // clés de VOTRE palette
    0 || 1 => 'palierEncore', 2 => 'palierDur',
    3 => 'palierBien', 4 => 'palierFacile', _ => 'palierParfait',
  },
  qualityLabelKeyFor: (q) => 'app.srs.palier.$q',  // clés l10n de VOTRE application
  qualityPreviewLabelFor: (q) => '↺ ${scheduler.simulate(info, q).intervalDays} j',
  qualityEmphasis: const ZSrsQualityEmphasis(
    fillOpacity: 0.14, selectedFillOpacity: 0.30,
    borderWidth: 1.5, selectedBorderWidth: 2.5,
  ),
)
```

Les clés de couleur passent par votre `ZcrudScope.colorKeyResolver`, les libellés par
`ZcrudScope.labels`. **`gradingBuilder` n'est plus nécessaire pour ce besoin.**

- **Application passive** : rien à faire, arbre et couleurs identiques.
- **Application ayant CONTOURNÉ** par un `gradingBuilder` écrit *uniquement* pour
  recolorer les paliers : **retirez-le** et posez les quatre seams — vous récupérez au
  passage la correction, les indices et l'évaluation que votre réimplémentation devait
  porter. Le moyen de le vérifier vous-même : votre test affirmant que les paliers du
  socle sont neutres doit **rougir** une fois les seams posés ; s'il reste vert, le
  `gradingBuilder` est encore en place et masque le relais.
- Un `gradingBuilder` qui rend **autre chose** qu'une rangée de paliers est une
  **décision** : gardez-le. Les seams ne s'y appliquent pas — c'est vous qui rendez.

## La question de doctrine, et sa réponse

La demande relève que les jetons de session sont **sept, et tous géométriques**
(`stackFlex`, `inputFlex`, `contentPadding`, `dividerThickness`, `sectionGap`,
`minTarget`, `counterStyle`) : aucun jeton de couleur, de forme, d'élévation ou de
dégradé. Le relevé est **exact**. La question posée : est-ce le contrat voulu — « le
socle donne la structure, l'application donne la peau, et la peau se peint par créneaux »
— ou manque-t-il une famille de jetons de session ?

**Réponse : ni l'un ni l'autre. La peau n'est pas réservée aux créneaux, et la doctrine
existe déjà — elle n'avait simplement pas été appliquée à la session.**

Le patron du socle est **référence auditée → jeton nullable → seam**, avec la priorité
`paramètre > jeton > référence`. Il tourne déjà ailleurs : la carte de flashcard porte
quatre dégradés typés dans un fichier de référence audité, exposés par le jeton
`ZcrudTheme.flashcardTypeGradients`, puis surchargeables par seam. Une identité visuelle
typée — liseré par type de carte, badge d'indice, pastille de consigne — est donc
atteignable **sans réimplémentation** : elle passe par ce patron, pas par un créneau.

Ce qui manquait à la session n'était pas une doctrine, c'était son application. Cette
version en livre le premier maillon pour les paliers.

⚠️ **Ce que le socle ne fera pas** : poser une palette de paliers **par défaut**. La
direction retenue est que le socle ne reproduise pas au pixel près l'identité d'une
application particulière. Les couleurs typées restent donc **offertes par jeton, jamais
imposées** — un socle qui livrerait la palette d'un hôte l'imposerait à tous les autres.

Si vous voulez l'inverse — une palette de paliers livrée par défaut, que chacun
surcharge — c'est une décision de produit, et elle se demande explicitement.

## Vérification, rejouée au repos

`zcrud_session` : 0 error / 0 warning, **673 tests verts**. `zcrud_study` : 0 error /
0 warning, **1992 tests verts** en 53 s. Aucune valeur chromatique introduite dans les
deux paquets (FR-26). Aucun résidu d'injection R3.

Les gardes ont été posées sous discipline R3 — rouge **par assertion**, restauration par
copie de fichier, sha256 publiés, résidus prouvés par grep négatif. Elles mesurent la
**couleur peinte et le libellé rendu**, jamais le passage du paramètre : un seam peut
être transmis et ne rien produire.

Deux pièges de méthode ont été payés et corrigés en cours de route, ils valent d'être
connus : un harnais de test qui énonce un paramètre à sa valeur neutre **court-circuite
le défaut du constructeur**, et l'inertie ne mesure alors plus rien ; et une garde restée
verte sous injection ne prouve pas sa solidité — elle indique qu'elle regarde ailleurs.
