ARG VARIANT="22-bullseye@sha256:42b4550b980e289ae43f1ffac3de1b8dabc943b3b415eb89a0f41cdcea791ad6"
FROM mcr.microsoft.com/vscode/devcontainers/javascript-node:${VARIANT}

RUN apt update && apt install -y vim
RUN yarn global add zenn-cli@0.1.155
