FROM python:3.14-alpine

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    FLASK_APP=app.py

WORKDIR /app

RUN apk add --no-cache curl && pip install --no-cache-dir flask && rm -rf /root/.cache/

COPY ./app.py /app/app.py

EXPOSE 8080

CMD ["python", "-m", "flask", "run", "--host=0.0.0.0", "--port=8080", "--with-threads"]