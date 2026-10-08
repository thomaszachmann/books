ARG BASE_REGISTRY=nexus:8082
FROM ${BASE_REGISTRY}/library/python:3.12-slim AS build
ARG PIP_INDEX_URL
ARG PIP_TRUSTED_HOST
WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM ${BASE_REGISTRY}/library/python:3.12-slim
ARG APP_VERSION=1.1.0
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 APP_VERSION=${APP_VERSION}
COPY --from=build /install /usr/local
WORKDIR /app
COPY app.py .
USER 10001
EXPOSE 8000
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "app:app"]
