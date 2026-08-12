// @ts-check
// `@type` JSDoc annotations allow editor autocompletion and type checking
// (when paired with `@ts-check`).
// There are various equivalent ways to declare your Docusaurus config.
// See: https://docusaurus.io/docs/api/docusaurus-config

import {themes as prismThemes} from 'prism-react-renderer';

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

const githubOrg = 'zakarius-dev';
const githubRepo = 'zcrud';
const githubUrl = `https://github.com/${githubOrg}/${githubRepo}`;

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'zcrud',
  tagline: 'Un schéma déclaratif de champs, deux surfaces : formulaires et listes — CRUD riche pour Flutter',
  favicon: 'img/favicon.ico',

  // Future flags, see https://docusaurus.io/docs/api/docusaurus-config#future
  future: {
    v4: true, // Improve compatibility with the upcoming Docusaurus v4
  },

  // Hébergement GitHub Pages, publié par build local (aucun GitHub Actions).
  url: 'https://zakarius-dev.github.io',
  baseUrl: '/zcrud/',
  organizationName: githubOrg,
  projectName: githubRepo,
  deploymentBranch: 'gh-pages',
  trailingSlash: false,

  // On veut que les liens cassés fassent échouer le build.
  onBrokenLinks: 'throw',
  onBrokenAnchors: 'throw',

  // Le contenu de docs/site/ est du Markdown pur, générateur-agnostique
  // (charte documentaire, principe 4) — jamais de JSX/expressions embarquées.
  // Sans `format: 'md'`, le pipeline MDX complet essaie d'interpréter tout
  // `{…}` rencontré (y compris la syntaxe native `## Titre {#ancre-stable}`
  // déjà écrite dans le contenu) comme une expression JS et casse la
  // compilation ("Could not parse expression with acorn"). `format: 'md'`
  // restreint le pipeline au Markdown/CommonMark + extensions Docusaurus
  // (dont les ancres `{#id}`), sans toucher au contenu.
  markdown: {
    format: 'md',
    hooks: {
      onBrokenMarkdownLinks: 'throw',
    },
  },

  // Une seule locale : français.
  i18n: {
    defaultLocale: 'fr',
    locales: ['fr'],
  },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          path: '../docs/site',
          routeBasePath: 'docs',
          sidebarPath: './sidebars.js',
          includeCurrentVersion: true,
          editUrl: `${githubUrl}/tree/main/docs/site/`,
        },
        // Pas de blog pour ce site de documentation technique.
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      // Pas de carte sociale par défaut : celle du gabarit Docusaurus portait
      // sa propre marque. À remplacer par un visuel zcrud le jour où il existe.
      colorMode: {
        defaultMode: 'light',
        respectPrefersColorScheme: true,
      },
      navbar: {
        title: 'zcrud',
        logo: {
          alt: 'Logo zcrud',
          src: 'img/logo.svg',
          srcDark: 'img/logo-dark.svg',
        },
        items: [
          {
            type: 'docSidebar',
            sidebarId: 'siteSidebar',
            position: 'left',
            label: 'Documentation',
          },
          {
            // Peuplé par un lot séparé (`melos run doc:api`, sous
            // website/static/api/) — le lien existe dès aujourd'hui même si
            // le dossier est encore vide en local. Protocole `pathname://`
            // (mécanisme Docusaurus natif) : le lien est envoyé tel quel au
            // navigateur SANS passer par la vérification des liens internes
            // (onBrokenLinks) — /api n'est pas une route générée par
            // Docusaurus, c'est un dossier statique peuplé après coup.
            to: 'pathname:///zcrud/api/',
            label: "Référence d'API",
            position: 'left',
          },
          {
            type: 'docsVersionDropdown',
            position: 'right',
          },
          {
            href: githubUrl,
            label: 'GitHub',
            position: 'right',
          },
        ],
      },
      footer: {
        style: 'dark',
        links: [
          {
            title: 'Documentation',
            items: [
              {label: 'Démarrage rapide', to: '/docs/demarrage-rapide'},
              {label: 'Concepts', to: '/docs/concepts/'},
              {label: 'Guides', to: '/docs/guides/'},
              {label: 'Catalogue des paquets', to: '/docs/paquets/'},
            ],
          },
          {
            title: 'Ressources',
            items: [
              // Voir le commentaire sur l'entrée de navbar équivalente :
              // pathname:// pour ne pas être soumis à onBrokenLinks.
              {label: "Référence d'API", to: 'pathname:///zcrud/api/'},
              {label: 'Dépôt GitHub', href: githubUrl},
              {
                label: 'Charte documentaire',
                to: '/docs/charte',
              },
            ],
          },
          {
            title: 'Licence',
            items: [
              {
                label: 'MIT — voir LICENSE',
                href: `${githubUrl}/blob/main/LICENSE`,
              },
            ],
          },
        ],
        copyright: `Copyright © ${new Date().getFullYear()} zcrud — Licence MIT.`,
      },
      prism: {
        theme: prismThemes.github,
        darkTheme: prismThemes.dracula,
      },
    }),

  themes: [
    [
      '@easyops-cn/docusaurus-search-local',
      /** @type {import('@easyops-cn/docusaurus-search-local').PluginOptions} */
      ({
        hashed: true,
        language: ['fr'],
        indexDocs: true,
        indexBlog: false,
        indexPages: true,
        docsRouteBasePath: '/docs',
        // Le contenu réel vit sous ../docs/site (docs.path dans le preset
        // classic ci-dessus) — sans ce réglage le plugin cherche par défaut
        // un dossier website/docs/ inexistant (warning `docsDir` au build).
        docsDir: '../docs/site',
      }),
    ],
  ],
};

export default config;
