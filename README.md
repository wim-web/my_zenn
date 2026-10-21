# For Zenn

Zennとの連携用Repository

[my articles in zenn](https://zenn.dev/wim)

## required

- Docker

## 開発環境

Node.js は `.node-version` の **24.22.1**、Yarn は **1.22.22** を使用します。
CIとdevcontainerを更新するときは、`.node-version`、`package.json` の `engines`、
`.devcontainer/Dockerfile` の `NODE_VERSION` をそろえてください。

devcontainerはdigest固定した `24-bookworm` イメージを使用します。
このベースイメージのNode.jsは修正前のため、DockerfileでOSのCA証明書を更新してから、
nvmのチェックサム検証付きで公式Node.js 24.22.1へ更新し、古いNode.jsを置換します。
OSのCA証明書更新だけでは、Node.jsの組込CAへの対策は完了しません。

既存のdevcontainerは、VS Codeの **Dev Containers: Rebuild Container Without Cache** で再作成してください。
再作成後に以下を確認します。

```sh
node --version # v24.22.1
/usr/local/bin/node --version # v24.22.1
yarn --version # 1.22.22
zenn --version # 0.1.155
yarn install --frozen-lockfile
yarn run textlint -f checkstyle "articles/**" "books/**"
```

## eMudhra中間CA秘密鍵漏えいへの対応

2026-10-21時点で、Node.js 24系の修正版は [24.22.1](https://github.com/nodejs/node/releases/tag/v24.22.1) です。
CIのreviewdogは既存のバージョンを維持し、[Go 1.27.3](https://go.dev/doc/devel/release#go1.27.0) で
毎回ビルドして使用します。既存の配布バイナリは、OSのCA更新だけで修正済みとは判断できません。

GitHub Actions自身のNode.jsランタイムとホストOSのCA更新はGitHub管理です。
`setup-node` は後続コマンド用のNode.jsを設定するため、Actions自身のランタイムの更新とは別に確認が必要です。
既存のdevcontainerやキャッシュ済みイメージは自動では更新されません。再ビルド・再作成してから利用してください。
Zenn側のビルド環境はこのリポジトリでは管理していません。

背景と検証用ホスト: [eMudhra Intermediate CA Compromise](https://emudhra.we-have-a-problem.com/)
