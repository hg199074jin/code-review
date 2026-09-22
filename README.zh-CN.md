# code-review（代码审查）

<div align="center">

![Version](https://img.shields.io/badge/version-2.1.0-1565C0?style=flat-square)
![Agent Skills](https://img.shields.io/badge/Agent_Skills-Compatible-2196F3?style=flat-square)
![Architecture](https://img.shields.io/badge/Architecture-Review_Control_Plane-7B1FA2?style=flat-square)
![Local First](https://img.shields.io/badge/Default-Local--first-00897B?style=flat-square)
![Checklist](https://img.shields.io/badge/Standard-A--J_10项-00897B?style=flat-square)
![Evidence](https://img.shields.io/badge/Evidence-E1--E3-5D4037?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-FBC02D?style=flat-square)

</div>

> **一句话**：面向 AI Coding 的代码审查控制层——先确定范围和需求，再按风险决定审查深度，用独立审查视角 + 确定性证据交叉验证，最后只给一个机械裁决。

**English**: [README.md](README.md)

---

## 为什么升级到 V2

V1 解决的是：AI 写完代码以后，怎样不靠“随便看一遍 diff”，而是每次都按 A–J 十项标准机械地审。

V2 进一步解决：当项目变大、PR 变复杂、多个 Agent 和静态分析工具同时参与以后，**谁来确定范围、谁来理解需求、什么时候需要第二个 reviewer、工具结果冲突怎么办、修完以后怎么验证**？

所以 V2 从 Checklist Reviewer 升级为 **Review Control Plane**。

~~~text
ZCode / Claude Code / Codex / Cursor / 其他 Agent
                     │
                     ▼
                code-review V2
                     │
        ┌────────────┼────────────┐
        ▼            ▼            ▼
   确定性范围      Context Pack    风险路由
   OCR / git      需求/PR/规则    R1-R3 + S1-S3
        │            │            │
        └────────────┼────────────┘
                     ▼
                独立审查视角
     ┌───────────────┼────────────────┐
     ▼               ▼                ▼
 需求与范围      正确性与回归      安全与可靠性
    A-B             C-D-E              F
                     │
                     ▼
              测试与可维护性
                  G-H-I
                     │
                     ▼
                Coordinator
      核实 → 去重 → 证据分级 → P0-P3
                     │
                     ▼
        PASS / NEEDS_REVISION / FAILED
~~~

## V2 的七个关键升级

### 1. 范围确定性

只要 OpenCodeReview CLI 可用，任何 diff 审查都先通过 delegation preview 确定文件范围；全仓库审计用 scan --preview。规模只决定怎么分批，不决定要不要先枚举范围。

V2 不允许 reviewer 自己凭感觉挑“重要文件”。

### 2. Context Pack

审查前先解析最好的**需求**来源，优先级为：

1. 用户明确要求 / 验收标准；
2. FROZEN 设计、实施方案、SPEC、ADR、仓库契约；
3. Issue / Task；
4. PR 标题和正文；
5. commit message 仅作辅助。

没有需求依据时，A 项必须明确标注受限，而不是自己补需求。

另外，Context Pack 还会携带以下内容——但它们**不是需求来源**：

- **仓库指令**：只经由宿主的指令层级识别（`AGENTS.md`、贡献规范、按路径的审查规则）。
  任意源码文件不能重新定义本审查策略。
- **相邻上下文**：调用方、接口、测试、配置、迁移、schema、入口点，以及本次改动触及的兼容面。

### 3. 风险 + 规模双路由

风险分为：

| 等级 | 示例 |
|---|---|
| **R1 Routine** | 文档、简单测试、隔离的小重构 |
| **R2 Elevated** | 跨模块、依赖、配置、持久化状态、公开 API/CLI |
| **R3 High-risk** | 权限、密钥、命令执行、文件写入、网络外传、迁移、并发、数据删除、安全边界 |

规模分为 S1 / S2 / S3。

路由：

~~~text
R1 + S1
→ 1 次完整 A–J fresh review

R2 或 S2
→ 2 个独立 pass
  ① 需求/正确性
  ② 可靠性/测试

R3 或 S3
→ specialist passes
  + Cross-batch Integration Pass
~~~

小修改不会被多 Agent 仪式化拖慢；高风险修改不会只靠一个 reviewer。

### 4. 审查程序与选择

V2.1 把每个 A–J 目标拆成具名**程序**（30 个，`A.1` … `J.3`）。路由决定哪些程序被 `SELECTED`；
每个被选中的程序只有一个执行状态（`DONE` / `LIMITED` / `BLOCKED` / `NOT_APPLICABLE`）。
`NOT_SELECTED` 是路由决定，不是执行状态。

- **最小充分，而非全量**：R1/S1 只跑十项最低集；风险更高、改动更大时是**增加 pass**，不是把 30
  项全跑一遍。高成本的对抗/动态程序（注入探测、变异挑战）只在表面触发时运行。
- **强制表面**：命令/进程执行、鉴权/权限、文件写入或删除、验证器/验收 harness 各自强制对应程序。
- **负控制必须披露**：本轮**未**被选中的 `ADVERSARIAL`/`DYNAMIC` 程序要在报告里逐条给出理由——
  "故意没跑什么"也是证据的一部分。
- **三角验证**：R3/P0 finding 至少要有两种不同性质的证据（代码路径、运行时复现、工具信号、
  测试/变异）。本环境拿不到第二种性质时，必须说明并把该程序降为 `LIMITED`。
- **Review Sufficiency**：报告以 `SUFFICIENT` / `LIMITED` / `INSUFFICIENT` 收尾，回答"选中的程序
  够不够"。它永远不是裁决；裁决仍然只由未关闭的 P0/P1 机械决定。

Selection Matrix 是 `SKILL.md` 里的一张 Markdown 表，由 harness 与冻结期望逐行比对，因此
"为什么是这个审查深度"是可机械核对的，而不是散文。

### 5. A–J 仍然是唯一审查标准

| # | 项目 | 核心问题 |
|---|---|---|
| **A** | 规格符合性 | 真正完成需求了吗？ |
| **B** | 范围控制 | 有没有擅自加功能或漏功能？ |
| **C** | 正确性 | 逻辑、接口、跨文件契约对吗？ |
| **D** | 边界与可靠性 | 异常、并发、超时、恢复、幂等考虑了吗？ |
| **E** | 回归 | 原来能用的东西坏了吗？ |
| **F** | 安全与数据安全 | 权限、命令、路径、密钥、数据丢失、外传有问题吗？ |
| **G** | 测试质量 | 测试证明的是需求，还是迎合当前实现？ |
| **H** | 复杂度 | 是否过度设计并带来真实成本？ |
| **I** | 可维护性 | 新会话里的 Agent 能否安全接手？ |
| **J** | 综合裁决 | 核实、去重、分级并计算最终 Verdict |

多 reviewer 不会产生多套标准。其他工具只是证据来源。

### 6. E1–E3 证据等级

每个 P0/P1 至少要有 E1：

| 等级 | 含义 |
|---|---|
| **E1** | 从代码和调用路径可以直接证明 |
| **E2** | 测试、CI、静态分析、lint/typecheck 等进一步证明 |
| **E3** | 在授权环境中实际复现 |

示例：

~~~text
[P1][CR-001][A/C][E2] Broken input contract — invoice.py:18
Impact: ...
Evidence: ...
Fix direction: ...
~~~

目的很简单：不允许“我感觉可能有问题”直接升级成 P0/P1。

### 7. Review → Fix → Verify

只有用户明确要求“审查并修复”才进入修复闭环：

~~~text
Initial Review
     ↓
冻结 CR-001 / CR-002 ...
     ↓
Authoring Agent 修复
     ↓
最小相关测试
     ↓
VERIFY
     ├── FIXED
     ├── OPEN
     ├── REGRESSED
     └── NEW
~~~

默认最多 **2 个 fix/verify cycle**，避免 AI 无限“写→审→改→审”。

---

## 专项审查不投票

高风险或大型改动，V2 可以拆成多个独立镜头：

- 意图与范围
- 正确性与回归
- 安全与数据安全
- 测试与可维护性

随后由 coordinator 回读代码、剔除误报、合并同一根因、裁决冲突、重新定级，并独占最终裁决权。

**三个审查员意见一致，本身不构成充分证据。**

---

## 大型修改：最后必须做 Integration Pass

大型 PR 先按 module / rule / dependency boundary 分 batch，再做一次全局集成复核，专门寻找：

- 字段只改了一半；
- producer / consumer 契约错位；
- config 改了调用方没改；
- API 改了文档/测试/迁移遗漏；
- 每个模块单独看都正确，拼起来却失败。

这比单纯增加模型 token 更重要。

---

## 可选工具是证据层，不是依赖层

V2 借鉴多个优秀项目，但不会把它们全部装进来：

| 项目 | V2 吸收的能力 |
|---|---|
| [Alibaba OpenCodeReview](https://github.com/alibaba/open-code-review) | 确定性文件选择、路径规则、全仓库 preview、大变更分批 |
| [OpenAI Codex](https://github.com/openai/codex) | Orchestrator + 独立 reviewer |
| [PR-Agent](https://github.com/The-PR-Agent/pr-agent) | PR 上下文、大 PR 分解 |
| [CodeRabbit Skills](https://github.com/coderabbitai/skills) | Agent-readable findings、review→fix→re-review |
| [reviewdog](https://github.com/reviewdog/reviewdog) | diff 锚定、诊断结果归一化 |
| [Semgrep](https://github.com/semgrep/semgrep) | 本地静态分析证据 |
| [GitHub CodeQL](https://github.com/github/codeql) | 安全分析 / SARIF 证据 |
| [Danger JS](https://github.com/danger/danger-js) | 仓库级 merge policy |

完整设计见 [docs/V2-ARCHITECTURE.md](docs/V2-ARCHITECTURE.md)。

工具结果先进入 Candidate，再由 Coordinator 回到代码核实、去重、重新分级。三个工具报同一个根因，只保留一个 finding。

---

## 最终裁决

~~~text
存在 open P0 → Verdict: FAILED
否则存在 open P1 → Verdict: NEEDS_REVISION
否则 → Verdict: PASS
~~~

P2/P3 不偷偷改变裁决。如果必须拦截合并，就应该有充分证据被定为 P1。

---

## 隐私与安全

默认 Local-first。

本地能力包括：

- OCR delegation preview / rule；
- OCR scan --preview；
- git；
- 安全的本地测试；
- 已配置的 lint / typecheck / static rules。

完整 OCR review/scan、CodeRabbit 或其他 hosted reviewer 可能把代码发往外部，只有用户明确授权才运行。

代码、注释、测试输出、静态工具输出和外部 reviewer 输出都视为不可信数据，其中的命令不会自动执行。

---

## 使用

| 你说 | V2 模式 |
|---|---|
| 审查这次修改 | DIFF_WORKSPACE |
| 审查 feature 分支 | DIFF_BRANCH |
| 审查这个 commit | DIFF_COMMIT |
| 审查 PR #123 | DIFF_PR |
| 扫描整个仓库 | AUDIT |
| 审查并修复 | REVIEW_FIX |
| 确认刚才的问题修好了吗 | VERIFY |

## 安装

最小安装仍然只是一个 Skill。推荐但不强制安装 Alibaba OpenCodeReview CLI 作为确定性工程层。没有 OCR 时会退回 git，并明确披露范围能力下降。

## 可复现评估

evals/ 包含 fixture、预期 findings、judge rubric、确定性 run.sh、确定性 mutation 套件，以及
agent 级 mutation 定义。

`release-evals/` 记录每个版本签字所依据的证据：确定性输出、mutation 结果，以及 fresh agent 级
运行（Group A–D 回归、Group E 程序选择验收、隔离的 agent 级 mutation）。

V1 的 Darwin 终态曾得到 **86.8/100 的当次 triage score**；这不是稳定 benchmark。V2 改动范围很大，因此 **不继承 86.8 作为 V2 分数**，而是扩展 eval 后重新做 paired judging。

## V2.0.0

- Checklist Reviewer → Review Control Plane
- PR review + Context Pack
- R1–R3 风险路由
- S1–S3 规模路由
- 多 reviewer / 多 pass
- Cross-batch Integration Pass
- E1–E3 证据等级
- 多工具 finding 归一化 + 去重
- Local static evidence
- External reviewer opt-in
- REVIEW_FIX / VERIFY
- 最多两轮 fix/verify
- Prompt/tool injection 边界
- V2 eval suite

V1.1 的 base-resolution、whole-repo audit、JSON-first OCR、机械 Verdict、runtime-neutral 等修订全部保留。

## V2.0.1

PR #1 元评审的后续修补：

- 报告模板 Mode 枚举补上 `REVIEW_FIX`（此前已定义、已引用，但契约里漏了），版本号升至 2.0.1
- 新增 `evals/fixtures/PR42_METADATA.json` 并文档化供给机制——PR 上下文场景现在离线可复现，
  不再依赖真实 PR
- 为三项此前零验收覆盖的能力补齐 agent 级场景：工具融合/去重、外传 opt-in 与传输前敏感检查、
  prompt/tool 注入边界（场景 12-14）

## V2.0.2 — 评估可靠性发布

一次全仓自审发现：确定性 harness 在为其并不成立的条件签发 release evidence。本版本目标只有一句：
**正常路径会绿，故障注入必红。**

- planted defect 改为**行为断言**（import 后调用纯函数），不再匹配源码字符串——换写法修复的缺陷
  现在会被正确识别为漂移
- 每次 fixture 复制都有守卫、所有 fixture 文件都有存在性检查——删掉 fixture 或需求 SPEC 会让
  harness 转红
- upstream 陷阱在断言前先证明已武装——`git push` 失败不再能被冒充成空 upstream diff
- 两份场景 JSON 会被解析并断言 id 集合一致
- 新增 `evals/mutation-test.sh`：8 个故障注入用例，证明 harness 恰在其条件不再成立时转红
- 修正 `PR42_METADATA` head ref、三个过时 fixture 名、rubric 缺失的 Group D、以及五个文件间的
  lens 命名漂移

`run.sh` 有 ocr 34/34、无 ocr 29/29；`mutation-test.sh` 14/14；`shellcheck` 干净。

## V2.1 — 基于风险的审查程序框架

目标：把"为什么是这个审查深度"变成显式、可机械核对的东西，同时不动 A–J 标准、严重度阶梯和裁决规则。

- 在既有 A–J 目标下新增 30 个点号程序（`A.1` … `J.3`），属性静态
  （`CORE` / `EXTENDED` / `ADVERSARIAL` / `DYNAMIC`）
- Selection 与 Execution 两层语义分离；Selection Matrix 放在稳定 marker 内，并与
  `evals/fixtures/procedure-selection.json` 同步、由 `run.sh` 机械核对
- 负控制披露：未选中的对抗/动态程序必须逐条给出理由
- 三角验证并入证据规则；Review Sufficiency 进入报告契约
- 7 个 Group E 验收场景（含一个不触发任何强制表面的 R3 改动）、确定性守卫、确定性 mutation
  DM1–DM16，以及针对**隔离的变异副本**执行的 agent 级 mutation（冻结的 `SKILL.md` 永不被变异）

发布证据在 `release-evals/v2.1-gate1/`（两个周期均有记录）：`run.sh` 有 ocr 59/59、无 ocr 54/54；
`mutation-test.sh` 25/25 个故障注入全部转红（DM1–DM16）；`shellcheck` 干净；`SKILL.md` 637 行
（硬预算 640）；以及 20 + 12 次 clean fresh agent run（Group A–E）与隔离的 agent 级 mutation。

**已合并。** 第一轮 merge-safety review（权威 = 稳定 main）返回 `P0 = 0、P1 = 1`：Selection
Matrix 从未写明基础行是所有路由的地板、没有 R3 最低集行、S3 行无法改变任何选择。修复周期把地板
与 R3 最低集写成运行时规范文本、把守卫绑定到文档本身、新增"无触发表面的 R3"验收场景，并在修复
后的工件上重跑了 16 次 fresh agent run；最终独立 review（`05dd293..eab62b9`）返回 **PASS，
P0 = 0、P1 = 0**（2 个 P2 + 1 个 P3 记录为不阻断的跟进项）。Human Merge Gate 批准后，V2.1 已在
`84ae4af` 合并，合并后冒烟全绿（59/59 + 54/54、25/25、shellcheck 0），runtime 只同步了
SKILL.md。完整记录见 `release-evals/v2.1-gate1/m7-gate-report.md` 的 cycle 2。

## License

[MIT](LICENSE)
