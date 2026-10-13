#!/usr/bin/env python3
"""Signale les classes utilisées dans les templates mais absentes du CSS compilé.

Ce projet a vécu avec un app/web/public/static/css/index.css figé, généré une fois puis jamais
reconstruit : un tiers des classes des templates ne produisait plus aucun style.
Ce script empêche la situation de revenir.

    python3 -I scripts/audit_css.py            # sortie 0 si tout est couvert
    python3 -I scripts/audit_css.py autre.css  # auditer une autre feuille

Les classes purement comportementales (accrochées par querySelector) et les
classes d'impression ne sont pas des utilitaires Tailwind : elles sont ignorées.
"""

import collections
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SKIP_DIRS = {".venv", "node_modules", "mobile", "archive", ".git"}

# Accroches JS, classes d'impression et marqueurs Tailwind sans style propre.
IGNORE = {
    "filter-pill", "empty-slot", "session-search-item", "session-cell",
    "status-card", "active",          # état basculé en JS
    "card", "page-break", "no-print",  # feuille d'impression du rapport
    "peer", "group",                   # marqueurs Tailwind (peer-*/group-*)
    "disabled-link",
}

ESCAPE = re.compile(r"([:.\[\]/%()#,!*+])")


def compiled_classes(css_path):
    css = css_path.read_text(encoding="utf-8")
    return css


def used_classes():
    used = collections.defaultdict(set)
    for path in ROOT.rglob("*.html"):
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        for group in re.findall(r'class="([^"{}]*)"', text):
            for name in group.split():
                used[name].add(path.relative_to(ROOT).as_posix())
    return used


def main():
    css_path = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "app/web/public/static/css/index.css"
    if not css_path.exists():
        print(f"feuille introuvable : {css_path}")
        print("lancez d'abord : npm run css:build")
        return 2

    css = compiled_classes(css_path)
    used = used_classes()
    dead = {
        name: files
        for name, files in used.items()
        if name not in IGNORE and "." + ESCAPE.sub(r"\\\1", name) not in css
    }

    print(f"{len(used)} classes distinctes, {len(dead)} sans style ({css_path.name})")
    for name, files in sorted(dead.items(), key=lambda kv: -len(kv[1])):
        print(f"  {name:<34} {', '.join(sorted(files)[:3])}")

    if dead:
        print("\nRelancez `npm run css:build`. Si la classe est une accroche JS,")
        print("ajoutez-la à IGNORE dans ce script.")
    return 1 if dead else 0


if __name__ == "__main__":
    sys.exit(main())
