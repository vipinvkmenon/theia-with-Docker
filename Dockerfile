
ARG NODE_VERSION=12.18.3
FROM node:${NODE_VERSION}-alpine as node_base


# Use DOCKER DIND and modify for rootless
FROM docker:20.10-dind

COPY --from=node_base . .

RUN echo http://dl-2.alpinelinux.org/alpine/edge/community/ >> /etc/apk/repositories
RUN apk --no-cache add shadow
# busybox "ip" is insufficient:
#   [rootlesskit:child ] error: executing [[ip tuntap add name tap0 mode tap] [ip link set tap0 address 02:50:00:00:00:01]]: exit status 1
RUN apk add --no-cache iproute2

# "/run/user/UID" will be used by default as the value of XDG_RUNTIME_DIR
RUN mkdir /run/user && chmod 1777 /run/user

# create a default user preconfigured for running rootless dockerd
RUN set -eux; \
	adduser -h /home/theia -g 'Rootless' -s /bin/sh -D -u 1001 rootless; \
	echo 'rootless:100000:65536' >> /etc/subuid; \
	echo 'rootless:100000:65536' >> /etc/subgid

RUN set -eux; \
	\
	apkArch="$(apk --print-arch)"; \
	case "$apkArch" in \
		'x86_64') \
			url='https://download.docker.com/linux/static/stable/x86_64/docker-rootless-extras-20.10.7.tgz'; \
			;; \
		*) echo >&2 "error: unsupported architecture ($apkArch)"; exit 1 ;; \
	esac; \
	\
	wget -O rootless.tgz "$url"; \
	\
	tar --extract \
		--file rootless.tgz \
		--strip-components 1 \
		--directory /usr/local/bin/ \
		'docker-rootless-extras/rootlesskit' \
		'docker-rootless-extras/rootlesskit-docker-proxy' \
		'docker-rootless-extras/vpnkit' \
	; \
	rm rootless.tgz; \
	\
	rootlesskit --version; \
	vpnkit --version

# pre-create "/var/lib/docker" for our rootless user
RUN set -eux; \
	mkdir -p /home/theia/.local/share/docker; \
	chown -R rootless /home/theia/.local/share/docker

# Setup for theia
RUN addgroup theia && \
    usermod -a -G theia rootless

VOLUME /home/theia/.local/share/docker


RUN apk add --no-cache make pkgconfig gcc g++ python libx11-dev libxkbfile-dev
ARG version=latest
ADD $version.package.json ./package.json


ARG GITHUB_TOKEN

RUN yarn --pure-lockfile && \
    NODE_OPTIONS="--max_old_space_size=4096" yarn theia build && \
    yarn theia download:plugins && \
    yarn --production && \
    yarn autoclean --init && \
    echo *.ts >> .yarnclean && \
    echo *.ts.map >> .yarnclean && \
    echo *.spec.* >> .yarnclean && \
    yarn autoclean --force && \
    yarn cache clean



RUN chmod g+rw /home && \
    mkdir -p /home/project && \
    chown -R rootless /home/theia && \
    chown -R rootless /home/project &&\
	chown -R rootless /src-gen && \
	chown -R rootless /plugins;

RUN apk add --no-cache git openssh bash
ENV HOME /home/theia

WORKDIR /home/theia

ADD $version.package.json /home/theia/package.json
RUN chown -R rootless /home/theia

COPY init-docker-env /usr/local/bin
RUN chmod 777 /usr/local/bin/init-docker-env

# More user friendly name
RUN mv /usr/local/bin/dockerd-entrypoint.sh /usr/local/bin/start-dockerd
RUN chmod 777 /usr/local/bin/start-dockerd

EXPOSE 3000

ENV SHELL=/bin/bash \
    THEIA_DEFAULT_PLUGINS=local-dir:/plugins
ENV USE_LOCAL_GIT true
# Setup for docker group
RUN groupadd docker
RUN usermod -a -G docker rootless

RUN apk --no-cache add curl

RUN curl -Lo /usr/local/bin/kyma https://storage.googleapis.com/kyma-cli-stable/kyma-linux
RUN chmod 777 /usr/local/bin/kyma

RUN curl -Lo /usr/local/bin/kubectl "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
RUN chmod 777 /usr/local/bin/kubectl

RUN curl  -fsLO https://github.com/istio/istio/releases/download/1.10.1/istioctl-1.10.1-linux-amd64.tar.gz
RUN tar -xzf istioctl-1.10.1-linux-amd64.tar.gz && rm istioctl-1.10.1-linux-amd64.tar.gz
RUN mv istioctl /usr/local/bin && chmod 777 /usr/local/bin/istioctl

RUN curl -fsLO https://get.helm.sh/helm-v3.6.0-linux-amd64.tar.gz
RUN tar -zxvf helm-v3.6.0-linux-amd64.tar.gz && rm helm-v3.6.0-linux-amd64.tar.gz
RUN mv linux-amd64/helm /usr/local/bin/helm
RUN chmod 777 /usr/local/bin/helm

USER rootless

#istioctl
RUN export PATH=$PATH:$HOME/.istioctl/bin

ENTRYPOINT ["node", "/src-gen/backend/main.js", "/home/project", "--hostname=0.0.0.0" ]


