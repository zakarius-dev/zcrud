# Changelog

Format « Keep a Changelog » (sections Ajouté / Modifié / Corrigé, versions
antéchronologiques). Toutes les modifications notables de `zcrud_ui_kit`
sont documentées ici.

## 2.4.0 — 2026-08-17

### Modifié

#### Le titre d'une confirmation devient optionnel

`showZConfirmDialog` et `ZConfirmDialog` imposaient un `title`. La confirmation
du moteur legacy n'en affichait **aucun** — son titre était explicitement
**commenté** dans le source. Un hôte portant ses gestes destructifs devait donc
**inventer** des libellés que rien ne permet de vérifier contre une référence, le
message portant déjà la question en entier.

Le coût réel n'était pas le bruit visuel mais la **localisation** : dans un module
traduit en dix langues sans clé de titre générique, les seules issues étaient une
chaîne en dur, dix fichiers à modifier pour un mot jamais affiché, ou le
détournement d'une clé voisine.

`title: null` ⇒ **aucun `AlertDialog.title` dans l'arbre** — pas un titre vide,
pas un `SizedBox`, et **surtout aucun défaut inventé par le socle** : un socle qui
invente un titre recrée le même problème un étage plus bas, et l'hôte ne saurait
pas le retirer. Sans titre, le dialogue reste correctement annoncé (route nommée
et cadrée).

**Rétrocompatibilité totale** : tout appelant passant un titre garde exactement le
rendu actuel.

## 0.93.0 — 2026-08-13

### Ajouté

- **`ZCountBadge`** — pastille de comptage réutilisable : seule, ou posée sur un
  contenu (icône de barre, avatar). Le nombre est **annoncé**
  (`semanticsLabel` nomme ce qui est compté), la cible tactile passe à **48 dp**
  dès que la pastille est cliquable, le placement est **directionnel**
  (bascule en RTL) et toutes les couleurs sont dérivées du `ColorScheme` —
  aucune valeur littérale. Zéro n'affiche rien (`showZero` pour l'imposer), et
  les grands nombres sont écrêtés à l'affichage (`99+`) sans altérer l'annonce.

### Modifié

- Chantier documentation : README réécrit au gabarit du monorepo, dartdoc de
  l'API publique normalisée (orientée consommateur), fiche `docs/site/paquets/`
  ajoutée, `public_member_api_docs` activé.

Historique antérieur : voir `git log` sur `packages/zcrud_ui_kit/`.
