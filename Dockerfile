FROM python:3.9-slim

WORKDIR /app
COPY app/requirements.txt app/requirements.txt
RUN pip install --no-cache-dir -r app/requirements.txt

COPY /app /app

EXPOSE 8080

CMD ["flask", "run", "--host=0.0.0.0", "--port=8080"]
