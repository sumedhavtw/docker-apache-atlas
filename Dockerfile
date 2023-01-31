FROM ubuntu:20.04
LABEL maintainer="foobar"

ARG VERSION=2.3.0
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC
ENV MAVEN_OPTS="-Xms2g -Xmx2g"
ENV JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64"
COPY apache-atlas-${VERSION}-server.tar.gz /tmp

RUN mkdir -p /opt/apache-atlas \
    && mkdir -p /opt/gremlin

RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get -y install apt-utils \
    && apt-get -y install \
        maven \
        wget \
        python \
        openjdk-8-jdk-headless \
        patch \
        unzip \
    && tar --strip 1 -xzvf /tmp/apache-atlas-${VERSION}-server.tar.gz -C /opt/apache-atlas \
    && rm -f /tmp/apache-atlas-${VERSION}-server.tar.gz \
    && apt-get -y --purge remove \
        maven \
        unzip \
    && apt-get -y autoremove \
    && apt-get -y clean

VOLUME ["/opt/apache-atlas/conf", "/opt/apache-atlas/logs"]

COPY conf/hbase/hbase-site.xml.template /opt/apache-atlas/conf/hbase/hbase-site.xml.template
COPY atlas_start.py.patch atlas_config.py.patch /opt/apache-atlas/bin/
COPY conf/atlas-env.sh /opt/apache-atlas/conf/atlas-env.sh
COPY conf/gremlin /opt/gremlin/

WORKDIR /opt/apache-atlas/bin
RUN patch -b -f < atlas_start.py.patch \
    && patch -b -f < atlas_config.py.patch

WORKDIR /opt/apache-atlas/conf
RUN sed -i 's/\${atlas.log.dir}/\/opt\/apache-atlas\/logs/g' atlas-log4j.xml \
    && sed -i 's/\${atlas.log.file}/application.log/g' atlas-log4j.xml

WORKDIR /opt/apache-atlas/bin
RUN ./atlas_start.py -setup || true
RUN ./atlas_start.py & \
    touch /opt/apache-atlas/logs/application.log \
    && tail -f /opt/apache-atlas/logs/application.log | sed '/Defaulting to local host name/ q' \
    && sleep 10 \
    && ./atlas_stop.py \
    && truncate -s0 /opt/apache-atlas/logs/application.log

CMD ["/bin/bash", "-c", "/opt/apache-atlas/bin/atlas_start.py; tail -fF /opt/apache-atlas/logs/application.log"]
