# Base on offical Node.js Alpine image
FROM node:18-alpine as base

# Install dependencies only when needed
FROM base AS deps
# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
RUN apk add --no-cache libc6-compat
# Set working directory
WORKDIR /usr/app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install dependencies
RUN npm ci

FROM base AS builder
WORKDIR /usr/app
COPY --from=deps /usr/app/node_modules ./node_modules

LABEL org.opencontainers.image.source https://github.com/Invotyx/myformatic-frontend

ARG APP_NAME
ARG REACT_APP_BASE_URL
ARG STRIPE_PUBLISHABLE_KEY
ARG GOOGLE_APP_ID
ARG NEXT_PUBLIC_GOOGLE_DEVELOPER_KEY

ENV APP_NAME=${APP_NAME}
ENV REACT_APP_BASE_URL=${REACT_APP_BASE_URL}
ENV STRIPE_PUBLISHABLE_KEY=${STRIPE_PUBLISHABLE_KEY}
ENV GOOGLE_APP_ID=${GOOGLE_APP_ID}
ENV NEXT_PUBLIC_GOOGLE_DEVELOPER_KEY=${NEXT_PUBLIC_GOOGLE_DEVELOPER_KEY}
ENV PUSHER_APP_KEY=3c5baf855144ca0df174
ENV PUSHER_APP_CLUSTER=eu
ENV PUSHER_CHANNEL_NAME=myformatic

# Copy all files
COPY . .

# Build app
RUN npm run build

# Start a new stage for production dependencies
FROM base as prod-deps
WORKDIR /usr/app
COPY --from=builder /usr/app/package*.json ./
# Install production dependencies only
RUN npm install --omit=dev

# Start a new stage from scratch
FROM base as runner

WORKDIR /usr/app

# Copy only the necessary from the "builder" stage
COPY --from=builder /usr/app/.next ./.next
COPY --from=builder /usr/app/public ./public
COPY --from=builder /usr/app/package.json ./
COPY --from=prod-deps /usr/app/node_modules ./node_modules

# Expose the listening port
EXPOSE 3000

RUN chown -R node:node /usr/app/.next/

# Run container as non-root (unprivileged) user
# The node user is provided in the Node.js Alpine base image
USER node

# Run yarn start script when container starts
CMD [ "npm", "start" ]