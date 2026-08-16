# Handoff **v1.6.0** — l'écran assemblé peut porter la navigation de l'application

> **Tag à épingler : `v1.6.0`** — traite le CR « l'écran assemblé ne peut pas porter la navigation
> de l'application ». Paquet porteur : **`zcrud_screen`** uniquement.
> Release **strictement additive** : un écran qui ne déclare rien est inchangé.
>
> 🔴 **Vous avez compensé** : votre `Scaffold` imbriqué doit être retiré, sinon le relais reste
> sans effet — §4.

---

## 1. Le manque

`ZPageScaffold` acceptait `drawer` et `endDrawer` et les passait à son `Scaffold`. `ZCrudScreen`
**ne les exposait pas** : `grep -rn "drawer" packages/zcrud_screen/lib/` rendait RC=1, aucune
occurrence.

Vous nommez le motif mieux que nous ne l'aurions fait : *le socle sait faire, l'écran ne relaie
pas*. C'est le troisième CR de suite sur ce patron, et c'est un signal que nous prenons — un
assemblage qui masque une capacité de sa propre brique est un assemblage incomplet, pas un
assemblage protecteur.

## 2. Ce qui est livré

`ZCrudScreen.drawer` et `ZCrudScreen.endDrawer`, relayés **tels quels**. Défaut `null` ⇒
comportement strictement inchangé (votre critère n°2).

**Aux deux surfaces, pas une seule.** `ZCrudScreen` monte un `ZPageScaffold` à deux endroits : la
coquille nominale et l'écran **« accès refusé »**. Votre CR ne voyait que le premier. Le second
est pourtant le pire cas : un refus d'ACL rendait un écran **sans contenu *et* sans navigation**,
l'usager n'ayant même plus de liste à laquelle se raccrocher. Les deux sont couverts, et deux
gardes distinctes le prouvent — l'injection qui neutralise le seul site « accès refusé » fait
rougir cette garde-là et elle seule.

**Le bouton d'ouverture n'est pas réimplémenté** : il est inséré par Material
(`automaticallyImplyLeading`). Votre critère n°4 — un `leading` hôte prime sur le bouton de menu —
est donc satisfait par construction, et gardé plutôt que codé.

## 3. Une interaction tranchée d'avance plutôt que découverte en recette

En **vue corbeille**, le socle impose un bouton de retour, qui occupe le `leading`. Material
n'insère alors pas le bouton de menu.

Décision : **on garde**. Sortir de la corbeille prime sur changer de module, et retirer ce bouton
casserait un contrat existant. Le tiroir reste ouvrable **par glissement depuis le bord**, et le
bouton de menu **revient** au retour aux vivants — les deux propriétés sont assertées, pas
supposées.

## 4. ⚠️ Impact sur votre code

- **Hôte passif** : rien à faire.
- **Vous, hôte ayant compensé** : votre contournement du §5 — `Scaffold` imbriqué,
  `GlobalKey<ScaffoldState>`, `leading` détourné pour ouvrir le menu — doit être **retiré**. Ce
  n'est pas facultatif : tant que votre `leading` est déclaré, **il prime**, et Material n'insère
  pas le bouton du tiroir désormais relayé. Vous obtiendriez le relais sans son bouton, et
  concluriez que la livraison ne marche pas.
  Geste : supprimer le `Scaffold` externe et le `GlobalKey`, supprimer le `leading` détourné,
  passer `drawer: monMenuLateral` à `ZCrudScreen`.

## 5. Deux points de votre CR, pour l'exactitude

- **Inexact, sans conséquence** : vous citez `floatingActionButton` parmi les paramètres exposés.
  Il n'existe nulle part dans `zcrud_screen` (grep RC=1). Le compte, lui, était juste : 48 avant,
  50 après.
- **Non traité, et dit comme tel** : le troisième symptôme de votre §2 — *« le retour Android
  quitte l'application »* — ne relève pas de ce relais. C'est le routage de votre application (la
  route est restaurée au démarrage, sans pile derrière elle) ; le tiroir ne le corrigera pas. Nous
  le signalons pour que la recette ne l'attribue pas à cette livraison.

## 6. Périmètre volontairement tenu

Vous proposiez d'étendre le même relais à `bottomNavigationBar` et `persistentFooterButtons`, tout
en écrivant « nous n'en avons besoin d'aucun aujourd'hui ». Nous ne les avons **pas** livrés :
chaque paramètre est de la surface d'API pour toujours, et une garde ne prouvant qu'un passe-plat
dont personne n'a l'usage serait proche de la tautologie. Le geste restera d'une ligne le jour où
vous les demanderez.

## 7. État des vérifications

`melos run generate` RC=0 (zéro `.g.dart` modifié) · `melos run verify` RC=0 (14 gates,
40 paquets) · `zcrud_screen` analyze **No issues found**, **298** tests (baseline 288, +10).
`zcrud_core` non touché, donc non rejoué.

Six injections R3, toutes rouges **par assertion** — jamais par compilation : supprimer un
paramètre aurait cassé le build sans rien prouver de ce que la garde mesure, les injections posent
donc un `null` en dur au site de relais. Trois méritent d'être citées, parce qu'elles font rougir
une garde **et une seule**, ce qui prouve que les gardes ne se recouvrent pas : le site « accès
refusé » neutralisé, le bouton réimplémenté par-dessus un `leading` hôte, et la décision corbeille
inversée. Une quatrième vérifie le sens inverse — un tiroir **fabriqué** par le socle quand l'hôte
n'en déclare aucun fait rougir la garde du défaut inchangé.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale constitue
la ligne de défense de cette release.
