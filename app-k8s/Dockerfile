FROM python:3.12-alpine

# https://stackoverflow.com/questions/59812009/what-is-the-use-of-pythonunbuffered-in-docker-file
ENV PYTHONUNBUFFERED=1

WORKDIR /app
COPY app.py .

EXPOSE 8080
CMD ["python3", "app.py"]
