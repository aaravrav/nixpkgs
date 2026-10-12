"""Entry points for the three upstream services."""

import sys


def api():
    from uvicorn.main import main

    main(["api.main:app", "--host", "127.0.0.1", "--port", "8000", *sys.argv[1:]])


def inference():
    from uvicorn.main import main

    main(["inference.main:app", "--host", "127.0.0.1", "--port", "8001", *sys.argv[1:]])


def worker():
    from celery.bin.celery import celery

    celery(["--app", "worker.celery_app:celery_app", "worker", *sys.argv[1:]])
