# Bot de Discord de Próxima RP. Se construye desde la raíz del repo (ver deploy/docker-compose.yml).
FROM node:22-alpine
WORKDIR /app/discord
COPY discord/package.json discord/package-lock.json ./
RUN npm ci --omit=dev && mkdir data && chown node:node data
COPY discord/src ./src
COPY brand /app/brand
USER node
CMD ["node", "src/bot.js"]
