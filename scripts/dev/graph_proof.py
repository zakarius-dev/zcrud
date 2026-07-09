#!/usr/bin/env python3
"""Extracteur de graphe AD-1 reproductible : lit les arêtes zcrud_* de chaque
pubspec, construit l'adjacence src->dst, prouve l'acyclicité (Kahn) et vérifie
out-degree(zcrud_core) == 0. Sortie déterministe.

Gate CI d'acyclicité AD-1 (E1-3). Durci (finding L-3, code-review E1-2) pour
couvrir NON SEULEMENT `dependencies:` mais AUSSI `dev_dependencies:` et
`dependency_overrides:` (angle mort d'un build tool : une arête zcrud_* peut
créer un cycle via ces blocs).

Usage :
    python3 scripts/dev/graph_proof.py [ROOT]
ROOT = dossier contenant les packages (défaut : `packages`). Le paramètre sert
aux fixtures de preuve (arbre de pubspecs fictif hors workspace).
"""
import glob
import os
import re
import sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else "packages"

# Blocs de dépendances scannés (L-3 : les trois, pas seulement `dependencies:`).
DEP_BLOCKS = ("dependencies", "dev_dependencies", "dependency_overrides")
BLOCK_OPEN = re.compile(r"^(%s):\s*$" % "|".join(DEP_BLOCKS))
TOP_LEVEL = re.compile(r"^[A-Za-z_]")
EDGE = re.compile(r"^\s+(zcrud_[a-z_]+)\s*:")

pkgs = {}
edges = set()          # (src, dst) tous blocs — dédupliqué ; utilisé pour la DÉTECTION DE CYCLE
runtime_edges = set()  # (src, dst) `dependencies:` uniquement — utilisé pour l'out-degree du cœur
for pubspec in sorted(glob.glob(os.path.join(ROOT, "*", "pubspec.yaml"))):
    src = os.path.basename(os.path.dirname(pubspec))
    pkgs.setdefault(src, set())
    cur_block = None
    for line in open(pubspec):
        raw = line.rstrip("\n")
        m_block = BLOCK_OPEN.match(raw)
        if m_block:
            cur_block = m_block.group(1)
            continue
        # une nouvelle clé top-level (non indentée, non commentaire) ferme le bloc
        if cur_block and TOP_LEVEL.match(raw):
            cur_block = None
        if cur_block:
            m = EDGE.match(raw)
            if m:
                dst = m.group(1)
                if dst != src:  # ignore auto-référence
                    edges.add((src, dst))
                    # L-2 : l'out-degree du cœur ne compte QUE les arêtes runtime
                    # (`dependencies:`). Un futur dev_dependency légitime d'un
                    # package zcrud sur zcrud_core (util de test) ne doit PAS
                    # déclencher un faux CORE OUT>0 ; le cycle, lui, reste fatal
                    # quel que soit le bloc.
                    if cur_block == "dependencies":
                        runtime_edges.add((src, dst))

edges = sorted(edges)
nodes = set(pkgs) | {d for _, d in edges} | {s for s, _ in edges}
adj = {n: set() for n in nodes}
indeg = {n: 0 for n in nodes}
for s, d in edges:
    if d not in adj[s]:
        adj[s].add(d)
        indeg[d] += 1

print("--- arêtes (src -> dst) ---")
for s, d in edges:
    print(f"{s} -> {d}")
print(f"total arêtes = {len(edges)}")

# out-degree du cœur — L-2 : runtime uniquement (dev_deps/overrides exclus)
core_out = len({d for s, d in runtime_edges if s == "zcrud_core"})
print(f"out-degree(zcrud_core) = {core_out} (runtime)")

# Kahn topo sort
q = sorted([n for n in nodes if indeg[n] == 0])
order = []
indeg2 = dict(indeg)
while q:
    n = q.pop(0)
    order.append(n)
    for m in sorted(adj[n]):
        indeg2[m] -= 1
        if indeg2[m] == 0:
            q.append(m)
    q.sort()
acyclic = len(order) == len(nodes)

print(f"noeuds = {len(nodes)}, triés = {len(order)}")
print("ACYCLIQUE OK" if acyclic else "CYCLE DETECTE")
print("CORE OUT=0 OK" if core_out == 0 else "CORE OUT>0 VIOLATION")

# L-2 : garde-fou « le scanner a bien trouvé des packages » basé sur pkgs (pas
# sur len(edges)) — un arbre légitime SANS arête zcrud ne doit pas échouer.
ok = acyclic and core_out == 0 and len(pkgs) > 0
sys.exit(0 if ok else 1)
