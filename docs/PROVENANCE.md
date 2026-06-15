# Provenance & verification / 原创性与防篡改

This document explains how the authorship of **openclaw-free-deploy** is
established and, more importantly, how to make it **tamper-evident** so that a
copy cannot credibly be passed off as someone else's work.

本文件说明本项目的著作权如何确立，以及——更重要的——如何让它**可被验证、难以
被冒认**。

---

## The honest reality / 先讲实话

A plaintext notice (in `NOTICE`, `LICENSE`, a README badge, or a source header)
states authorship, but **anyone who forks the repo can edit that text**. Text
alone is not tamper-proof. Real protection comes from three things that a copier
*cannot* fake:

1. **The MIT license** legally *requires* your copyright notice to be kept in
   every copy. Stripping it is a license violation — this is your enforceable
   claim.
2. **Cryptographic signatures** on your Git commits and release tags. They are
   produced with a private key only you hold; nobody can forge a valid signature
   for your identity.
3. **The canonical repository under your account** plus its timestamped Git
   history. Forks visibly show “forked from ldcstc-gif/…”, and commit hashes
   form a chain that cannot be rewritten without detection.

纯文本声明（`NOTICE`/`LICENSE`/README 徽章/源码头部）能写明作者，但**任何人 fork
后都能改掉这些文字**，所以单靠文本无法防篡改。真正难以伪造的是三样东西：①
MIT 许可证在法律上要求保留你的版权声明（删除即违规）；② 用只有你持有的私钥对
提交与发布标签进行**密码学签名**；③ 你账号下的官方仓库及带时间戳的 Git 历史
（fork 会显示来源，提交哈希构成不可篡改的链）。

This repo ships the *claim* (notices everywhere) and the *tooling* for the
*proof* (signing + checksums). The signing steps below need **your** key, so you
must run them once.

本仓库已铺好"声明"（多处署名）与"证明"工具（签名 + 校验和）。下面的签名步骤需要
**你自己的密钥**，请执行一次。

---

## 1. Sign your commits (GitHub "Verified") / 让提交显示 Verified

The simplest method if you already have an SSH key on GitHub is **SSH commit
signing**.

如果你的 GitHub 已绑定 SSH 公钥，用 **SSH 提交签名**最简单：

```bash
# Tell git to sign with SSH, using your existing key.
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true
git config --global tag.gpgsign true

# Make sure your git identity matches the GitHub account.
git config --global user.name  "ldcstc-gif"
git config --global user.email "<the email verified on your GitHub account>"
```

Then add the **same** public key on GitHub as a *Signing key* (not only an
Authentication key): GitHub → Settings → SSH and GPG keys → New SSH key → type
"Signing Key". New commits will then show a green **Verified** badge.

随后在 GitHub 把**同一把**公钥再添加为 *Signing Key*（不只是 Authentication
Key）：Settings → SSH and GPG keys → New SSH key → 类型选 "Signing Key"。之后新
提交就会显示绿色 **Verified**。

> Prefer GPG? Use `git config --global gpg.format openpgp`, create a key with
> `gpg --full-generate-key`, and upload the public key under Settings → SSH and
> GPG keys → New GPG key.
>
> 想用 GPG：把上面的 `gpg.format` 设为 `openpgp`，用 `gpg --full-generate-key`
> 生成密钥，再到同一页面 "New GPG key" 上传公钥。

---

## 2. Make a signed release tag / 打一个签名的发布标签

A signed, annotated tag freezes a specific version under your identity:

签名的附注标签把某个版本固定在你的身份下：

```bash
git tag -s v2.0.0 -m "openclaw-free-deploy v2.0.0 — signed by ldcstc-gif"
git push origin v2.0.0
```

Anyone can verify it:

任何人都可验证：

```bash
git verify-tag v2.0.0          # SSH or GPG signature must check out
```

On the GitHub Releases page the tag will show as **Verified**.

在 GitHub Releases 页面，该标签会显示 **Verified**。

---

## 3. Checksum manifest for release artifacts / 发布物的校验和清单

For the downloadable `.zip`/`.tar.gz`, ship a signed checksum manifest so any
byte-level change is detectable:

对于可下载的 `.zip`/`.tar.gz`，附上签名的校验和清单，任何字节级改动都能被发现：

```bash
chmod +x scripts/gen-checksums.sh
./scripts/gen-checksums.sh                 # writes SHA256SUMS
gpg --armor --detach-sign SHA256SUMS       # writes SHA256SUMS.asc (your key)
```

Attach **both** `SHA256SUMS` and `SHA256SUMS.asc` to the GitHub Release.

把 `SHA256SUMS` 和 `SHA256SUMS.asc` **两个文件**都附到 GitHub Release。

Anyone verifies authenticity + integrity with:

任何人这样同时验证真伪与完整性：

```bash
gpg --verify SHA256SUMS.asc SHA256SUMS     # authenticity: signed by you
sha256sum -c SHA256SUMS                     # integrity: files unmodified
```

(SSH-signing a file instead of GPG:
`ssh-keygen -Y sign -f ~/.ssh/id_ed25519 -n file SHA256SUMS`, verify with
`ssh-keygen -Y verify`.)

（若用 SSH 而非 GPG 签名文件：用 `ssh-keygen -Y sign ...` 生成签名，
`ssh-keygen -Y verify ...` 验证。）

---

## 4. What a verifier should check / 验证者应核对什么

1. The repo is, or is forked from, **github.com/ldcstc-gif/openclaw-free-deploy**.
2. Recent commits and the release tag show a **Verified** badge.
3. `LICENSE` and `NOTICE` still name **ldcstc-gif** as the author/copyright holder.
4. For a downloaded archive, `SHA256SUMS` checks out and `SHA256SUMS.asc`
   verifies against ldcstc-gif's public key.

1. 仓库就是 / fork 自 **github.com/ldcstc-gif/openclaw-free-deploy**。
2. 近期提交与发布标签显示 **Verified**。
3. `LICENSE` 与 `NOTICE` 仍署名 **ldcstc-gif**。
4. 下载的压缩包：`SHA256SUMS` 校验通过，且 `SHA256SUMS.asc` 能用 ldcstc-gif 的
   公钥验证。

---

*Keep your private signing key secret. The whole scheme rests on the fact that
only you can produce a valid signature for your identity.*

*务必保管好你的签名私钥——整套机制的根基就是"只有你能为你的身份生成有效签名"。*
