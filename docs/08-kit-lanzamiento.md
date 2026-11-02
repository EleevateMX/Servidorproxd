# 8. Kit de lanzamiento de Próxima RP

*Tu próxima vida empieza aquí.*

## 1. Portal de Cfx.re (portal.cfx.re → Server Keys → Generate)

| Campo | Copia esto |
|---|---|
| NAME | Próxima RP \| Latam |
| TAGLINE | Tu próxima vida empieza aquí · Rol en español para toda Latinoamérica |
| DESCRIPTION | Servidor de rol en español para toda Latinoamérica. Vive tu historia en Los Santos o compite en modos de juego: todos contra todos, deathmatch por equipos, rey de la colina y carreras. |
| LANGUAGE | Español (la variante de Latinoamérica si aparece) |
| TAGS | roleplay, español, latinoamerica, latam, modos de juego |
| BANNER IMAGE | brand/portal/proxima-rp-banner-1865x200.png |
| ICON | brand/portal/proxima-rp-icono-512.png |

Guarda la clave que te da el portal: la pedirá txAdmin. Es secreta, no la compartas.

## 2. Contratar el hosting

- Proveedor autorizado de la lista oficial: https://fivem.net/server-hosting
- Producto FiveM **con txAdmin**, 48 plazas o menos (no necesitas suscripción).
- Centro de datos en **Norteamérica** (mejor ping para Latinoamérica).
- Sin base de datos por ahora. Con protección DDoS y acceso FTP.

## 3. Instalar Próxima RP (txAdmin)

1. Abre txAdmin desde el panel del hosting y entra con tu cuenta de Cfx.re.
2. Asistente → **Remote URL Template** → pega:
   https://raw.githubusercontent.com/EleevateMX/Servidorproxd/HEAD/recipe.yaml
3. Pega tu clave de licencia cuando la pida.
4. En el editor de server.cfg que aparece al final:
   - `set pxd_props_webToken "..."` → un token de 24+ caracteres (ver abajo) para el dashboard de props.
   - `set pxd_login_accessCode "..."` → solo si quieres servidor privado con código.
5. **Save & Run Server**.
6. En FiveM: F8 → `connect IP:PUERTO` (los da el panel del hosting).

Generar un token en PowerShell (Windows):

    -join ((1..32) | ForEach-Object { '{0:x2}' -f (Get-Random -Maximum 256) })

## 4. Ya dentro

| Qué | Cómo |
|---|---|
| Modos de juego | F7 o /modos |
| Editor de props (staff) | F6 o /props |
| Dashboard de props | http://IP:PUERTO/pxd_props/ (con el token) |
| Guardar un sitio para diseños | /ancla nombre |
| Volver a la bienvenida | /bienvenida |
| Salir de una partida | /salirmodo |
| Añadir staff | txAdmin → CFG Editor → permissions.cfg → `add_principal identifier.license:XXXX group.admin` |

## 5. Todo lo demás

- Código del servidor: https://github.com/EleevateMX/Servidorproxd (rama claude/stoic-wozniak-k6fi8y)
- Descargar en ZIP: https://github.com/EleevateMX/Servidorproxd/archive/refs/heads/claude/stoic-wozniak-k6fi8y.zip
- Guías: docs/07-hosting-oficial.md (hosting) y docs/04-editor-de-props.md (diseños).
- Marca: logo SVG, voz de bienvenida (ElevenLabs) y capturas en brand/ y pxd_loadscreen/html/assets/.
- Fondo y vídeo de Kling: los instala la receta solos. Para tenerlos en tu PC: `node scripts/fetch-brand-assets.mjs` dentro del repo.

## Colores

Noche #05070f · Estrella #5ce1ff · Nova #ff4fd8 · Oro #ffc857
