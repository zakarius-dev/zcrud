/// Barrel d'API publique de `zcrud_chat_syncfusion` — CHAT-6.
///
/// Ce paquet est la **frontière** du chat : tout ce qu'un backend particulier
/// impose de compensations s'arrête ici, et le socle (`zcrud_chat`,
/// `zcrud_chat_kernel`, `zcrud_core`) n'en porte rien.
///
/// ## Deux volets, une seule raison d'être
///
/// **1. La coquille Syncfusion — un BACKEND du port, plus une vue parallèle
/// (CHAT-3b).** `ZSfAssistShellRenderer` implémente `ZChatShellRenderer` : il
/// rend le **CADRE** (`SfAIAssistView`) et rappelle la fabrique de tuiles du
/// socle. Il REMPLACE `ZSfAssistConversationView`, widget parallèle à
/// `ZChatConversationView` qui faisait perdre à l'hôte la région live, le dépli
/// inline et `ZChatMessageTile` — le doublon né d'une couture placée au mauvais
/// niveau (motif CR-LEX-78). `ZSfAssistRenderer` disparaît avec lui : il
/// déclinait tout et ne servait qu'à rechaîner le renderer de BLOCS de l'hôte,
/// que la coquille n'intercepte plus (deux scopes indépendants).
/// `syncfusion_flutter_chat` n'expose aucun widget de bloc (tous privés,
/// vérifié dans `conversion_area.dart`) : il n'y a donc RIEN à adapter à ce
/// niveau, et une fausse adaptation écrite à la main serait pire que l'absence.
/// AD-57 : `syncfusion_flutter_chat` est une arête de CE paquet, et d'aucun
/// autre.
///
/// **2. La normalisation du fil textuel d'IFFD.** `ZIffdLexer` découpe
/// (`###LINE###`, sentinelles pseudo-XML, fragments coupés en deux),
/// `ZIffdStreamNormalizer` classe en canaux et produit les événements typés du
/// kernel, `ZIffdTextStreamPort` expose le tout comme un `ZChatStreamPort`. Une
/// erreur écrite en clair par le serveur (`⚠️ Erreur <Agent> : …`) devient un
/// `Left(ZChatProviderFailure)` — **jamais** un message de conversation (AD-5).
///
/// ⛔ AUCUN client HTTP, AUCUN SDK IA (AD-11/AD-12) · ⛔ AUCUN gestionnaire
/// d'état (AD-2/AD-15) · AD-1 : arêtes SORTANTES seules, graphe ACYCLIQUE,
/// CORE OUT = 0.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

export 'src/data/z_iffd_lexer.dart';
export 'src/data/z_iffd_stream_normalizer.dart';
export 'src/data/z_iffd_stream_port.dart';
export 'src/data/z_iffd_wire.dart';
export 'src/presentation/z_sf_assist_labels.dart';
export 'src/presentation/z_sf_assist_shell_renderer.dart';
