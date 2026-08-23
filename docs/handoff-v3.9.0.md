# Handoff v3.9.0 — les restes de v3.8.0 : fournisseur typé sur les artefacts, `copyWith` de requête, sous-listes imbriquées

> **Date** : 2026-08-23 (brouillon écrit avant les lots, complété lot par lot). **Portée prévue** :
> `zcrud_chat_kernel`, `zcrud_chat`, `zcrud_core`. **Traite** : les trois restes signalés au handoff
> v3.8.0 et laissés ouverts — pour que le transport par route soit complet, sans contournement.

## 1. Pourquoi

v3.8.0 a livré le routeur IA et son catalogue avec trois compromis assumés, chacun signalé :
1. le fournisseur d'une **génération d'artefact** voyageait dans `extra['provider_id']` faute de champ
   typé sur `ZChatArtifactGenerationRequest` ;
2. `ZChatGenerationRequest` n'avait pas de `copyWith` : `withSettings`, `withCorpusScope` et
   `ZChatRouteResolution.toRequest` recopiaient ses 19 champs à la main — trois sites à tenir en phase ;
3. les **replis** d'une route s'éditaient en jetons `provider:model` parce que l'emboîtement d'un
   `subItems` dans un item de `subItems` n'avait pas été mesuré dans le moteur d'édition.

## 2. Ce que le socle livre (à compléter lot par lot)

### X1 — noyau
- **`ZChatArtifactGenerationRequest.providerId`** typé (opaque, même statut que `modelId`) — plus aucun canal `extra['provider_id']`.
- **`ZChatGenerationRequest.copyWith`** (sentinelle `_unset`, 19 champs) ; `withSettings`, `withCorpusScope` et `ZChatRouteResolution.toRequest` en sont des appelants : **un seul site de recopie**, gardé (le constructeur n'est appelé qu'une fois dans `lib/`).
- **Précédence de l'effort, tranchée et documentée** : sans réglages, `base.computeEffort ?? route ?? racine` — la route ne recouvre plus un budget explicite ; avec réglages, la feuille reste un remplacement (`settings.computeEffort ?? route`). ⚠️ Hôte qui comptait sur la route pour écraser un effort posé par son builder : ce n'est plus le cas.
### X3 — cœur (`zcrud_core`, moteur d'édition)
**Mesure initiale : rouge.** Un `subItems` déclaré dans les `itemFields` d'un `subItems` était monté mais **pas mettable en page**, et perdait son scope. Trois défauts corrigés dans `z_sub_list_field_widget.dart` :
1. le dialogue d'item mesure en largeur intrinsèque, la table imbriquée se mesure par `LayoutBuilder` — largeur finie posée **seulement** quand le sous-schéma emboîte une liste (prédicat récursif) ; un formulaire plat garde sa largeur ;
2. le formulaire d'item re-posait `ZReadModeScope` mais **pas `ZcrudScope`** : un scope posé sous `home` était invisible de la route ⇒ niveau 2 en `ZDenyAllAcl`, sans libellés ni thème. Re-posé par `scope.copyWith(child:)` ;
3. un `summaryFields` nommant une sous-liste affichait la liste brute ; il rend le **compte**.
Sans limite de profondeur (gardé à 3 niveaux), lecture seule propagée, AD-2 (éditer au niveau 2 ne reconstruit ni le niveau 1 ni la racine — gardé), AD-10 (sous-liste absente/corrompue ⇒ vide). ⚠️ Hôte qui compensait la perte de scope dans le formulaire d'item (`itemFieldBuilder`/`fieldBuilder` re-posant libellés, thème ou ACL) : **retirer** la compensation.
### X2 — chat
- La résolution d'artefact et le port routé d'artefact lisent et écrivent **`providerId` typé** ; `extra` ne transporte plus le fournisseur.
- 🔴 **Rupture compilée** : `kZChatArtifactProviderIdKey` est **retirée** du barrel (un seul canal par donnée). Un hôte qui l'importait casse à la compilation — remède : lire `request.providerId` ; pour forcer un fournisseur, poser `providerId:` **et** `modelId:` sur la requête. La constante n'a existé qu'en v3.8.0.
- Garde de source : aucun `provider_id` ni `kZChatArtifactProviderIdKey` dans `lib/` (grep négatif avec contre-preuve).
### X1b — noyau
- `$ZChatModelRefFieldSpecs` (`provider_id` optionnel, `model_id` requis, aucun libellé) ; les **replis** d'une route **et** de la racine sont déclarés en `subItems` imbriqué (`ZSubListConfig(itemFields: $ZChatModelRefFieldSpecs)`) à la place des jetons `tags` ; `routes` résume aussi le compte des replis.
- **Forme sur le fil** : `toMap`/`toJson` émettent les replis en **liste de maps** `{provider_id, model_id}` — toujours ; la lecture reste tolérante (maps, jetons `"p:m"`, chaînes nues). ⚠️ Un hôte qui lisait ou écrivait lui-même des jetons (filtres `arrayContains`, index typés, affichage) passe par `ZChatModelRef.fromJson` ou adapte ; un document écrit en jetons est relu, puis **réécrit en maps** à la prochaine sauvegarde.
- Mesuré en passant, préexistant, non modifié : un jeton nu **hors liste** (`'fallbacks': 'f'`) n'est toléré que par le décodeur de catalogue, pas par `ZChatRouter.fromMap`.

## 3. Ce qui change pour un hôte

| Hôte | Effet |
|---|---|
| **Passif** (sans catalogue, sous-listes plates) | rien |
| Qui lisait `extra['provider_id']` sur une requête d'artefact | lire `request.providerId` — sinon `null` silencieux ; qui l'écrivait pour forcer un fournisseur : poser `providerId:` **et** `modelId:` |
| Qui importait `kZChatArtifactProviderIdKey` | **rupture compilée** (retirée) |
| Qui comptait sur la route pour écraser un `computeEffort` posé par son builder | ce n'est plus le cas : `base ?? route ?? racine` sans réglages |
| Qui compensait la perte de `ZcrudScope` dans un formulaire d'item (`itemFieldBuilder`/`fieldBuilder` re-posant libellés, thème, ACL) | **retirer** la compensation — le scope est re-posé |
| Qui manipulait des replis en jetons `"p:m"` | forme canonique = liste de maps ; lecture tolérante, réécriture en maps |

**Tripwire recommandé** : un test hôte qui affirme aujourd'hui « au niveau 2, l'ACL est `ZDenyAllAcl` » ou « `extra` porte `provider_id` » rougit à l'adoption et désigne la compensation.

## 4. Vérification

Rejouée par l'orchestrateur, workstreams au repos, depuis le dossier de chaque paquet :
- `melos run generate` : 0 `.g.dart` modifié ; `melos run analyze` : 0 erreur ; `melos run verify` : **RC=0** (douze gates, 41 paquets à la recette, `ACYCLIQUE OK`, `CORE OUT=0`, `reserved-keys`, `web`).
- `zcrud_chat_kernel` **657** VM / **486** Node ; `zcrud_chat` **832 en 14 s** ; `zcrud_core` **2 389** ; `zcrud_chat_firestore` **20** (une garde jumelle a mordu sur la nouvelle forme des replis — son codec d'exemple retraduit maps → jetons, l'assertion sur la forme legacy est conservée).
- Balayage des **41 paquets** : 40 verts, `zcrud_generator` rouge environnemental. Quatre paquets n'avaient pu être remesurés en fin de chaîne (coupure réseau : `dart test` appelle `pub.dev` avant de lancer) ; **remesurés au retour du réseau** : `zcrud_chat_kernel` 657, `zcrud_exam` 79, `zcrud_chat_syncfusion` 69 (paquet Flutter : `flutter test --no-pub`), `zcrud_study_kernel` 398. Leçon consignée : l'identité à l'octet d'un paquet ne vaut rien si sa **dépendance** a changé — seule la mesure compte.
- Campagnes R3 : X1 6 · X1b 6 · X2 6 · X3 5 — **23 injections, 23 rouges par assertion**.
