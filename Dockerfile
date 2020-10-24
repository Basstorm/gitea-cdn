###################################
#Build stage
FROM golang:1.15-alpine3.12 AS build-env
ARG GOPROXY
ENV GOPROXY ${GOPROXY:-direct}
ARG GITEA_VERSION
ARG TAGS="sqlite sqlite_unlock_notify"
ENV TAGS "bindata timetzdata $TAGS"
ARG CGO_EXTRA_CFLAGS
#Build deps
RUN apk --no-cache add build-base git nodejs npm
#Setup repo
RUN cd ${GOPATH}/src \
  && go get -u code.gitea.io/gitea 
WORKDIR ${GOPATH}/src/code.gitea.io/gitea
#Do patch
RUN sed -i s#../fonts/noto-color-emoji/NotoColorEmoji.ttf#https://cdn.jsdelivr.net/npm/noto-color-emoji@1.0.1/ttf/NotoColorEmoji.ttf#g ${GOPATH}/src/code.gitea.io/gitea/web_src/less/_base.less \
  && cat ${GOPATH}/src/code.gitea.io/gitea/web_src/less/_base.less | grep NotoColorEmoji.ttf \
  && rm -rf ${GOPATH}/src/code.gitea.io/gitea/web_src/fonts/noto-color-emoji/NotoColorEmoji.ttf
#Checkout version if set
RUN if [ -n "${GITEA_VERSION}" ]; then git checkout "${GITEA_VERSION}"; fi \
 && make clean-all build
FROM alpine:3.12
LABEL maintainer="maintainers@gitea.io"
EXPOSE 22 3000
RUN apk --no-cache add \
    bash \
    ca-certificates \
    curl \
    gettext \
    git \
    linux-pam \
    openssh \
    s6 \
    sqlite \
    socat \
    su-exec \
    gnupg
RUN addgroup \
    -S -g 1000 \
    git && \
  adduser \
    -S -H -D \
    -h /data/git \
    -s /bin/bash \
    -u 1000 \
    -G git \
    git && \
  echo "git:$(dd if=/dev/urandom bs=24 count=1 status=none | base64)" | chpasswd
ENV USER git
ENV GITEA_CUSTOM /data/gitea
VOLUME ["/data"]
ENTRYPOINT ["/usr/bin/entrypoint"]
CMD ["/bin/s6-svscan", "/etc/s6"]
COPY docker/root /
COPY --from=build-env /go/src/code.gitea.io/gitea/gitea /app/gitea/gitea
RUN ln -s /app/gitea/gitea /usr/local/bin/gitea
