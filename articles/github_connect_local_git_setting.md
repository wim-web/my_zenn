---
title: "GitのクライアントでGithubのアイコンが表示されないとき"
emoji: "🤝"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["Git", "GitHub"]
published: true
---

## アイコンが表示されない

Gitの履歴を見たりするのに[Fork](https://git-fork.com/)というGUIクライアントを使っているのですが、なぜかローカルでコミットするとアイコンが表示されず、GitHub上でマージなどしたコミットにはアイコンが表示される状態でした。

![commits](https://github.com/wim-web/my_zenn/blob/master/image/github_connect_local_git_setting/commits.png?raw=true)

調べてみるとGitHub上で登録したアドレスとローカルのGitで設定してあるアドレスが違うと表示されないとのことでした。

しかし、<https://github.com/settings/emails> のPrimary email addressで登録してあるアドレスと `git config --global user.email` で確認したローカルでのアドレスは一緒のものでした。

しばらく途方に暮れていたのですがアイコンが表示できているコミットのAuthorを見てみると、ドメインが `@users.noreply.github.com` という見慣れないアドレスになっていました。

GitHubの設定画面をよく見てみるとちゃんと書いてありました。

> Because you have email privacy enabled, '登録したアドレス' will be used for account-related notifications as well as password resets. ~@users.noreply.github.com will be used for web-based Git operations, e.g., edits and merges.

GitHubの設定では登録したアドレスを他のユーザーに見られないようにするためにKeep my email addresses privateという設定があり、それの設定を有効にしていました。

ローカルのアドレス設定をGitHubが発行したものに変更してコミットするとちゃんとアイコンが表示されました。
