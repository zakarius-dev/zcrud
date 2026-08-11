# Handoff **v0.83.0** — l'aperçu géo en flux, et le registre markdown qui passe enfin ce que le widget accepte

> **Tag à épingler : `v0.83.0`** — répond aux points **A**, **B1** et **B2** de
> `cr-geo-inline-preview-and-markdown-skin`. **B3 volontairement non traité** : vous vouliez B2
> d'abord pour re-mesurer — la balle est chez vous.
> **Tout est opt-in** : défauts prouvés identiques à v0.82.0 au pixel. Aucun jeton nouveau,
> aucune arête, 39 paquets.

---

## 1. A — `ZGeoPresentation.previewWithFullscreen`

Votre diagnostic était exact et vérifié : la page plein écran est construite avec le **même
`ZFieldSpec`**, donc brider la config bridait les deux surfaces. La restriction porte désormais sur
la **présentation en flux**, jamais sur la config :

* **en flux** : en-tête (chrome si activé) + carte **pan/zoom actifs mais tap d'ajout et drags
  désarmés** + pied « N points » localisé. Ni lat/lng, ni liste de sommets, ni toolbar, ni picker ;
* **icône plein écran seulement si éditable** — en `readOnly`, l'aperçu reste, sans porte d'entrée ;
* **en plein écran** : toutes les capacités (`toolbarConfig` effectif, saisie, sommets, style,
  métriques) — la route immersive **n'hérite jamais** de la restriction d'aperçu ;
* le brouillon local et la confirmation d'abandon de G5 sont **intacts** (zéro ligne touchée).

🔵 **Le désarmement suit votre legacy à la lettre mesurée** (`gff:1668,1683`) : c'est **le tap** qui
est désarmé, pas la carte — une carte gelée n'aurait plus été un aperçu.
🔵 **Une divergence assumée envers le legacy** : son bouton plein écran est inconditionnel
(`gff:1501`) ; votre CR demandait le masquage en `readOnly` — **votre CR prime**, c'est écrit.
⚠️ Conséquence à connaître : en `preview + readOnly`, pas de consultation immersive — un hôte qui la
veut reste en `inlineEditor`.

**Votre geste** : `presentation: ZGeoPresentation.previewWithFullscreen` (cumulable avec votre
`showChrome: true`) — et retirez toute compensation de masquage si vous en aviez posé une.

## 2. B2 — `toolbarConfig` au registre… et l'inventaire complet derrière

Le constat était juste — et c'était une leçon générale : *le widget accepte* ne veut pas dire
*l'hôte peut l'atteindre*. Livré :

* `registerZMarkdownFields` expose **`toolbarConfig`** — et **`showLabel`**, un second trou que
  votre CR ne nommait pas, trouvé par l'inventaire ;
* les écartés sont **motivés** : `ctx`/`mode`/`key` (structurels), `onInit`/`onBuild` (hooks de
  test), et **`placeholder`** — l'exposer au registre aurait été un piège : le paramètre primant sur
  `field.hintText`, un littéral partagé aurait **écrasé le placeholder de chaque champ** ;
* votre règle « ce que le widget accepte, le registre doit pouvoir le passer » est désormais
  **exécutable** : une garde de parité pérenne compare les deux signatures dans la source réelle
  (commentaires strippés, exemptions justifiées, volet « exposé ⇒ transmis »). Jouée sur v0.82.0,
  elle rougit en nommant exactement `['showLabel', 'toolbarConfig']` — le trou ne se recréera pas
  au prochain paramètre.

**Votre geste** : `registerZMarkdownFields(…, toolbarConfig: ZRichTextToolbarConfig.full.copyWith(
themedBarBackground: true))` — une config fournie **remplace** le préset.

## 3. B1 — la phrase de doc

`surfaceColor` documente désormais qu'il peint aussi le corps des cartes de champ markdown
(2 lignes de dartdoc dans le cœur — seule écriture hors des deux paquets).

## 4. Vérification

`melos generate` **RC=0** (0 `.g.dart`) · `melos analyze` **RC=0** · `melos verify` **RC=0** —
rejoués **après** le bump.
`zcrud_geo` **370** (+12) · `zcrud_markdown` **569** (+5) · `zcrud_core` 1744 · `example` 108.
**0 erreur, 0 avertissement.**

**R3 — 7 injections, toutes rouges par ASSERTION** (tap réarmé, héritage immersif, gate readOnly,
aperçu gelé, défaut basculé, forwarding retiré ×2), sha avant/après, restauration par copie,
résidus par greps négatifs montrés. **Lignes de base dans les deux sens** — la garde de parité B2
est née rouge sur v0.82.0.

⚠️ **Notre CI reste à l'arrêt (facturation)** — vérifications locales uniquement.

## 5. Signalé, non fait

* **B3** : à re-mesurer côte à côte chez vous maintenant que B2 est disponible (fond de zone
  d'édition, densité de barre, permanence de la pilule).
* Dettes antérieures : cf. `v0.82.0` et les handoffs précédents.
