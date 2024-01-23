FROM bitnami/java:11-debian-11

LABEL version="0.1"
LABEL maintaner="Hubert Dulay"
LABEL release-date="2023-12-31"
LABEL promoted="true"

RUN apt-get update -y && \
    apt-get install -y librdkafka-dev

WORKDIR /code

RUN curl https://downloads.apache.org/pinot/apache-pinot-1.0.0/apache-pinot-1.0.0-bin.tar.gz -o apache-pinot.tar.gz && \
    tar xvf apache-pinot.tar.gz

