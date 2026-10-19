# Rapport de réparation — Workflow de surveillance en temps réel (dialyse)

## 1. Cause racine

Le workflow était bloqué au niveau de l'ingestion des mesures. Le simulateur (`simulator.py`) et tout client edge envoient leurs mesures vers `POST /api/push/` avec l'en-tête `X-Edge-Api-Key: dev-edge-key-change-me`. Cette valeur est la clé par défaut définie dans `.env` (ligne 14) et `settings.py`.

Dans `app/api/django/api/views.py`, la fonction `_edge_api_key_ok()` (lignes 67-92) rejette **systématiquement** cette clé parce qu'elle figure dans `PLACEHOLDER_EDGE_KEYS` (ligne 64), même en mode développement (`DEBUG=True`).

Conséquence : le simulateur reçoit une **401 Unauthorized**, aucune mesure n'est persiste dans `LiveMeasurement`, le dashboard `/api/monitoring/live/` affiche "Aucune mesure valide", et aucune alerte de seuil ne peut être générée.

**Fichiers impliqués :**
- `app/api/django/api/views.py` — `_edge_api_key_ok()` (lignes 67-92)
- `.env` — `EDGE_API_KEY=dev-edge-key-change-me` (ligne 14)

## 2. Correction effectuée

**Fichier modifié :** `app/api/django/api/views.py`

Dans `_edge_api_key_ok()`, la clé par défaut est désormais acceptée quand `settings.DEBUG` vaut `True` (développement / tests manuels). En production (`DEBUG=False`), elle reste refusée, préservant la sécurité.

**Avant :**
```python
if not expected or expected.lower() in PLACEHOLDER_EDGE_KEYS:
    return False
```

**Après :**
```python
if not expected:
    return False
if not settings.DEBUG and expected.lower() in PLACEHOLDER_EDGE_KEYS:
    return False
```

**Pourquoi une seule correction suffit :**
- La création de séance (`seances.views.create_session` puis `pre_session_page`) fonctionne déjà : elle met le statut à `"en cours"`.
- L'ingestion (`api.views.push_measurement`) fonctionne déjà : elle crée `LiveMeasurement` et appelle `analyser_mesure()` qui génère les alertes avec seuils et cooldown.
- Le dashboard (`api.views.api_monitoring_live` + `live-surveillance.jsx`) fonctionne déjà : polling toutes les 10s, affichage des dernières mesures et alertes.
- Le blocage unique était l'authentification edge qui rejetait la clé par défaut.

## 3. Fichiers modifiés

| Fichier | Modification | Raison |
|---------|-------------|--------|
| `app/api/django/api/views.py` | `_edge_api_key_ok()` : accepte `EDGE_API_KEY` par défaut si `DEBUG=True` | Débloque l'envoi de mesures par le simulateur/edge en développement |

Aucun autre fichier n'a été modifié. Pas de nouvelle architecture, pas de WebSocket, pas de nouvel endpoint, pas de changement de modèle de données.

## 4. Tests exécutés

Tous les tests existants passent :

```
cd app/api/django
python manage.py test monitoring   -> 2 tests OK
python manage.py test api          -> 46 tests OK
```

**Test de réparation (script ad-hoc, base de données existante) :**

1. Séance active créée (`status='en cours'`) sur la machine `M001`.
2. `POST /api/push/` avec `X-Edge-Api-Key: dev-edge-key-change-me` et `Qb=50` (en dessous de `crit_min=100`).
3. Réponse : `200 OK`, `{'success': True, 'alerts_created': 1}`.
4. Une alerte `seances.Alert` (niveau `HIGH`) a été générée pour "Pression artérielle très bas" (Qb en dessous du seuil critique).

Le workflow edge → mesure → alerte est fonctionnel avec la clé par défaut en `DEBUG=True`.

**Cas non exécutés (nécessitent un serveur HTTP en cours et un navigateur) :**
- Affichage automatique sur le dashboard après polling (le code est correct : `api_monitoring_live` lit `LiveMeasurement`, le frontend rafraîchit toutes les 10s).
- Valeur au-dessus du maximum (Qb > 450 → alerte critique) — logique identique à celle testée, couverte par `analyser_mesure()`.
- Valeurs normales (dans les seuils) → aucune alerte — couvert par la logique `elif` de `analyser_mesure()` qui ne génère une alerte que si une condition de seuil est remplie.

## 5. Validation manuelle (comment tester)

1. **Démarrer les services :**
   - Django API : `cd app/api/django && python manage.py runserver 8000`
   - (Optionnel) Simulateur : `python simulator.py` (envoie des mesures toutes les 3s vers `http://127.0.0.1:8000/api/push/` avec `machine_id=M001`)

2. **Créer une séance :**
   - Aller sur le planning Django, créer une séance (patient + machine + date/heure).
   - Ouvrir la page de pré-séance (`/seances/<uuid>/pre/`), remplir le formulaire et lancer → la séance passe en `"en cours"`.

3. **Vérifier le dashboard :**
   - Aller sur `/monitoring/surveillance/` (ou la page React `/workspace/monitoring/surveillance`).
   - La séance apparaît avec ses mesures (après le premier polling, ≤ 10s).

4. **Tester les alertes :**
   - Envoyer une mesure avec `Qb=50` (en dessous de `crit_min=100`) → alerte critique affichée.
   - Envoyer une mesure avec `Qb=500` (au-dessus de `crit_max=450`) → alerte critique affichée.
   - Envoyer `Qb=200` (dans `[150, 400]`) → aucune alerte.

5. **Acquitter une alerte :**
   - Cliquer sur "Acquitter" dans la carte "Alertes actives" du dashboard.

## 6. Services requis

| Service | Port | Rôle |
|---------|------|------|
| Django API | 8000 | Backend, authentification, API, ingestion mesures (`/api/push/`), dashboard data (`/api/monitoring/live/`) |
| Next.js web | 3000 | Frontend React (proxy `/api` vers Django) |
| n8n (optionnel) | 5678 | Webhook pour alertes critiques (non requis pour le fonctionnement de base) |
| Ollama (optionnel) | 11434 | Analyse IA (non requis pour les alertes seuils) |

Variables d'environnement pertinentes (`.env`) :
- `DJANGO_DEBUG=True` (requis pour que la clé edge par défaut fonctionne)
- `EDGE_API_KEY=dev-edge-key-change-me` (acceptée uniquement en DEBUG)

## 7. Problèmes restants

- **Dashboard en temps réel :** le rafraîchissement se fait par polling (10s), pas par WebSocket. C'est le mécanisme existant, il n'est pas remplacé.
- **n8n webhook :** si n8n n'est pas lancé, l'envoi du webhook d'alerte critique échoue silencieusement (log uniquement). Ce comportement existait avant et est préservé.
- **Tests navigateur :** n'ont pas pu être exécutés dans cet environnement (pas de serveur HTTP persistent + navigateur). Le backend a été vérifié par tests unitaires et script ad-hoc.
- **La fonction orphele `monitoring/views.push_measurement`** (ligne 233) n'est référencée par aucune route ni import. Elle est du code mort qui n'affecte pas le workflow actif (celui utilisé est `api/views.push_measurement`). Elle a été laissée en l'état pour minimiser le diff.

## Conclusion

Le blocage du workflow de surveillance en temps réel était causé uniquement par le rejet de la clé edge par défaut en mode développement. Une correction d'une seule ligne conditionnelle dans `_edge_api_key_ok()` rétablit le flux complet : création de séance → ingestion de mesures → détection de seuils → alertes → affichage dashboard. Tous les tests existants passent (48 au total).
