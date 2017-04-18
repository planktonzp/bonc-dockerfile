FROM alpine:3.5
MAINTAINER Dipper Roy<ruizhipeng001@gmail.com>

ENV NPM_CONFIG_LOGLEVEL info
ENV NODE_VERSION 7.9.0

# ADD GROUP & USER
RUN addgroup -g 1000 node \
    && adduser -u 1000 -G node -s /bin/sh -D node \
    && apk add --no-cache \
        libstdc++ \
    && apk add --no-cache --virtual .build-deps \
        binutils-gold \
        curl \
        g++ \
        gcc \
        libgcc \
        linux-headers \
        make \
        python \
    && curl -o /tmp/hosts "https://raw.githubusercontent.com/racaljk/hosts/master/hosts" \
  # gpg keys listed at https://github.com/nodejs/node#release-team
    && curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION.tar.xz" \
    && tar -xf "node-v$NODE_VERSION.tar.xz" \
    && cd "node-v$NODE_VERSION" \
    && ./configure \
    && make -j$(getconf _NPROCESSORS_ONLN) \
    && make install \
    && apk del .build-deps \
    && cd .. \
    && rm -Rf "node-v$NODE_VERSION" \
    && rm "node-v$NODE_VERSION.tar.xz"

ENV YARN_VERSION 0.22.0

RUN apk add --no-cache --virtual .build-deps-yarn curl \
  && curl -fSL -o yarn.js "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-legacy-$YARN_VERSION.js" \
  && mv yarn.js /usr/local/bin/yarn \
  && chmod +x /usr/local/bin/yarn \
  && apk del .build-deps-yarn

CMD [ "node" ]
