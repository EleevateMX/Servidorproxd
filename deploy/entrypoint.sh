#!/usr/bin/env sh
# Genera secrets.cfg desde variables de entorno y arranca FXServer.
set -eu
: "${FX_LICENSE_KEY:?Falta FX_LICENSE_KEY (clave de https://portal.cfx.re)}"
: "${PXD_PROPS_WEB_TOKEN:?Falta PXD_PROPS_WEB_TOKEN (24+ caracteres)}"
if [ "${#PXD_PROPS_WEB_TOKEN}" -lt 24 ]; then echo "PXD_PROPS_WEB_TOKEN debe tener 24+ caracteres" >&2; exit 1; fi

# Rechaza comillas para no romper el .cfg.
for v in "$FX_LICENSE_KEY" "$PXD_PROPS_WEB_TOKEN" "${PXD_LOGIN_ACCESS_CODE:-}" "${FX_ADMIN_IDENTIFIERS:-}"; do
  case "$v" in *\"*) echo "Las variables no pueden contener comillas" >&2; exit 1;; esac
done

{
  echo "sv_licenseKey \"$FX_LICENSE_KEY\""
  echo "set pxd_props_webToken \"$PXD_PROPS_WEB_TOKEN\""
  echo "set pxd_login_accessCode \"${PXD_LOGIN_ACCESS_CODE:-}\""
  [ -n "${FX_MAXCLIENTS:-}" ] && echo "sv_maxclients ${FX_MAXCLIENTS}"
  # Identificadores de staff separados por comas, p. ej. license:abc,fivem:123
  if [ -n "${FX_ADMIN_IDENTIFIERS:-}" ]; then
    echo "$FX_ADMIN_IDENTIFIERS" | tr ',' '\n' | while read -r id; do
      [ -n "$id" ] && echo "add_principal identifier.$id group.admin"
    done
  fi
} > /srv/server-data/secrets.cfg
chmod 600 /srv/server-data/secrets.cfg

exec bash /opt/fxserver/run.sh +exec server.cfg
