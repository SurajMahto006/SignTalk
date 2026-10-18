FROM node:22-alpine
WORKDIR /app
COPY tools/signaling-server/package.json tools/signaling-server/package-lock.json ./
RUN npm ci --omit=dev
COPY tools/signaling-server/server.js tools/signaling-server/signaling-room.js tools/signaling-server/signaling-logic.js ./
COPY build/web ./public
ENV STATIC_DIR=/app/public
ENV PORT=8080
EXPOSE 8080
CMD ["node", "server.js"]
