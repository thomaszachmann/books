FROM python:latest
ENV API_TOKEN=lab-token-123
RUN apt-get update
RUN apt-get install -y curl gcc
RUN curl -sSL https://bootstrap.pypa.io/get-pip.py | python
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
EXPOSE 8000
CMD gunicorn -b 0.0.0.0:8000 app:app
