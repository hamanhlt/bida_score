# Nginx alpine ~25 MB. App tĩnh nên không cần Flutter SDK trong image —
# user `flutter build web --release` ở host trước, Docker chỉ copy + serve.
FROM nginx:1.27-alpine

# Xoá config mặc định, dùng config riêng (SPA fallback + gzip).
RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy artifact đã build.
COPY build/web/ /usr/share/nginx/html/

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
