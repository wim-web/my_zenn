FROM mcr.microsoft.com/devcontainers/javascript-node:24-bookworm@sha256:16eb68aa0d17eedaaf2566b180854fe4e506478e35aadf790fb02aa089024f13

ENV NODE_VERSION=24.22.1

# Update the OS trust store before downloading the patched Node.js runtime.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates fish vim \
    && dpkg --compare-versions "$(dpkg-query -W -f='${Version}' ca-certificates)" ge '20250419~deb12u2' \
    && rm -rf /var/lib/apt/lists/*

# The pinned devcontainer image predates the eMudhra fix. nvm verifies the
# official binary's checksum; replace the image's system runtime as well.
RUN bash -c 'set -euo pipefail; \
    source "$NVM_DIR/nvm.sh"; \
    nvm install "$NODE_VERSION"; \
    nvm alias default "$NODE_VERSION"; \
    nvm use default; \
    ln -sfn "$NVM_DIR/current/bin/node" /usr/local/bin/node; \
    test "$(node --version)" = "v$NODE_VERSION"; \
    test "$(/usr/local/bin/node --version)" = "v$NODE_VERSION"'

RUN yarn global add zenn-cli@0.1.155
