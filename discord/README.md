# Bot de Discord de Próxima RP

**Windows sin comandos:** doble clic en `1-configurar.bat`, `2-montar-servidor.bat` y `3-encender-bot.bat` (necesita Node.js de https://nodejs.org).

Monta el servidor de Discord (roles, canales, permisos y mensajes fijos) y lo mantiene: bienvenida, verificación, roles de avisos, tickets, `/anuncio` y contadores de jugadores.

```bash
cp .env.example .env
```
```bash
npm install
```
```bash
npm run setup -- --aplicar --icono
```
```bash
npm start
```

Guía completa: [docs/11-discord.md](../docs/11-discord.md).
