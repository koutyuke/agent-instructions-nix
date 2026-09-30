<div align="center">

  <h1>agent-instructions-nix</h1>

  <p><i>Compose and manage shared instructions for AI coding agents with Nix and Home Manager.</i></p>
  <p>
    <img src="https://img.shields.io/badge/Nix-flake-5277C3?logo=nixos&amp;logoColor=white" alt="Nix flake">
    <img src="https://img.shields.io/badge/Home_Manager-supported-5277C3" alt="Home Manager supported">
    <img src="https://img.shields.io/badge/License-MIT-64748B" alt="MIT License">
  </p>

  <p>
    <a href="./README.md">🇬🇧 English</a> | <b>🇯🇵 日本語</b>
  </p>

  <p><sub>✦ ✦ ✦</sub></p>
</div>

## 概要

**agent-instructions-nix** は、複数の Markdown ファイルを組み合わせて AI コーディングエージェント向けのグローバル指示ファイル（`CLAUDE.md` や `AGENTS.md` など）を生成する Nix ライブラリです。共通の指示を一元管理しながら、エージェント固有の指示も柔軟に追加・構成できます。

```text
CONTEXT7.md ────┐
                ↓
COMMON.md ────→ + ────┬────→ ~/.claude/CLAUDE.md (COMMON.md + CONTEXT7.md)
                      ↓
CODEX.md ───────────→ + ───→ ~/.codex/AGENTS.md  (COMMON.md + CONTEXT7.md + CODEX.md)
```

- **指示の共通化と個別カスタマイズ**: 共通の Markdown ファイルを指定順に結合し、エージェント固有のファイルを追加・カスタマイズできます。
- **主要エージェントへの組み込み対応**: 35 種類のエージェント向けに既定の配置パスを定義済みです。任意のパスも指定可能で、必要なエージェントの設定ファイルだけを生成できます。
- **Markdown の自動整形**: front matter や冗長な空行の除去、ファイルごとの見出しレベル（H1〜）の自動調整に対応しています。
- **Home Manager 連携**: 各エージェントの指示ファイルへのシンボリックリンクを Home Manager で自動配置できます。Home Manager を使わず、ファイル生成（Nix 単体）のみで利用することも可能です。

## 使い方

`flake.nix` の `inputs` に本ライブラリを追加します。

```nix
# flake.nix
inputs.agent-instructions = {
  url = "github:koutyuke/agent-instructions-nix";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

続いて Home Manager の設定でモジュールを読み込み、共通の Markdown ファイルと対象のエージェントを指定します。
以下の例では Claude Code と Codex の双方に共通指示を配置し、Codex にのみ `CODEX.md` を追加しています。

```nix
# Home Manager の設定
{ inputs, ... }:
{
  imports = [
    inputs.agent-instructions.homeManagerModules.default
  ];

  programs.agent-instructions = {
    enable = true;
    sources = [
      ./COMMON.md
      {
        path = ./CONTEXT7.md;
        headingStrategy = "demote";
      }
    ];
    targets = {
      claude.enable = true;
      codex = {
        enable = true;
        sources = [
          {
            path = ./CODEX.md;
            headingStrategy = "drop";
          }
        ];
      };
    };
    insertH1.enable = true;
  };
}
```

上記の設定では、`sources` に指定した順序で `COMMON.md` と `CONTEXT7.md` が結合され、Codex にはその末尾に `CODEX.md` が追加されます。

Home Manager の設定を反映すると、設定をもとにファイルを統合し、`~/.claude/CLAUDE.md` および `~/.codex/AGENTS.md` にシンボリックリンクが作成されます。

この設定と同じ構成の例を [example/](./example) に置いています。元の Markdown ファイルと、生成されるファイル（[example/result/](./example/result)）を確認できます。
Home Manager を使わずにビルドを試すには、リポジトリのルートで次のコマンドを実行します。

```bash
nix build --impure --file ./example
diff -r result example/result
```

> `--impure` は、ローカルの flake の読み込みと `builtins.currentSystem` の評価に必要です。

## Markdown の結合と整形

各 Markdown ファイルは以下の前処理を行ったうえで、空行を 1 行挟んで結合されます。

1. **改行・BOM の正規化**: 改行コードを LF に統一し、ファイル先頭の BOM を除去
2. **front matter の除去**: 1 行目の `---` から次の `---` までのブロックを除去（結合後のドキュメント途中に残ると見出しや区切り線として誤認されるため）
3. **見出しレベルの変換**: 指定された `headingStrategy` に従って見出しを調整
4. **空行の整理**: 前後の不要な空行を除去し、コードフェンス外にある連続した空行を 1 行に集約

### `headingStrategy`

`headingStrategy` オプションで見出しの変換方法を指定できます。

| `headingStrategy` | 動作                                                                   | 主なユースケース                                                            |
| ----------------- | ---------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| `"none"`          | 見出しを変換せず、そのまま維持する                                     | もともと `##` 以下で構造化されているファイル                                |
| `"demote"`        | すべての見出しレベルを 1 段下げる（H1 を含まないファイルでも適用）     | `# Context7` のようなトピック単位の H1 をセクション（H2）として残したい場合 |
| `"drop"`          | ファイル先頭の H1 行のみを除去する（先頭が H1 でない場合は何もしない） | `# 共通指示` のような単体ドキュメント用のタイトル H1 が不要な場合           |

> [!NOTE]
> 変換の対象となるのは、コードフェンスの外にある ATX 形式（`#` で始まる行）の見出しのみです。Setext 形式（行の下に `===` や `---` を置く記法）には対応していません。

<table>
  <tr>
    <th>入力</th>
    <th><code>"none"</code></th>
    <th><code>"demote"</code></th>
    <th><code>"drop"</code></th>
  </tr>

<tr valign="top">
<td>

```md
# Context7

Fetch the latest docs.

## Steps

1. Resolve the ID
```

</td>
<td>

```md
# Context7

Fetch the latest docs.

## Steps

1. Resolve the ID
```

</td>
<td>

```md
## Context7

Fetch the latest docs.

### Steps

1. Resolve the ID
```

</td>
<td>

```md
Fetch the latest docs.

## Steps

1. Resolve the ID
```

</td>
</tr>
</table>

### `insertH1`

生成ファイルの先頭に H1 見出しを自動挿入する場合は、`insertH1.enable = true` を指定します。

`insertH1.text` を省略した場合は、配置先（`dest`）のファイル名（`CLAUDE.md` や `.goosehints` など）が見出し文字列として自動的に使われます。

ターゲットごとに `targets.<name>.insertH1` を定義すると、共通設定を上書きできます。H1 の挿入を無効（デフォルト）にしている場合は、先頭の Markdown ファイルに含まれる見出しがそのままドキュメントのトップレベル見出しになります。

```nix
{
  insertH1.enable = true;
  targets = {

    # 出力結果: `# CLAUDE.md`
    claude.enable = true;

    # 出力結果: `# Codex Instructions`
    codex = {
      enable = true;
      insertH1 = {
        enable = true;
        text = "Codex Instructions";
      };
    };
  };
}
```

## オプション

| オプション                      | 型                         | 既定値  | 説明                                                                                    |
| ------------------------------- | -------------------------- | ------- | --------------------------------------------------------------------------------------- |
| `enable`                        | boolean                    | `false` | モジュールを有効化する                                                                  |
| `sources`                       | list of (path or `Source`) | `[ ]`   | 全ターゲット共通の Markdown ファイル一覧。指定順に結合されます                          |
| `insertH1`                      | `H1`                       | `{ }`   | 各ターゲットファイルの先頭に挿入する H1 見出しの設定                                    |
| `targets.<name>.enable`         | boolean                    | `false` | このターゲットの指示ファイルを生成・配置する                                            |
| `targets.<name>.dest`           | null or string             | `null`  | `$HOME` からの相対パス。`null` の場合は既定の配置先を使用（カスタムターゲットでは必須） |
| `targets.<name>.sources`        | list of (path or `Source`) | `[ ]`   | 共通 `sources` の末尾に追加で結合する Markdown ファイル                                 |
| `targets.<name>.inheritSources` | boolean                    | `true`  | `false` にすると共通の `sources` を継承しない                                           |
| `targets.<name>.insertH1`       | null or `H1`               | `null`  | このターゲット専用の `insertH1` 設定。`null` の場合は共通の `insertH1` 設定を使用       |

### `Source`

| オプション        | 型                                    | 既定値       | 説明                                                                       |
| ----------------- | ------------------------------------- | ------------ | -------------------------------------------------------------------------- |
| `path`            | path                                  | なし（必須） | 読み込む Markdown ファイルのパス                                           |
| `headingStrategy` | one of `"none"`, `"demote"`, `"drop"` | `"none"`     | 見出しの変換ルール。[Markdown の結合と整形](#markdown-の結合と整形) を参照 |

### `H1`

| オプション | 型             | 既定値  | 説明                                                      |
| ---------- | -------------- | ------- | --------------------------------------------------------- |
| `enable`   | boolean        | `false` | 先頭への H1 見出し挿入を有効化する                        |
| `text`     | null or string | `null`  | 見出しの文字列。`null` の場合は `dest` のファイル名を使用 |

## ターゲットと既定の配置先

| 名前           | `dest`                             | 競合する Home Manager のオプション    | 出典                                                                                                                                                                                                                                                      |
| -------------- | ---------------------------------- | ------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `agents`       | `.agents/AGENTS.md`                | -                                     | [Cline](https://github.com/cline/cline/blob/main/sdk/packages/shared/src/storage/paths.ts), [Droid](https://docs.factory.com/cli/configuration/agents-md), [Kimi Code](https://github.com/MoonshotAI/kimi-code/blob/main/docs/en/customization/agents.md) |
| `agentty`      | `.agentty/AGENTS.md`               | -                                     | [agentty](https://github.com/1ay1/agentty)                                                                                                                                                                                                                |
| `amp`          | `.config/amp/AGENTS.md`            | -                                     | [Amp](https://ampcode.com/docs/customize/agents-md)                                                                                                                                                                                                       |
| `antigravity`  | `.gemini/AGENTS.md`                | -                                     | [Antigravity](https://antigravity.google/docs/rules/)                                                                                                                                                                                                     |
| `claude`       | `.claude/CLAUDE.md`                | `programs.claude-code.context`        | [Claude Code](https://code.claude.com/docs/en/memory)                                                                                                                                                                                                     |
| `cline`        | `.cline/rules/AGENTS.md`           | -                                     | [Cline](https://github.com/cline/cline/blob/main/sdk/packages/shared/src/storage/paths.ts)                                                                                                                                                                |
| `codex`        | `.codex/AGENTS.md`                 | `programs.codex.context`              | [Codex](https://developers.openai.com/codex/guides/agents-md)                                                                                                                                                                                             |
| `command-code` | `.commandcode/AGENTS.md`           | -                                     | [Command Code](https://commandcode.ai/docs/memory)                                                                                                                                                                                                        |
| `copilot`      | `.copilot/copilot-instructions.md` | `programs.github-copilot-cli.context` | [GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/add-custom-instructions)                                                                                                                                                      |
| `crush`        | `.config/crush/CRUSH.md`           | -                                     | [Crush](https://github.com/charmbracelet/crush/blob/main/README.md)                                                                                                                                                                                       |
| `droid`        | `.factory/AGENTS.md`               | -                                     | [Droid](https://docs.factory.com/cli/configuration/agents-md)                                                                                                                                                                                             |
| `dsh`          | `.dsh/AGENTS.md`                   | -                                     | [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/config-catalog.md)                                                                                                                                                      |
| `eca`          | `.config/eca/AGENTS.md`            | -                                     | [ECA](https://github.com/editor-code-assistant/eca/blob/main/docs/config/rules.md)                                                                                                                                                                        |
| `every-code`   | `.code/AGENTS.md`                  | -                                     | [Every Code](https://github.com/just-every/code/blob/main/docs/getting-started.md)                                                                                                                                                                        |
| `forgecode`    | `.forge/AGENTS.md`                 | -                                     | [ForgeCode](https://github.com/tailcallhq/forgecode/blob/main/crates/forge_services/src/instructions.rs)                                                                                                                                                  |
| `fx`           | `.fx/AGENTS.md`                    | -                                     | [fx](https://github.com/vercel-labs/fx/blob/main/src/builtins/context.zig)                                                                                                                                                                                |
| `gemini`       | `.gemini/GEMINI.md`                | -                                     | [Gemini CLI](https://geminicli.com/docs/cli/gemini-md/)                                                                                                                                                                                                   |
| `goose`        | `.config/goose/.goosehints`        | -                                     | [goose](https://goose-docs.ai/docs/guides/context-engineering/using-goosehints/)                                                                                                                                                                          |
| `hax`          | `.config/hax/AGENTS.md`            | -                                     | [hax](https://github.com/OleksandrChekhovskyi/hax/blob/master/src/agent_env.c)                                                                                                                                                                            |
| `junie`        | `.junie/AGENTS.md`                 | -                                     | [Junie](https://junie.jetbrains.com/docs/guidelines-and-memory.html)                                                                                                                                                                                      |
| `kilocode`     | `.config/kilo/AGENTS.md`           | -                                     | [Kilo Code](https://github.com/Kilo-Org/kilocode/blob/main/packages/opencode/src/session/instruction.ts)                                                                                                                                                  |
| `kimi`         | `.kimi-code/AGENTS.md`             | -                                     | [Kimi Code](https://github.com/MoonshotAI/kimi-code/blob/main/docs/en/customization/agents.md)                                                                                                                                                            |
| `mimo`         | `.config/mimocode/AGENTS.md`       | -                                     | [MiMo Code](https://github.com/XiaomiMiMo/MiMo-Code/blob/main/packages/cli/src/session/instruction.ts)                                                                                                                                                    |
| `minimax`      | `.minimax/AGENTS.md`               | -                                     | [MiniMax Code](https://github.com/MiniMax-AI/minimax-code/blob/main/packages/local-runtime-v2/src/service/turn-system/persistence/global-instructions.ts)                                                                                                 |
| `mistral-vibe` | `.vibe/AGENTS.md`                  | -                                     | [Mistral Vibe](https://github.com/mistralai/mistral-vibe/blob/main/vibe/core/config/harness_files/_harness_manager.py)                                                                                                                                    |
| `omp`          | `.omp/agent/AGENTS.md`             | -                                     | [oh-my-pi](https://github.com/can1357/oh-my-pi/blob/main/packages/coding-agent/src/discovery/builtin.ts)                                                                                                                                                  |
| `opencode`     | `.config/opencode/AGENTS.md`       | `programs.opencode.context`           | [opencode](https://opencode.ai/docs/rules/)                                                                                                                                                                                                               |
| `pi`           | `.pi/agent/AGENTS.md`              | `programs.pi-coding-agent.context`    | [pi](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/configuration.md)                                                                                                                                                          |
| `prime-agent`  | `.prime/agent/AGENTS.md`           | -                                     | [Prime Agent](https://github.com/PrimeIntellect-ai/prime-agent/blob/main/crates/pa-core/src/resources/mod.rs)                                                                                                                                             |
| `qoder`        | `.qoder/AGENTS.md`                 | -                                     | [Qoder CLI](https://docs.qoder.com/cli/memory)                                                                                                                                                                                                            |
| `qwen`         | `.qwen/QWEN.md`                    | -                                     | [Qwen Code](https://qwenlm.github.io/qwen-code-docs/en/users/features/memory/)                                                                                                                                                                            |
| `reasonix`     | `.reasonix/AGENTS.md`              | -                                     | [Reasonix](https://github.com/esengine/DeepSeek-Reasonix/blob/main/internal/state/instruction/resolver.go)                                                                                                                                                |
| `vix`          | `.vix/AGENTS.md`                   | -                                     | [vix](https://github.com/get-vix/vix/blob/main/internal/config/paths.go)                                                                                                                                                                                  |
| `zaly`         | `.config/zaly/AGENTS.md`           | -                                     | [zaly](https://github.com/folke/zaly/blob/main/packages/agent/src/prompt/markdown.ts)                                                                                                                                                                     |
| `zcode`        | `.zcode/AGENTS.md`                 | -                                     | [Z Code](https://zcode.z.ai/en/docs/agents)                                                                                                                                                                                                               |

> [!NOTE]
> `dest` は Nix の評価時に静的に決定されます。`CLAUDE_CONFIG_DIR`、`CODEX_HOME`、`XDG_CONFIG_HOME` などの環境変数で設定ディレクトリを変更している場合は自動反映されないため、`dest` を明示的に指定してください。

### カスタムターゲット

一覧にないツールでも、任意のターゲット名と `$HOME` からの相対パス（`dest`）を指定して自由に追加できます。

```nix
programs.agent-instructions.targets.my-agent = {
  enable = true;
  dest = ".my-agent/RULES.md";
  sources = [ ./MY_AGENT.md ];
};
# → ~/.my-agent/RULES.md
```

## コア API を直接利用する

Home Manager を使わずに利用する場合は、ライブラリの関数で直接バンドル（derivation）をビルドし、独自の方法で `$HOME` 配下に配置できます。受け取る引数は Home Manager のモジュールオプションと共通です。

```nix
bundle = inputs.agent-instructions.lib.mkBundle {
  inherit pkgs;
  sources = [ ./COMMON.md ];
  targets.claude.enable = true;
};
# → $out/claude.md
```

各ターゲット向けに結合された Markdown は、1 つのバンドル（ディレクトリ）直下に `<name>.md` として生成されます（例: `/nix/store/<hash>-agent-instructions/` 配下に `codex.md` や `claude.md` が出力されます）。Home Manager モジュールは、各ターゲットの `dest` からバンドル内の対応ファイルへシンボリックリンクを張る仕組みになっています。そのため、`dest` を変更してもバンドル内のファイル名は変わりません。

### API リファレンス

`mkBundle { pkgs, sources?, insertH1?, targets?, name? }`

- 各ターゲットの指示ファイルをまとめたバンドル（derivation）を生成します
- 設定値の検証を行い、`checkTargets` でエラーがあれば評価を中断（throw）し、`targetWarnings` の警告があれば評価時警告（warning）として出力します

`resolveTargets { sources?, insertH1?, targets? }`

- 入力設定を正規化し、有効化されたターゲットを `{ <name> = { dest; sources; h1; }; }` の形式に解決します
- `h1` には挿入対象の見出し文字列、または `null` が格納されます

`checkTargets resolved`

- 解決済みターゲットの妥当性を検証し、エラーメッセージのリストを返します（問題がなければ空リスト `[ ]`）

`targetWarnings resolved`

- 解決済みターゲットの警告メッセージのリストを返します（警告がなければ空リスト `[ ]`）

`compose { sources, h1? }`

- 指定された `sources` を前処理・結合した Markdown 文字列を返します
- `resolveTargets` で解決したターゲットの attribute set をそのまま渡すことができます

`defaultTargets`

- 組み込みターゲットの定義と既定の `dest` パス一覧

## 開発とテスト

```bash
nix flake check        # コア機能のテスト（test/core.nix、nixpkgs のみで実行可能）
nix flake check ./dev  # Home Manager 連携モジュールのテスト（test/home-manager.nix）
nix fmt                # nixfmt によるコードフォーマット
```

## ライセンス

Copyright 2026 koutyuke

本リポジトリは [MIT License](./LICENSE) のもとで公開されています。
