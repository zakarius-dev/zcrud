import clsx from 'clsx';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import Heading from '@theme/Heading';

import styles from './index.module.css';

const FEATURES = [
  {
    title: 'Un schéma, deux surfaces',
    description: (
      <>
        Annotez votre modèle (<code>@ZcrudModel</code>) : la sérialisation,
        le <code>ZFieldSpec[]</code> et l'enregistrement au registre sont
        générés. Le formulaire d'édition et la liste en découlent — zéro
        duplication entre les deux.
      </>
    ),
  },
  {
    title: 'Rebuilds granulaires',
    description: (
      <>
        Taper 100 caractères ne reconstruit que le champ courant : pas de
        perte de focus, pas de jank. C'est l'objectif produit n°1, vérifié
        par test.
      </>
    ),
  },
  {
    title: "Aucun gestionnaire d'état imposé",
    description: (
      <>
        Le cœur du moteur est Flutter-natif. Riverpod, GetX et Provider ont
        chacun leur paquet de binding — vous choisissez, zcrud ne décide pas
        à votre place.
      </>
    ),
  },
  {
    title: 'Offline-first par contrat',
    description: (
      <>
        Store local source de vérité, synchronisation différée,
        Last-Write-Wins sur <code>updatedAt</code>, soft-delete. Le réseau
        est un détail, jamais un prérequis.
      </>
    ),
  },
];

function Feature({title, description}) {
  return (
    <div className={clsx('col col--3')}>
      <div className={styles.featureCard}>
        <Heading as="h3">{title}</Heading>
        <p>{description}</p>
      </div>
    </div>
  );
}

function HomepageHeader() {
  const {siteConfig} = useDocusaurusContext();
  return (
    <header className={clsx('hero', styles.heroBanner)}>
      <div className="container">
        <Heading as="h1" className={styles.heroTitle}>
          {siteConfig.title}
        </Heading>
        <p className={styles.heroSubtitle}>{siteConfig.tagline}</p>
        <div className={styles.buttons}>
          <Link className="button button--primary button--lg" to="/docs/">
            Aller à la documentation
          </Link>
          {/* Dossier statique peuplé après coup par `melos run doc:api` —
              `pathname://` (mécanisme Docusaurus natif) laisse ce lien
              exister sans être soumis à la vérification des liens internes
              (onBrokenLinks), le dossier n'étant pas une route Docusaurus. */}
          <Link
            className="button button--outline button--secondary button--lg"
            to="pathname:///zcrud/api/">
            Référence d'API
          </Link>
        </div>
      </div>
    </header>
  );
}

export default function Home() {
  const {siteConfig} = useDocusaurusContext();
  return (
    <Layout
      title={siteConfig.title}
      description={siteConfig.tagline}>
      <HomepageHeader />
      <main>
        <section className={styles.features}>
          <div className="container">
            <div className="row">
              {FEATURES.map((feature) => (
                <Feature key={feature.title} {...feature} />
              ))}
            </div>
          </div>
        </section>
        <section className={styles.ecosystem}>
          <div className="container">
            <Heading as="h2">39 paquets, un seul socle</Heading>
            <p>
              Le graphe de dépendances est acyclique et vérifié : formulaires,
              listes, Markdown riche, géolocalisation, téléphone/pays,
              flashcards, mindmaps, chat, export PDF/Excel, synchronisation
              Firestore offline-first — vous n'embarquez que ce que vous
              importez.
            </p>
            <div className={styles.buttons}>
              <Link className="button button--secondary button--lg" to="/docs/demarrage-rapide">
                Démarrage rapide
              </Link>
              <Link className="button button--secondary button--lg" to="/docs/paquets/">
                Catalogue des paquets
              </Link>
            </div>
          </div>
        </section>
      </main>
    </Layout>
  );
}
