FROM nginx:alpine

ARG PRIMARY_COLOR="#1e3a5f"
ARG SECONDARY_COLOR="#a7c7e7"
ARG SITE_NAME="ArgoCD-TrF-K8s-Demo"

COPY index.html /usr/share/nginx/html/index.html

RUN sed -i "s|#1e3a5f|${PRIMARY_COLOR}|g" /usr/share/nginx/html/index.html && \
    sed -i "s|#a7c7e7|${SECONDARY_COLOR}|g" /usr/share/nginx/html/index.html && \
    sed -i "s|SITE_NAME_PLACEHOLDER|${SITE_NAME}|g" /usr/share/nginx/html/index.html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]