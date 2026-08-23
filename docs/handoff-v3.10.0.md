# Handoff v3.10.0 — CR-IFFD-89 : `taskAliases` sur les formes de catalogue

> **Date** : 2026-08-23. **Portée** : `zcrud_chat_kernel`. **Traite** : CR-IFFD-89, émise le jour même
> en consommant v3.9.0, trouvée **par une garde hôte**, pas à l'écran.

## 1. Le défaut

`ZChatRouteCatalogShape.suffixPairs` dérive une route par tâche depuis `<tâche>Model` /
`<tâche>FallbackModels`, **nommée par le préfixe brut du document**. La session cherche la route par
`request.style.kind`. Chez IFFD, quatre préfixes sur treize ne coïncident pas avec le `kind`
(`summary` ≠ `summarize`, `elaboration` ≠ `elaborate`, `history` ≠ `story`, `chatStyle` ≠ `classroom`) :
la route **existe**, est **décodée** avec le bon modèle, et n'est **jamais trouvée** — la résolution
replie sur la racine, sans erreur. Le résumé partait sur le modèle de chat.

Constat vérifié sur disque : `z_chat_route_catalog_decoder.dart:348-362` (`key.substring(...)`),
aucun `taskAliases` (grep = 0) ; `rootAliases`/`routeAliases` traduisent des clés, jamais le nom de
la tâche. Même trou sur la forme nommée (`lex`, routes par nom d'agent).

L'hôte avait écrit la correction chez lui (`_aligneLesRoutes`) et l'a **retirée avant commit** —
troisième copie d'une même table, et violation du partage maximal. Deux tripwires affirment la perte.

## 2. Ce que le socle livre
- **`taskAliases`** sur `ZChatRouteCatalogShape` (général **et** `suffixPairs`) : un unique point de traduction, appliqué après extraction du préfixe et après lecture de la clé d'objet des routes nommées (forme `lex`). Défaut vide ⇒ comportement inchangé (étalon gardé). Fusion de deux noms vers une clé : dernière déclaration gagnante ; alias vers une clé vide ⇒ route écartée, jamais d'exception.
- Aucun alias d'hôte au socle (garde FR-26 : `summarize|elaborate|story|classroom` absents de `catalog/`, contre-preuve comprise) ; le preset `lex` n'en porte pas non plus — gardé.

## 3. Ce qui change pour un hôte
- **Passif** (sans `taskAliases`) : rien — le préfixe reste la clé.
- **IFFD** : déclarer `taskAliases: {'summary': 'summarize', 'elaboration': 'elaborate', 'history': 'story', 'chatStyle': 'classroom'}`
  sur sa forme (la table reste une donnée d'hôte) ; ses deux tripwires rougissent et désignent ce
  qu'il retire.

## 4. Vérification

Rejouée par l'orchestrateur, au repos : `zcrud_chat_kernel` **663** VM / **491** Node ; `melos run generate` 0 `.g.dart` ; `melos run analyze` 0 erreur ; `melos run verify` **RC=0** (douze gates) ; balayage des **41 paquets** : 40 verts, `zcrud_generator` rouge environnemental. Six injections R3, six rouges par assertion. Greps négatifs : aucun alias d'hôte dans `catalog/`, aucun résidu.
