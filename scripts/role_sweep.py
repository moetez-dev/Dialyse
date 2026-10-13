#!/usr/bin/env python3
"""Walk every screen as every role and report what each one gets.

Checks more than the status code: that the page carries the shared chrome,
uses the design tokens, and shows no leftover rendering artefacts.
"""

import os
import re
import subprocess
import sys

BASE = "http://localhost:8000"

# Clés de session par rôle. Les créer avec :
#   docker compose exec web python manage.py shell -c "..."
# (voir scripts/README ou le commentaire en bas de ce fichier)
ROLES = {
    "Admin": os.environ.get("SID_ADMIN", ""),
    "Docteur": os.environ.get("SID_DOCTEUR", ""),
    "Infirmier": os.environ.get("SID_INFIRMIER", ""),
    "Technicien": os.environ.get("SID_TECHNICIEN", ""),
}

PAGES = [
    "/monitoring/", "/monitoring/surveillance/", "/monitoring/alerts-history/",
    "/monitoring/seances-history/", "/patients/", "/seances/", "/machines/",
    "/machines/raspi/", "/nurses/", "/docteurs/", "/profile/",
    "/machines/details/1/", "/machines/configurer/1/", "/doctor/1/",
]

# Artefacts that should never reach a rendered page.
ARTEFACTS = [
    (r">\s*None\s*<", "literal None"),
    (r"\bundefined\b", "literal undefined"),
    (r"bg-gray-\d|text-gray-\d|bg-white\b", "unmigrated colour class"),
    (r"TemplateSyntaxError|Traceback", "server error in body"),
    (r"Oct\.|Jan\.|Aug\.|\ba\.m\.|\bp\.m\.", "English date"),
]


def strip_scripts(html):
    """Le contenu des <script> n'est pas du rendu : ne pas y chercher d'artefacts."""
    return re.sub(r"<script\b.*?</script>", "", html, flags=re.S | re.I)


def fetch(path, sid):
    out = subprocess.run(
        ["curl", "-s", "-w", "\n@@%{http_code}", "-b", f"sessionid={sid}", BASE + path],
        capture_output=True, text=True,
    ).stdout
    body, _, code = out.rpartition("\n@@")
    return code.strip(), body


def main():
    missing = [r for r, sid in ROLES.items() if not sid]
    if missing:
        print("clés de session manquantes :", ", ".join(missing))
        print("exporter SID_ADMIN, SID_DOCTEUR, SID_INFIRMIER, SID_TECHNICIEN")
        return 2

    problems = []
    width = max(len(p) for p in PAGES) + 2
    header = "page".ljust(width) + "".join(r.ljust(13) for r in ROLES)
    print(header)
    print("-" * len(header))

    for path in PAGES:
        row = path.ljust(width)
        for role, sid in ROLES.items():
            code, body = fetch(path, sid)
            mark = code
            if code == "200":
                has_nav = 'id="sidebar"' in body
                has_tokens = "bg-surface" in body or "text-body" in body
                visible = strip_scripts(body)
                found = [name for pat, name in ARTEFACTS if re.search(pat, visible)]
                # Un rôle non reconnu n'a aucune entrée : barre absente attendue.
                if not has_nav and role != "Technicien":
                    mark = "200 nochrome"; problems.append((path, role, "no sidebar"))
                elif not has_tokens:
                    mark = "200 notoken"; problems.append((path, role, "no design tokens"))
                elif found:
                    mark = "200 ⚠"; problems.extend((path, role, f) for f in found)
                else:
                    mark = "200 ok"
            row += mark.ljust(13)
        print(row)

    print()
    if problems:
        print(f"{len(problems)} issue(s):")
        seen = set()
        for path, role, what in problems:
            key = (path, what)
            if key in seen:
                continue
            seen.add(key)
            print(f"   {path:<32} [{role}] {what}")
    else:
        print("no issues found")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
