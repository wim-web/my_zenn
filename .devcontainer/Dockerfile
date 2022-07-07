ARG VARIANT="bullseye"
FROM mcr.microsoft.com/vscode/devcontainers/javascript-node:16-${VARIANT}

RUN apt update && apt install -y vim
RUN yarn global add zenn-cli@0.1.114
