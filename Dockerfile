FROM alpine:3

RUN apk --no-cache add \
    postgresql-client \
    openssl \
    bash \
    file \
    curl \
    jq

WORKDIR /entrypoint
COPY *.sh ./
RUN chmod +x -R /entrypoint

ENTRYPOINT [ "/entrypoint/up.sh" ]