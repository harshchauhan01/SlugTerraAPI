FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Copy dependency file first for better Docker layer caching.
COPY config/requirements.txt /app/requirements.txt

# Normalize requirements encoding to UTF-8 to avoid pip parsing issues.
RUN python -c "from pathlib import Path; p=Path('/app/requirements.txt'); raw=p.read_bytes();\nenc=None\n\nfor e in ('utf-8-sig','utf-16','utf-16-le','utf-16-be'):\n    try:\n        text=raw.decode(e)\n        enc=e\n        break\n    except UnicodeDecodeError:\n        pass\n\nif enc is None:\n    raise SystemExit('Unable to decode requirements.txt')\n\np.write_text(text, encoding='utf-8')"

RUN pip install -r /app/requirements.txt

# Copy Django project files.
COPY config/ /app/

EXPOSE 8000

CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
