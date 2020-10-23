FROM node:14.14.0-alpine3.12

RUN apk add --no-cache tini
RUN npm i -g zenn-cli@latest

WORKDIR /work

ENTRYPOINT [ "/sbin/tini", "--", "npx", "zenn" ]
CMD [ "preview" ]