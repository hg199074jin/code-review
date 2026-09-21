# code-review（代码审查）

<div align="center">

![Agent Skills](https://img.shields.io/badge/Agent_Skills-Standard-2196F3?style=flat-square)
![运行时](https://img.shields.io/badge/%E8%BF%90%E8%A1%8C%E6%97%B6-%E4%B8%AD%E7%AB%8B%E9%80%9A%E7%94%A8-9C27B0?style=flat-square)
![Darwin 优化](https://img.shields.io/badge/Darwin-Optimized-FF6B35?style=flat-square)
![九维评分](https://img.shields.io/badge/9%E7%BB%B4%E8%AF%84%E5%88%86-86.8%2F100-4CAF50?style=flat-square&labelColor=2E7D32)
![分数提升](https://img.shields.io/badge/%E5%88%86%E6%95%B0-%2B11.9-8E24AA?style=flat-square)
![检查清单](https://img.shields.io/badge/%E6%A3%80%E6%9F%A5%E6%B8%85%E5%8D%95-A--J_10%E9%A1%B9-00897B?style=flat-square)
![已实测](https://img.shields.io/badge/%E5%AE%9E%E6%B5%8B-3_Prompts-43A047?style=flat-square)
![只读](https://img.shields.io/badge/%E6%A8%A1%E5%BC%8F-%E5%8F%AA%E8%AF%BB-00897B?style=flat-square)
![许可](https://img.shields.io/badge/License-MIT-FBC02D?style=flat-square)

</div>

> **一句话**：一个自包含的代码审查技能，自己决定**何时审**、**审什么**、**怎么审**——以 A–J 十项清单为驱动，P0–P3 分级，结尾只给一行裁决。

**English**: [README.md](README.md)

---

## 为什么会有这个技能

当代码由 AI 写、审查也由 AI 做时，缺位的是人类审查者。能补上这个位置的不是"认真看一遍 diff"，而是一道**每次都以同样方式运行的、逐条机械展开的质量闸门**。

这个技能就是那道闸门。它不是 linter，也不是风格指南。它按顺序回答十个问题，每一次都不例外，并且不允许任何一项被静默跳过：

| # | 项目 | 它回答的问题 |
|---|---|---|
| **A** | 规格符合性 | 是真的实现了需求，还是只是看起来实现了？ |
| **B** | 范围控制 | 有没有夹带没人要的东西？ |
| **C** | 正确性 | 逻辑对不对？ |
| **D** | 边界情况 | 空值、异常、并发、超时、失败恢复——考虑了吗？ |
| **E** | 回归 | 原来能用的东西坏了吗？ |
| **F** | 安全性 | 路径、命令、密钥、权限——有问题吗？ |
| **G** | 测试质量 | 测试是真的证明了功能，还是只是跑绿了？ |
| **H** | 复杂度 | 是不是过度设计，而且有实际代价？ |
| **I** | 可维护性 | 未来的 Agent 能读懂并安全接手吗？ |
| **J** | 最终分级 | Critical / Major / Minor / Suggestion，外加一行裁决 |

最容易抓住 AI 写代码问题的是 **A** 和 **G**。AI 的典型失败不是某一行写错，而是**函数看起来实现了，但规格要求的分支根本不在**，再配一个只测正常路径的测试——于是绿灯给从未完成的工作盖了章。G 项的判据正是这个：*测试断言的是"规格要求的行为"，还是"代码眼下的行为"？后者就是迎合实现。*

## 安装

整个技能就是一个 `SKILL.md`，丢进任何兼容 Agent Skills 的运行时即可。

```bash
# Claude Code / Codex / Cursor / OpenClaw / Hermes / Gemini CLI —— 克隆进技能目录
git clone https://github.com/hg199074jin/code-review.git
cp -r code-review ~/.claude/skills/code-review        # 或其他运行时对应的目录
```

手动安装：下载本仓库，把目录复制成 `<skills-dir>/code-review/SKILL.md` 存在即可。重启会话，让技能描述被加载。

## 使用

直接说人话，不用记技能名，也不用记参数：

| 你说 | 审什么 |
|---|---|
| `审查这次修改` / `review my changes` | 工作区未提交的改动 |
| `审查 xxx 分支` / `review the xxx branch` | 该分支相对它的合并目标 |
| `审查这个 commit` / `review this commit` | 单个 commit 相对其父提交 |
| `扫描这个仓库` / `audit this repo` | 整个仓库，不是 diff |

审查全程**只读**：不改文件、不提交、不推送、不发评论。默认派一个全新的审查子代理执行，让判断独立于写代码的那个会话。

## 工作方式

1. **解析目标**——工作区、分支或 commit。有歧义时默认取工作区并用一行说明，绝不静默地审一个用户没要求的范围。分支审查的合并基点按固定阶梯解析（用户点名 → PR base → 仓库默认分支 → `main` → `master` → 报告并停止），**绝不把分支自身的 tracking upstream 当基点**——`origin/feature-x` 是同一分支的远端副本，对它 diff 几乎审不到东西。
2. **解析确定性范围**——只要 `ocr` 可用，任何 diff 审查都先跑 `ocr delegate preview --format json`（不花 LLM 调用）；规模只决定分批方式，不决定要不要解析范围。全仓库审计用 `ocr scan --preview --format json`——本地枚举、不调 LLM。高风险改动（安全、数据丢失、冻结契约）过两遍。
3. **走 A–J**——十项全查，按顺序。某一项只有说明理由后才能标 `➖ 不适用`。缺陷判据分模式：diff 审查只报本次改动引入、引用范围与 diff 重叠的问题；全仓库审计的目的恰恰是挖存量问题，按 file:line 引用。
4. **出报告**——一行"检查覆盖"说明每项查了没查；findings 按严重度排成 `[P1] 标题 — path/to/file.ext:line`；结尾恰好一行裁决，**机械计算**：有 P0 → `FAILED`；否则有 P1 → `NEEDS_REVISION`；否则 `PASS`。P2/P3 不影响裁决——该拦的 P2 就该定级为 P1。

那行"检查覆盖"就是防橡皮图章的装置：它逼着审查逐项摊开到底查了什么。`⚠️` 表示"查了但受限，原因如下"；`➖` 表示"不适用，原因如下"。

### 失败模式写进了规格

只描述 happy path 的技能，一旦现实不配合就会崩。这个技能把兜底路径显式编码了：

| 触发条件 | 一线修复 | 仍失败 |
|---|---|---|
| `ocr` 缺失或报错 | `which ocr` 确认，否则退回 `git diff` | 继续原生审查，并说明文件筛选不是确定性的 |
| `ocr` 拒绝 `--format json`（旧版 CLI） | 去掉 `--format` 重试，解析文本输出 | 继续；报告注明用了哪种输出模式 |
| 不是 git 仓库 / 还没有 commit | 改为直接读工作区文件 | 审这些文件，并说明无历史可比 |
| 分支 / SHA 解析不到 | 试配置的上游，再 `git merge-base` | 报告"目标不可用"并停下——**绝不静默换范围** |
| 测试跑不起来 | 探测项目原生 runner，运行最小相关子集 | 仅在确认安全（无 fixture/参数化/异步/导入副作用）时才直接调用测试函数；否则 E、G 标 `⚠️ 仅静态审阅`——**没跑过就绝不写"测试通过"** |
| diff 太大一次审不完 | 按目录或模块分批 | 报告哪些部分审了、哪些没审 |
| 分不清某处偏离是有意还是失误 | 报为"待确认偏离" | 不替作者判定意图 |
| 涉密仓库 + 要求外传型模式 | 🛑 拒绝，改本地审查 | 上报用户，不擅自继续 |

## 可选依赖

技能可独立运行。它可选地用 [`ocr`](https://github.com/alibaba/open-code-review)（OpenCodeReview）的 **delegation 模式**做确定性文件筛选和按路径的规则解析——该模式本地运行、无需 API key。

```bash
npm install -g @alibaba-group/open-code-review
ocr delegate preview          # 工作区改动的可审查文件清单
ocr delegate rule <files>     # 按路径解析出的规则
```

没有 `ocr` 就退回 `git diff`，并在报告里说明。`ocr` 有两个模式被**刻意不用**：`ocr review` 和完整 `ocr scan` 需要配置 LLM 端点、会把内容传出本机——未经用户明确授权，技能拒绝执行。`ocr scan --preview` **在用**：它在本地枚举文件、不调 LLM，正是全仓库审计需要的确定性能力。

## 目录结构

```
code-review/
├── SKILL.md                  # 技能本体——完整标准，自包含
├── evals/                    # 可复现评估
│   ├── run.sh                # 一条命令：重建 fixtures + 确定性检查
│   ├── fixtures/             # baseline / changed 源文件 + SPEC.md
│   ├── test-prompts.json     # 7 个场景（3 行为 + 4 回归）
│   ├── expected-findings.json# 每场景的必报 / 禁报清单
│   └── judge-rubric.md       # 9 维 rubric + paired 多数决协议
├── docs/
│   └── darwin-result-card.png
├── README.md
├── README.zh-CN.md
└── LICENSE
```

## V1.1 变更记录（外部评审轮，2026-09-21）

外部评审的九条发现全部核实后采纳：

- **[P1] base 解析**：不再接受分支的 tracking upstream 作为合并目标——改为固定阶梯（用户点名 → PR base → 默认分支 → `main` → `master` → 报告）。upstream 陷阱已做回归测试：`evals/run.sh` 实测 `git diff @{u}..HEAD` 为空、`main..HEAD` 才有真实增量。
- **[P1] 全仓库与 diff 判据解耦**：§3.4 分两套模式——diff 审查只报改动引入且与 diff 重叠的问题；全仓库审计专门挖存量问题，按 file:line 引用。
- **[P2] `ocr scan --preview`**（本机 v1.12.7 实测验证）：全仓库审计获得本地确定性文件枚举，不再整体放弃 `ocr`。
- **[P2] JSON 优先**：所有 `delegate` 调用优先 `--format json`，旧版 CLI 有文档化的文本回退。
- **[P2] 路由简化**：`delegate preview` 对任何规模的 diff 审查都跑；规模只决定分批。
- **[P2] 测试兜底收紧**：先探测原生 runner；禁止盲目 import 测试模块，除非确认无副作用。
- **[P2] 裁决机械化**：删除 `clustered P2`——有 P0 → FAILED，否则有 P1 → NEEDS_REVISION，否则 PASS。
- **[P3] 术语统一**：遗留的 "Critical/Important" 措辞统一为 P0/P1；"read-only" 重定义为*源码树只读*，并明确测试执行的副作用规则。
- **[P3] runtime 中立**：审查子代理的指令不再点名某运行时专属的 agent 类型。
- **可复现性**：新增 `evals/`——fixtures、期望发现、judge rubric、一条命令的确定性检查。

## 进化记录

本技能按 [darwin-skill](https://github.com/alchaincyf/darwin-skill) 协议进化：先设计测试 prompt 与基线评估，再逐轮改动，每轮由**三个独立 judge 对改前/改后做 paired 比较**决定去留（绝对分数是噪音，paired 多数决才是棘轮）。

| 轮次 | 维度 | 改动 | 裁决 |
|---|---|---|---|
| 基线 | — | — | **74.9** / 100 |
| 1 | 失败模式编码 | 新增 7 行三段式兜底表 | 3-0 better（clear） |
| 2 | 检查点设计 | 4 处 🔴/🛑 显性标记 | 3-0 better |
| 3 | 整体架构 | 三处重复的禁令合并为一处权威表述 | 3-0 better |
| 终态 | — | — | **86.8** / 100 |

三轮，三轮保留，零回滚。真正有说服力的是收尾回归测试：审查者显式调用了"排除文件必读"检查点和"无 pytest 时直接调用测试函数"的兜底——前两轮加的内容**被真正执行了**，不只是写在纸上。

评分卡见 `docs/darwin-result-card.png`。

## 许可

[MIT](LICENSE)
