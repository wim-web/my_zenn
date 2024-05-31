ARG VARIANT="22-bullseye@sha256:4c58c0d235685eec0dfbf813b0e73d6f01a7d1785878713b201ad974c33f8324"
FROM mcr.microsoft.com/vscode/devcontainers/javascript-node:${VARIANT}

RUN apt update && apt install -y vim
RUN yarn global add zenn-cli@0.1.149
