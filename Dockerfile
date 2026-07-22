# ============================================================
#  STAGE 1 – Builder (Node.js)
#  Build Astro project → output static files to /app/dist
# ============================================================
FROM node:20-alpine AS builder

WORKDIR /app

# Copy dependency manifests first (layer cache optimization)
COPY package.json package-lock.json* ./

# Install dependencies (skip devDependencies later at runtime stage)
RUN npm install
RUN npm ci 

# Copy source code
COPY . .

# Build Astro static output
RUN npm run build

# ============================================================
#  STAGE 2 – Runner (Nginx)
#  Serve the built /dist with a lean Alpine Nginx image
# ============================================================
FROM nginx:stable-alpine AS runner

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/app.conf

# Copy built static files from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Nginx runs on port 80 internally
# (NPM on proxy-net will forward traffic here — no host port binding needed)
EXPOSE 80

# Health check: ensure nginx is serving
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:80/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
