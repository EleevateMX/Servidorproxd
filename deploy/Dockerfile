# Próxima RP — imagen para desplegar el servidor en un VPS Linux con Docker.
# Construye con el build RECOMENDADO de FXServer para Linux (API oficial de versiones,
# la misma que usa txAdmin). Para fijar otro: --build-arg FX_ARTIFACT_URL=<enlace fx.tar.xz>
# Nota oficial: el FXServer de Linux es un «port de cortesía»; los arreglos llegan antes a Windows.
FROM debian:bookworm-slim

ARG FX_ARTIFACT_URL=""
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl xz-utils git \
 && rm -rf /var/lib/apt/lists/*

# Binarios de FXServer
RUN set -eu; \
    url="$FX_ARTIFACT_URL"; \
    if [ -z "$url" ]; then \
      url="$(curl -fsS https://changelogs-live.fivem.net/api/changelog/versions/linux/server \
        | grep -o '"recommended_download":"[^"]*"' | cut -d'"' -f4)"; \
    fi; \
    echo "FXServer: $url"; \
    mkdir -p /opt/fxserver; \
    curl -fL "$url" -o /tmp/fx.tar.xz; \
    tar -xf /tmp/fx.tar.xz -C /opt/fxserver; \
    rm /tmp/fx.tar.xz

# Recursos base de cfx-server-data
RUN git clone --depth 1 https://github.com/citizenfx/cfx-server-data.git /tmp/cfx \
 && mkdir -p "/srv/server-data/resources/[cfx]" \
 && cp -r /tmp/cfx/resources/. "/srv/server-data/resources/[cfx]/" \
 && rm -rf /tmp/cfx

# Configuración y recursos de Próxima RP (los secretos se generan al arrancar)
COPY server-data/server.cfg server-data/permissions.cfg /srv/server-data/
# Se copia la carpeta resources entera: Docker trata los corchetes de "[proxima]" como patrón.
# Lo que no debe entrar (p. ej. [cfx] local, datos) lo filtra .dockerignore.
COPY server-data/resources /srv/server-data/resources
COPY deploy/entrypoint.sh /usr/local/bin/proxima-entrypoint
RUN chmod +x /usr/local/bin/proxima-entrypoint \
 && useradd --system --create-home --home-dir /home/fx fx \
 && chown -R fx:fx /srv/server-data /opt/fxserver

USER fx
WORKDIR /srv/server-data
EXPOSE 30120/tcp 30120/udp
ENTRYPOINT ["proxima-entrypoint"]
