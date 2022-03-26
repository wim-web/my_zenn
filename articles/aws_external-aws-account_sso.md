---
title: "AWS SSOでOrganization外(External AWS Account)のアカウントにSSOする設定"
emoji: "😊"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["AWS"]
published: true
---

## 参考

[AWS Single Sign-On (AWS SSO) Integration Guide for External AWS Account](https://static.global.sso.amazonaws.com/app-4a24b6fe5e450fa2/instructions/index.htm)

## 設定の流れ

元となるアカウント（起点となるアカウント）をSSO側、外部のアカウントをExternal AWS Accountと表記してあります。

主な流れは SSO側 -> External AWS Account -> SSO側 になります。

### SSO側

AWS SSO > アプリケーションから「新規アプリケーションの追加」をクリックします。

アプリケーションカタログでExternal AWS Accountを選択しアプリケーションの追加をクリックします。

![add_new_application](https://github.com/wim-web/my_zenn/blob/master/image/aws_external-aws-account_sso/add_new_application.png?raw=true)

表示名はSSOのユーザーポータルで表示されるのでわかりやすい名前で登録してください。
表示名はユニークでなければいけないので、同じアプリケーションで権限を分けたい場合は権限も表示名に含めると良いです。

> External AWS Account service only supports one IAM Role attribute mapping per application instance. So, you would have to create multiple External AWS Account application instances to use multiple roles.

> We suggest that you choose a unique display name if you plan to have more than one of the same application.

![application_configuration](https://github.com/wim-web/my_zenn/blob/master/image/aws_external-aws-account_sso/application_configuration.png?raw=true)

セッション期間がデフォルトで1時間になっているので変更したい場合は変更しておきましょう。

AWS SSOメタデータをダウンロードして変更の保存をします。

### External AWS Account側

IAM > IDプロバイダから「プロバイダを追加」をクリックします。

プロバイダのタイプはSAMLを選択しプロバイダ名を入力後に、さきほどダウンロードしたメタデータをアップロードします。

![add_id-provider](https://github.com/wim-web/my_zenn/blob/master/image/aws_external-aws-account_sso/add_id-provider.png?raw=true)

次にIAM > ロールからSSOしたときに割り当てたい権限をもつロールを作成します。
（カスタムポリシーをアタッチしたい場合は事前に作成しておいてください。）

信頼されたエンティティの種類はSAML 2.0 フェデレーションを選択し、さきほど作成したプロバイダーを選んだあと次のステップにすすんでください。

![role_for_provider](https://github.com/wim-web/my_zenn/blob/master/image/aws_external-aws-account_sso/role_for_provider.png?raw=true)

あとは普通のロールと同じ要領でポリシーをアタッチしてください。

### SSO側

AWS SSO > アプリケーションから属性マッピングタブを選び新規属性マッピングの追加をクリックして以下を参考に空欄を埋めていきます。

- アプリケーションのユーザー属性: https://aws.amazon.com/SAML/Attributes/Role
- この文字列値または AWS SSO のユーザー属性にマッピング: arn:aws:iam::ACCOUNTID:saml-provider/SAMLPROVIDERNAME,arn:aws:iam::ACCOUNTID:role/ROLENAME
    - ACCOUNTID: 対象のAWSアカウントのID
    - SAMLPROVIDERNAME: さきほど作成したプロバイダ名
    - ROLENAME: さきほど作成したロール名
- 形式: unspecified

![attribute_mapping](https://github.com/wim-web/my_zenn/blob/master/image/aws_external-aws-account_sso/attribute_mapping.png?raw=true)

これでSSOの準備ができたので作成したアプリケーションにユーザーやグループを割り当てるとSSOのユーザーポータルに作成したアプリケーションが表示されます。

クリックして対象のAWSアカウントにログインできれば成功です！