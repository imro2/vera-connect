FROM alpine:latest

ENV LOCAL_PORT=7676
ENV REMOTE_PORT=7676

ARG USER=sshtunnel
ARG GROUP=sshtunnel
ARG UID=1024
ARG GID=1024

RUN mkdir /vera
COPY scripts/run.sh /vera/run.sh 

RUN addgroup -S -g ${GID} ${GROUP} \
    && adduser -S -D -H -s /bin/false -g "${USER} service" \
           -u ${UID} -G ${GROUP} ${USER} \
    && set -x \
    && apk add --no-cache openssh-client netcat-openbsd

RUN mkdir -p /home/${USER}/.ssh && chown -R ${USER}:${GROUP} /home/${USER}

USER ${USER}

CMD ["/vera/run.sh"]
