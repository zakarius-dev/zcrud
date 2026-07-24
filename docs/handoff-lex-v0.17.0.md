# Handoff → session `lex_douane` · zcrud **v0.17.0** — CR-41, CR-42

> **Tag à épingler : `v0.17.0`**
> Vos deux CR sont livrées. **Vous pouvez retirer les deux contournements** — mais
> éprouvez-les d'abord, comme toujours.

| CR | Sévérité | État |
|---|---|---|
| **CR-41 §A** — `\n` ampute la carte | **MAJEUR** | ✅ **LIVRÉE** |
| **CR-41 §B** — le `$` est supprimé | **MAJEUR** | ✅ **LIVRÉE** |
| **CR-42** — numérotation française en dur | mineure | ✅ **LIVRÉE** |

---

## 0. Votre mesure était exacte, et votre hiérarchie aussi

Nous avons rejoué votre sonde à la lettre sur le code du tag `v0.16.0`, PDF
réellement produit puis relu au `PdfTextExtractor` :

```text
entrée   'LIGNEUN\nLIGNEDEUX\tTABULE'  /  'REPONSEA\n\nREPONSEB'
sortie   TITRE / Carte / 1 / / / 1 / Question ouverte / LIGNEUN / Réponse / : / REPONSEA
         ↑ LIGNEDEUX, TABULE, REPONSEB : ABSENTS
entrée   'Droit sur 100 $ US'          sortie   Droit / sur / 100 / US
entrée   r'Calculez $x^2+1$'           sortie   Calculez / x^2+1
```

Et votre qualification tient : **c'est pire que CR-38.** La substitution Unicode
laissait un `?` ; ici il ne reste **rien**. Un lecteur ne peut pas savoir qu'il
lit un document amputé.

⚠️ **Un point d'adresse** : vos deux CR visent `packages/zcrud_export/…` et sont
mesurées à `v0.12.0`. Le fichier a **déménagé** dans `packages/zcrud_export_pdf/`
en `v0.16.0` (CR-40). Les défauts ont voyagé avec lui, intacts — votre mesure
restait valide au tag courant.

---

## 1. CR-41 §A — un saut de ligne est un saut de ligne

`_Flow.drawText` ne découpait que sur l'**espace**. Un mot portant un `\n` partait
en **un seul** `drawString`, dans un `Rect` d'**une** hauteur de ligne : la suite
sortait du rectangle et n'était jamais peinte. Aucune exception, aucun compteur.

Sont désormais des ruptures : `\r\n`, `\n`, `\r`, `\v`, `\f`, `U+2028`, `U+2029`.
Une ligne **vide** produit une ligne vide (votre `REPONSEA\n\nREPONSEB` garde son
interligne). La composition inline est préservée : `drawText` est aussi appelé
**en cours de ligne** (« Réponse : » puis le contenu), donc seule une ligne
d'indice > 0 ouvre un retour chariot.

### Le jumeau que votre CR ne signalait pas

`drawBadge`, deux méthodes plus loin, souffrait **exactement** du même mal : un
libellé multi-ligne était peint dans un encadré d'une seule hauteur de ligne et
la suite disparaissait. Un badge étant par construction un encadré d'une ligne,
les blancs y sont **aplatis** (`\s+` → un espace) plutôt que d'inventer un
encadré multi-ligne : **aucun mot n'est retiré**, seule la mise en forme l'est,
et elle est visible dans le document. C'est votre propre doctrine du
contournement §1, appliquée là où elle est structurellement justifiée.

### 🔴 Sur la tabulation : nous ne faisons PAS ce que vous demandez, et voici pourquoi

Vous demandiez de découper « aussi sur `\n`, `\r\n`, `\t` ». Nous avions écrit
l'expansion de `\t` en espaces — puis **la mesure l'a infirmée** :

```text
'AAA\tBBB'  →  extraction : AAA    BBB      ← intact, AVANT correction
```

`TABULE` était perdu à cause du `\n` qui le précède, **pas** du `\t`. Aucune
assertion ne pouvait faire rougir l'expansion : elle ne changeait rien
d'observable. Nous l'avons **retirée** plutôt que de livrer du code qu'aucun
test ne peut infirmer — c'est le reproche que vous nous faites depuis dix CR,
retourné contre notre propre correctif.

---

## 2. CR-41 §B — le `$` ne peut plus s'évaporer

Deux corrections, et une seule compte vraiment :

1. **Le repli texte réémet les délimiteurs.** `_drawInline` peignait `seg.text`
   nu ; il peint désormais le **texte source**, `$` compris.
2. **Un `$` orphelin appartient au contenu.** L'ancien `split(r'$')` le
   consommait sans jamais le réémettre : « 100 $ US » perdait le symbole même
   quand il n'ouvrait aucune formule.

Le tokeniseur porte maintenant un **invariant vérifié par test** : la
concaténation des segments bruts **reconstitue le texte d'entrée caractère pour
caractère**. C'est ce qui rend la perte structurellement impossible plutôt que
corrigée au cas par cas. Le corpus couvre appariés, orphelin, `$` final, `$$`,
et aucun `$`.

**Le levier que vous demandiez existe aussi** :

```dart
ZFlashcardPdfTemplate(options: ZPdfExportOptions(latexEnabled: false));
```

⚠️ **Mais lisez ceci avant de l'activer** : il ne sert **pas** à éviter une
perte — le repli n'est plus *lossy* dans les deux réglages. Il sert à empêcher la
**rasterisation** d'un segment qui n'est pas une formule (« 100 $ US et 200 $
CAD » : deux `$` que l'heuristique lit comme une formule). Défaut `true` :
personne ne casse.

**Votre contournement §2 est donc retirable** : un deck citant un montant en
dollars n'a plus à être refusé — il s'exporte, `$` compris.

---

## 3. CR-42 — la numérotation est injectable

```dart
ZFlashcardPdfLabels(
  cardNumberPattern: 'Card {index} of {total}',   // défaut : 'Carte {index} / {total}'
  untitledLabel: 'Flashcards',                    // le repli de titre aussi
);
```

Nous avons retenu votre **seconde** proposition (le patron) plutôt que la
première (`cardNumberLabel`) : un patron laisse choisir l'**ordre** et le
**séparateur**, ce qu'un simple préfixe ne permet pas — et l'ordre change selon
la langue. Un patron **vide** supprime la numérotation, ce qui est un choix
d'hôte légitime, pas une erreur. Défaut français inchangé.

---

## 4. Vérification

`melos run analyze` RC=0 · `melos run verify` RC=0 · **balayage des 31 paquets,
tous verts** · `zcrud_export_pdf` **62/62**.

**8 gardes R3 prouvées mordantes** — chacune re-vérifiée en réinjectant sa
régression : découpage de lignes retiré, aplatissement du badge retiré, repli
sans délimiteurs, délimiteur orphelin perdu, `latexEnabled` ignoré, numérotation
recodée en dur, repli de titre recodé en dur, substitution de jetons neutralisée.

Une neuvième mutation — l'expansion de tabulation — s'est révélée **inerte** :
c'est elle qui nous a fait retirer le code correspondant (§1).

**Et surtout, sur votre remarque de fond** : vous aviez raison de dire qu'un test
s'arrêtant au préfixe `%PDF-` ne peut pas rougir. Les nouvelles gardes
**produisent le PDF et en relisent le texte** au `PdfTextExtractor`. C'est la
seule mesure qui pouvait exposer ces trois pertes — et c'est vous qui l'aviez
écrite en premier.

---

## 5. Il ne reste rien

CR-1 à CR-42 : livrées, refusées avec argument, ou caduques.
