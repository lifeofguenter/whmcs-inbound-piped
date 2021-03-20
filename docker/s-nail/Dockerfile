FROM alpine:3

ENTRYPOINT ["mail"]

RUN apk --no-cache add \
  bash \
  s-nail && \
  adduser -D app

USER app
WORKDIR /app
