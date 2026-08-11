/// Barrel d'API publique de `zcrud_chat_markdown`.
///
/// Backend de rendu riche Markdown/LaTeX pour le port `ZChatRenderer` de
/// `zcrud_chat`, adossé à `zcrud_markdown`.
///
/// Ce paquet est un satellite opt-in : un consommateur de `zcrud_chat` qui
/// ne le monte pas ne tire aucune dépendance riche supplémentaire, et son
/// rendu reste strictement le rendu neutre par défaut. Ce barrel n'exporte
/// aucun symbole de l'éditeur riche sous-jacent, et le paquet ne déclare
/// aucune arête directe vers lui (invariant AD-1) : il n'est atteint qu'à
/// travers l'API neutre de `zcrud_markdown`.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

export 'src/presentation/z_chat_markdown_renderer.dart'
    show
        ZChatMarkdownRenderer,
        ZChatMarkdownStreamingMode,
        kZChatMarkdownDefaultRoles;
