# Handoff v3.8.0 — Transport par route : routeurs IA, gouvernance par plan, fournisseur et modèle par tâche

> **Date** : 2026-08-23 (brouillon écrit avant les lots ; complété lot par lot). **Portée prévue** :
> `zcrud_chat_kernel`, `zcrud_chat`, nouveau satellite `zcrud_chat_firestore`, `tool/reserved_keys_gate`.
> **Traite** : la décision du propriétaire du 2026-08-23 (transport par route de première classe) et la
> moitié « routage » du relevé des backends (`docs/analyses/backends-lex-iffd-2026-08-23.md`,
> `docs/analyses/routage-par-route-2026-08-23.md`).

## 1. Pourquoi

Deux modes de transport coexistent chez les hôtes : **un endpoint unique à corps riche** (Lex, `POST /`)
et **une route par intention** (IFFD, `generate_subject_explanation`, `summarize_explanation`…). Le
propriétaire a tranché : le mode par route est de première classe au socle. Il porte la **gouvernance**
(route ↔ plan d'abonnement), permet à l'app de déclarer **par tâche** le **fournisseur**, le modèle par
défaut, ses replis et ses callbacks, et le catalogue doit être **récupérable depuis le backend**. Lex
migrera vers ce mode à terme. Aujourd'hui tout passe par OpenRouter ; demain certaines tâches iront à
d'autres fournisseurs — le socle transporte le fournisseur par tâche et par repli, sans l'interpréter.

Ce que le relevé a mesuré :
- **IFFD** a déjà l'entité côté client (`IffdAiRouterModel` : douze paires `<tâche>Model`/`*FallbackModels`,
  `workflowEffort`, `questionsCounts`, identifiant par défaut `"free"`), une page d'administration maison
  (803 + 700 lignes) et une **édition zcrud déjà écrite mais désactivée** (`kAiRouterEditionUseZcrudDefault = false`).
  **22 sites** recopient `"model": aiRouter?.aiModel` ; trois dropdowns de repli sont dupliqués ; un bug
  réel : `folder_explanation_page.dart:213` envoie l'**identifiant du routeur** comme nom de modèle.
- **Lex** a l'entité côté serveur (`AiRouterConfig` : modèles par agent avec `provider`, replis
  `"provider:model"`, paramètres de pipeline, `workflow_effort`, `is_active`), servie par
  `GET /v1/admin/ai-routers`, cachée 300 s, repliée sur un défaut codé, et un gate **403 `UPGRADE_REQUIRED`**.
- 🔴 **Sécurité, à la main du propriétaire** : sur le backend IFFD, `check_app_check`/`check_authentication`
  existent mais leur unique appel est **commenté** (`iffd/v2/router.py:887-888`) ; les routes v2 acceptent
  les en-têtes d'auth et ne les vérifient jamais. Un transport gouverné par plan n'a de sens que si le
  serveur vérifie qui appelle.

## 2. Ce que le socle livre (à compléter lot par lot)

_K1 — noyau : entité, spec, `ZChatModelRef`, résolution, ports, gate, handlers, `providerId`._
_K2 — catalogue : sources, décodeur, TTL, cascade, dépôts._
_A — assemblage : session, seams partagés Chat/Notebook, ports routés, écran de conversation._
_F — satellite Firestore._

## 3. Ce qui change pour un hôte

### Hôte passif
Rien : sans catalogue déclaré, la requête reçue par le port est identique à celle du builder, les arbres
des écrans sont inchangés.

### Hôte qui déclare un catalogue SANS gate
**Toute route est refusée** (`ZDenyAllChatRouteGate`, posture `ZDenyAllAcl`). Déclarer explicitement
`const ZAllowAllChatRouteGate()` tant qu'aucune gouvernance n'existe.

### Hôte ayant compensé — IFFD
_À compléter : les 22 sites, les 3 dropdowns, `aiRouterId`/`setAiRouterId`, les 9 `aiHasAccessToAiRouter`,
`endpoint: 'chat'` en dur, `defaultModelId: aiRouterId`, la page admin maison → bascule du drapeau zcrud._

### Lex — à terme
_À compléter : source distante sur son endpoint admin, TTL 300 s, repli client ; transport inchangé._

## 4. Vérification
_À compléter._
