FROM python:3.11.1

LABEL version="0.1"
LABEL maintaner="Hubert Dulay"
LABEL release-date="2023-12-31"
LABEL promoted="true"


RUN apt-get update -y && \
    apt-get install -y librdkafka-dev

WORKDIR /code
COPY requirements.txt requirements.txt
COPY producer.py producer.py

RUN pip install --upgrade pip
RUN python3 --version && pip install -r requirements.txt

CMD ["python", "producer.py"]

