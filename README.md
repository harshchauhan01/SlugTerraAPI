# SlugTerraAPI

A Django REST API for browsing SlugTerra slug data, running slug duel simulations, and viewing summary statistics.

This project serves slug information from a JSON dataset and exposes it through clean HTTP endpoints with filtering, pagination, and interactive API docs.

## Contents

1. Project Overview
2. Features
3. Tech Stack
4. Repository Structure
5. Prerequisites
6. Quick Start (Local)
7. Running with Docker
8. Running on Kubernetes
9. API Documentation UI
10. API Endpoints
11. Load Testing with Locust
12. Data Source and Image Assets
13. Troubleshooting
14. Notes for Production

## Project Overview

SlugTerraAPI is built with Django + Django REST Framework and currently reads data from:

- `config/slugs_data.json`

It does not use database models for slug records at runtime. The API includes:

- A paginated slug list endpoint with filters
- A slug detail endpoint (case-insensitive by name)
- A stats endpoint for element/rarity/power-type counts
- A duel simulation endpoint with deterministic results via seed
- Swagger and ReDoc interactive docs

## Features

- JSON-backed API data (no slug model required)
- Pagination with configurable page size
- Filtering by search, element, rarity, and power type
- Duel simulation with round-level score breakdown
- OpenAPI docs via drf-yasg
- Dockerfile for containerized development
- Locust load test script
- Utility script to download and normalize slug images

## Tech Stack

- Python 3.12
- Django 5.2.12
- Django REST Framework 3.17.1
- django-filter 25.2
- drf-yasg 1.21.15
- SQLite (default)
- Optional PostgreSQL dependency present in requirements
- Optional Redis/Celery dependencies present in requirements

## Repository Structure

```text
SlugTerraAPI/
  README.md
  download_slug_images.py
  config/
    manage.py
    requirements.txt
    db.sqlite3
    slugs_data.json
    locustfile.py
    Dockerfile
    config/
      settings.py
      urls.py
    slugs/
      urls.py
      views.py
      models.py
    slug_images/
      ... (slug image folders)
```

## Prerequisites

- Python 3.12+ recommended
- pip
- Git (optional)
- Docker Desktop (optional, if running containerized)
- kubectl + a Kubernetes cluster (optional, if running on Kubernetes)

## Quick Start (Local)

### 1. Create and activate a virtual environment

Windows PowerShell:

```powershell
cd config
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

macOS/Linux:

```bash
cd config
python3 -m venv .venv
source .venv/bin/activate
```

### 2. Install dependencies

```bash
pip install -r requirements.txt
```

### 3. Apply migrations

```bash
python manage.py migrate
```

### 4. Start the development server

```bash
python manage.py runserver
```

Server default:

- http://127.0.0.1:8000/

## Running with Docker

Use Docker Compose for local containerized development (includes PostgreSQL + Redis).

### 1. Build image (optional)

From repository root:

```bash
docker build -f config/docker/Dockerfile -t slugterra-api:dev config
```

### 2. Start with Docker Compose

From `config/` folder:

```bash
docker compose up --build
```

Run in detached mode:

```bash
docker compose up --build -d
```

Stop and remove containers:

```bash
docker compose down
```

Stop and remove containers + volumes (removes PostgreSQL data):

```bash
docker compose down -v
```

Useful commands:

```bash
docker compose ps
docker compose logs -f web
docker compose exec web python manage.py createsuperuser
```

Default exposed ports in this setup:

- API app: 8000
- PostgreSQL: 5432
- Redis: 6379

## Running on Kubernetes

Kubernetes manifests are available in `k8s/`:

- `k8s/namespace.yml`
- `k8s/postgres.yml`
- `k8s/redis.yml`
- `k8s/deployment.yml`
- `k8s/service.yml`
- `k8s/ingress.yml`
- `k8s/hpa.yml`

### 1. Apply manifests

From `config/` folder:

```bash
kubectl apply -f k8s/namespace.yml
kubectl apply -f k8s/postgres.yml
kubectl apply -f k8s/redis.yml
kubectl apply -f k8s/deployment.yml
kubectl apply -f k8s/service.yml
kubectl apply -f k8s/ingress.yml
kubectl apply -f k8s/hpa.yml
```

### 2. Verify resources

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl get ns
kubectl get deploy,svc,ingress,hpa -n slugapi-ns
kubectl get pods -n slugapi-ns -w
```

### 3. Access the API locally

If you have an ingress controller installed, port-forward it to loopback:

```bash
kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 80:80
```

Then open:

- http://127.0.0.1/

If you do not have ingress running, use port-forward on the `ClusterIP` service:

```bash
kubectl port-forward -n slugapi-ns service/slugapp 8000:80
```

Then open:

- http://127.0.0.1:8000/

### 4. Clean up

```bash
kubectl delete -f k8s/hpa.yml
kubectl delete -f k8s/ingress.yml
kubectl delete -f k8s/service.yml
kubectl delete -f k8s/deployment.yml
kubectl delete -f k8s/namespace.yml
```

### Notes

- Current deployment image in `k8s/deployment.yml` is `harshchauhan01/slug-api:latest`.
- If you build your own image, push it to a registry and update the `image` field before applying.
- A local kind cluster config exists at `kind-cluster/kind-config.yml`.
- The app deployment expects the PostgreSQL service name `db` and Redis service name `redis`.
- The ingress rule does not use a host because Kubernetes ingress hosts must be DNS names, not IP addresses.
- To keep access on `127.0.0.1` only, port-forward the ingress controller to `127.0.0.1:80`.

## Monitoring with Prometheus and Grafana

You can run Prometheus and Grafana as standalone containers alongside the app.

From `config/` folder:

```bash
docker run -d --name prometheus --restart unless-stopped -p 9090:9090 prom/prometheus:latest
docker run -d --name grafana --restart unless-stopped -p 3000:3000 -e GF_SECURITY_ADMIN_USER=admin -e GF_SECURITY_ADMIN_PASSWORD=admin grafana/grafana:latest
```

Open the UIs:

- Prometheus: http://127.0.0.1:9090/
- Grafana: http://127.0.0.1:3000/

Default Grafana login:

- Username: admin
- Password: admin

If you want Prometheus to scrape this API, add a scrape configuration that targets the app's metrics endpoint.

## API Documentation UI

After server startup:

- Swagger UI: http://127.0.0.1:8000/swagger/
- ReDoc: http://127.0.0.1:8000/redoc/
- Raw schema: http://127.0.0.1:8000/swagger.json

## API Endpoints

Base URL:

- http://127.0.0.1:8000

### 1) Home

- Method: GET
- Path: /
- Purpose: API welcome payload and endpoint map

Example:

```http
GET /
```

### 2) List slugs

- Method: GET
- Path: /api/slugs/
- Purpose: Paginated slug list with optional filters

Query parameters:

- page (int): page number
- page_size (int): items per page (default 24)
- search (string): partial match on slug name
- element (string): exact element match (case-insensitive)
- rarity (string): exact rarity match (case-insensitive)
- power_type (string): substring match on power type (case-insensitive)

Examples:

```http
GET /api/slugs/
GET /api/slugs/?page=2&page_size=12
GET /api/slugs/?search=beek
GET /api/slugs/?element=fire&rarity=rare
GET /api/slugs/?power_type=ghoul
```

### 3) Slug detail

- Method: GET
- Path: /api/slugs/<slug_name>/
- Purpose: Returns one slug by exact name (case-insensitive)

Examples:

```http
GET /api/slugs/Aquabeek/
GET /api/slugs/infurnus/
```

Possible errors:

- 404 with detail message when slug is not found

### 4) Slug stats

- Method: GET
- Path: /api/slugs/stats/
- Purpose: Aggregate counts for elements, rarities, and power types

Example:

```http
GET /api/slugs/stats/
```

### 5) Slug duel simulation

- Method: GET
- Path: /api/slugs/duel/
- Purpose: Simulate duel rounds between two slugs

Required query parameters:

- slug_a (string)
- slug_b (string)

Optional query parameters:

- rounds (int): clamped to range 1..9, default 3
- seed (int): default 0 (deterministic simulation when fixed)

Example:

```http
GET /api/slugs/duel/?slug_a=Aquabeek&slug_b=Infurnus&rounds=3&seed=42
```

Possible errors:

- 400 if slug_a or slug_b is missing
- 404 if either slug does not exist

## Load Testing with Locust

Load profile script:

- `config/locustfile.py`

Run Locust from inside config folder:

```bash
locust -f locustfile.py --host=http://127.0.0.1:8000
```

Open Locust UI:

- http://127.0.0.1:8089

The locust file includes traffic for:

- /
- /api/slugs/
- /api/slugs/ with filters
- /api/slugs/stats/
- /api/slugs/<name>/
- /api/slugs/duel/

## Data Source and Image Assets

Primary slug dataset:

- `config/slugs_data.json`

Image utility script:

- `download_slug_images.py`

What the image script does:

- Reads slug entries from JSON
- Downloads images into `config/slug_images/<Slug_Name>/`
- Writes normalized image URLs back into slug JSON fields

## Troubleshooting

### Requirements encoding issues

If pip fails reading requirements due to encoding, re-save `config/requirements.txt` as UTF-8 and retry:

```bash
pip install -r requirements.txt
```

### Swagger/ReDoc not loading

Verify `drf_yasg` is installed and present in Django installed apps.

### 404 on slug detail

Slug names are matched case-insensitively but must be exact text otherwise.

### Port already in use

Run Django on another port:

```bash
python manage.py runserver 0.0.0.0:8001
```

## Notes for Production

Current defaults are development-oriented. Before production deployment:

- Set `DEBUG=False`
- Configure `ALLOWED_HOSTS`
- Move `SECRET_KEY` to environment variable
- Use a production database and robust cache strategy if needed
- Serve static files properly
- Run with gunicorn/uvicorn behind a reverse proxy

## License

This project is open source under the MIT License.

See the LICENSE file at the repository root for the full text.

## Contributing

Contributions are welcome.

1. Fork the repository.
2. Create a feature branch.
3. Make your changes with clear commit messages.
4. Add or update tests/docs where relevant.
5. Open a pull request describing what changed and why.
