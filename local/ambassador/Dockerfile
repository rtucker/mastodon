FROM alpine:latest

LABEL maintainer="https://github.com/mbilokonsky/ambassador" \
      description="A mastodon bot for showing the world the best your instance has to offer."

ENV UID=992 GID=992

WORKDIR /ambassador

RUN echo "@edge https://nl.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories \
 && apk -U upgrade \
 && apk add -t build-dependencies \
    build-base \
    postgresql-dev \
 && apk add \
    libuv@edge \
    nodejs-npm@edge \
    nodejs@edge \
    su-exec \
    tini \
 && npm install -g npm@3 && npm install -g yarn \
 && update-ca-certificates \
 && rm -rf /tmp/* /var/cache/apk/*

COPY index.js package.json yarn.lock /ambassador/

RUN yarn

COPY docker_entrypoint.sh /usr/local/bin/run

RUN chmod +x /usr/local/bin/run

ENTRYPOINT ["/usr/local/bin/run"]
