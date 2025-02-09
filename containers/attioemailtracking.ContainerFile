FROM docker.io/library/ubuntu:24.04
ARG DEBIAN_FRONTEND=noninteractive

RUN groupadd nimgroup \
    && useradd -m attio -d /home/attio -s /bin/bash \
    && usermod -a -G nimgroup,sudo attio \
    && mkdir -p /home/attio \
    && chown -R attio:nimgroup /home/attio \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
      ca-certificates \
      libpq-dev \
      libpcre3-dev

WORKDIR /home/attio

COPY attio_email_tracking /home/attio/attio_email_tracking

CMD ["/home/attio/attio_email_tracking"]

#podman build -f containers/attioemailtracking.ContainerFile . -t attioemailtracking
#podman tag attioemailtracking <repo>/attioemailtracking:latest
#podman push <repo>/attioemailtracking:latest
