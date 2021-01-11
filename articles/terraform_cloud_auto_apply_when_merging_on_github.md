---
title: "GitHubでmergeしたときにTerraform Cloudでauto-applyする"
emoji: "🐈"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["Terraform Cloud"]
published: true
---

## はじめに

この記事ではGitHub上でPRを出すとTerraform Cloudでplanが走り、masterブランチにmergeするとTerraform Cloudでapplyされるように設定します。

## Terraform Cloudの設定

前提として対象のWorkspaceが作成されていることとします。

設定はは簡単でGeneral SettingsのApply MethodをAuto applyにするだけです。

![auto-apply_setting](https://github.com/wim-web/my_zenn/blob/master/image/terraform_cloud_auto_apply_when_merging_on_github/auto-apply_setting.png?raw=true)

Auto applyだとPR時もapplyされてしまいそうですが、説明に書いてあるとおりGitHubのデフォルトブランチにpushされたときのみ自動applyされます。

## 余談

GitHubのBranch protection ruleでPR時にPlanが成功しないとmergeができないように設定できるのでチーム開発時に便利です。

![protection_rule](https://github.com/wim-web/my_zenn/blob/master/image/terraform_cloud_auto_apply_when_merging_on_github/protection_rule.png?raw=true)