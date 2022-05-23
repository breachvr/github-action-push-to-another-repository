FROM alpine:latest

RUN apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/main git
RUN apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/main git-lfs

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
