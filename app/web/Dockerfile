FROM node:24-alpine

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund

COPY . .
ARG DJANGO_API_ORIGIN=http://api:8000
ENV DJANGO_API_ORIGIN=${DJANGO_API_ORIGIN}
RUN npm run build

ENV NODE_ENV=production
EXPOSE 3000
CMD ["npm", "run", "start", "--", "--hostname", "0.0.0.0"]
