# ──────────────────────────────────────────────────────────────────────────
# Stage 1: build Flutter web. Dùng image Flutter SDK (cirruslabs — de-facto
# standard). `flutter build web --release` chạy ở đây → ra build/web/.
# ──────────────────────────────────────────────────────────────────────────
FROM ghcr.io/cirruslabs/flutter:stable AS build

# Flutter SDK trong image owned bởi user khác → git kêu "unsafe repository".
RUN git config --global --add safe.directory /sdks/flutter

WORKDIR /app

# Cache layer pub get: chỉ copy pubspec trước, get deps, rồi mới copy source.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy phần source còn lại (lib/, web/, assets/, ...) — xem .dockerignore.
COPY . .
RUN flutter build web --release

# ──────────────────────────────────────────────────────────────────────────
# Stage 2: serve static bằng nginx alpine (~25 MB). Flutter SDK ở stage 1
# bị discard hết — image cuối chỉ nginx + build/web/ (~50 MB).
# ──────────────────────────────────────────────────────────────────────────
FROM nginx:1.27-alpine

RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web/ /usr/share/nginx/html/

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
