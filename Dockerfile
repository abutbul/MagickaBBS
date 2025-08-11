## Multi-stage build for MagickaBBS with WWW support
FROM debian:stable-slim AS build

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    make \
    ca-certificates \
    libsqlite3-dev \
    libssl-dev \
    libssh-dev \
    libmicrohttpd-dev \
    zlib1g-dev \
    libreadline-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . .

# Build with WWW enabled (Makefile.linux.WWW sets -DENABLE_WWW)
RUN make -f Makefile.linux.WWW magicka

## Runtime image
FROM debian:stable-slim AS runtime
LABEL org.opencontainers.image.title="MagickaBBS" \
      org.opencontainers.image.source="https://github.com/abutbul/MagickaBBS" \
      org.opencontainers.image.description="Classic style BBS with optional web/SSH frontends" \
      org.opencontainers.image.licenses="MIT"

ENV DEBIAN_FRONTEND=noninteractive \
    DATA_DIR=/data \
    ENABLE_WWW=true \
    ENABLE_SSH=false \
    ENABLE_FORK=false

RUN apt-get update && apt-get install -y --no-install-recommends \
    libsqlite3-0 \
    libssl3 \
    libssh-4 \
    libmicrohttpd12 \
    zlib1g \
    libreadline8 \
 && rm -rf /var/lib/apt/lists/*

# Create app user
RUN useradd -r -m -d /opt/magicka magicka

WORKDIR /opt/magicka

# Copy binary
COPY --from=build /src/magicka /usr/local/bin/magicka

# Copy defaults (keep under /opt/magicka for seeding the data volume)
COPY config_default ./config_default
COPY ansis_default ./ansis_default
COPY www ./www_default
COPY magicka.strings ./magicka.strings

# Entry script
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

VOLUME ["/data"]

# Expose typical ports (can be toggled via config):
# 2023 Telnet, 2024 SSH, 8080 HTTP, 6667 MagiChat (IRC-like), 2027 UDP Broadcast
EXPOSE 2023 2024 8080 6667 2027/udp

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["magicka"]
