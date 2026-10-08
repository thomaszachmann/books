# syntax=docker/dockerfile:1
FROM python:3.12-slim@<DIGEST> AS build
ENV PIP_NO_CACHE_DIR=1 PIP_DISABLE_PIP_VERSION_CHECK=1
WORKDIR /build
COPY requirements.lock .
RUN pip install --require-hashes --no-deps --no-compile \
      --prefix=/install -r requirements.lock

FROM python:3.12-slim@<DIGEST>
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
COPY --from=build /install /usr/local
WORKDIR /app
COPY app.py .
USER 10001:10001
EXPOSE 8000
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "app:app"]
