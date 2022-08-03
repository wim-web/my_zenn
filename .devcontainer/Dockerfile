ARG VARIANT="18-bullseye"
FROM mcr.microsoft.com/vscode/devcontainers/javascript-node:${VARIANT}

RUN apt update && apt install -y vim
RUN yarn global add zenn-cli@0.1.116
