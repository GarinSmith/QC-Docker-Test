FROM ubuntu

RUN apt-get update && apt-get -y install curl imagemagick file jq

WORKDIR /app

COPY ./convert.sh /app

ENV PATH="/app:${PATH}"
