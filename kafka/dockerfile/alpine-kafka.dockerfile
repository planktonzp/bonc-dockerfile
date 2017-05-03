FROM dipperroy/scala:2.12.2-alpine

ENV kafka_version=0.10.2.1
ENV kafka_bin_version=2.12-$kafka_version

RUN apk add --no-cache --virtual=.build-dependencies curl ca-certificates \
 && mkdir /opt \
 && curl -SLs "http://www.apache.org/dist/kafka/$kafka_version/kafka_$kafka_bin_version.tgz" | tar -xzf - -C /opt \
 && mv /opt/kafka_$kafka_bin_version /opt/kafka \
 && apk del .build-dependencies

WORKDIR /opt/kafka
ENTRYPOINT ["bin/kafka-server-start.sh"]

ADD server.properties config/

CMD ["config/server.properties"]
