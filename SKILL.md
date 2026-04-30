---
name: video-clip-maker
description: >
  One-shot video clip maker — analyze a long video or transcript for viral moments,
  cut precise clips with ffmpeg, and generate cover art + captions for each clip.
  Use when the user wants to: cut a long video into short clips, find highlights or
  "爆点" in a video/transcript, make clips for 小红书/抖音/视频号/TikTok/Reels,
  generate cover images and captions for video clips, or says things like
  "帮我剪切片", "找爆点", "剪成短视频", "视频切片", "highlight reel",
  "clip this video", "find the best moments", "切片", "短视频", "精彩片段",
  "viral clips", "帮我剪几个片段", "把视频切一下", "提取精华", "做切片",
  "cut highlights", "social media clips".
---

# Video Clip Maker — Cola 执行手册

你（Cola）收到用户的视频 + "帮我切片" 类指令后，按本手册执行全流程。

## 路径约定

Skill 安装目录：`~/.cola/skills/video-clip-maker/`

脚本调用时，拼接绝对路径：

```
SKILL_DIR="$HOME/.cola/skills/video-clip-maker"
```

- `$SKILL_DIR/scripts/probe-video.sh`
- `$SKILL_DIR/scripts/cut-clips.sh`
- `$SKILL_DIR/scripts/extract-frames.sh`

## 流程总览

```
接收视频 → 前置检查 → 转录 → 爆点分析 → 展示候选（等确认）
→ 剪切 → 封面帧提取 → 封面图生成 → 多平台文案 → 输出交付物
```

唯一等用户确认的环节：爆点候选列表。确认后全部自动跑完。

## 快速模式

如果用户直接给了时间段（如「帮我切 03:21-04:45 和 08:12-09:30」），跳过转录和爆点分析，直接进入 Stage 3 剪切。流程变为：

```
接收视频 + 时间段 → 前置检查 → 直接剪切 → 封面帧 → 封面图 → 文案 → 输出
```

不需要确认环节，用户已经明确指定了片段。

## 前置检查

```bash
SKILL_DIR="$HOME/.cola/skills/video-clip-maker"

# 检查 ffmpeg
if ! command -v ffmpeg &>/dev/null; then
  # 告诉用户：需要先装 ffmpeg（brew install ffmpeg），然后停止
fi

# 探测视频信息
bash "$SKILL_DIR/scripts/probe-video.sh" "视频文件路径"
```

**拒绝条件**：
- 视频时长 < 3 分钟 → 告诉用户视频太短不适合切片
- ffmpeg 不存在 → 告诉用户装一下 `brew install ffmpeg`，停止
- 视频文件无法读取 → 提示检查路径

## Stage 1: 转录

按优先级获取文本：

1. **用户已提供字幕/文本** → 直接用
2. **调用 coli skill 做 ASR** → 读取 coli skill 说明并执行转录
3. **全部失败** → 告诉用户提供 .srt 或文字稿

## Stage 2: 爆点分析

读完整转录文本，用 5 项标准对每个潜在片段打分（每项 0-2 分，满分 10）：

| 维度 | 0 分 | 1 分 | 2 分 |
|------|------|------|------|
| **开头抓人** | 平淡无感 | 有一定吸引力 | 前 3 秒就让人想看下去 |
| **信息差** | 大家都知道的事 | 有点新意 | 观众会觉得「卧槽」 |
| **情绪转折** | 情绪平平 | 有起伏但不强 | 明显反转/高潮 |
| **方法论** | 纯聊天无干货 | 有零散信息 | 有可复制的具体做法 |
| **独立性** | 必须看前面才懂 | 稍需背景能猜到 | 单独看完全成立 |

### 筛选规则

- 总分 ≥ 6 入选
- 按总分降序，取 top 3-7 个（视源视频长度）
- 每个片段 30-180 秒（60-90 秒最佳）
- 片段之间不重叠

### 展示格式（唯一确认环节）

向用户展示：

```markdown
## 🎬 候选切片（共 N 个）

| # | 时间段 | 时长 | 爆点标题 | 得分 | 得分明细 |
|---|--------|------|----------|------|----------|
| 1 | 03:21-04:45 | 84s | XXXX | 8/10 | 抓人2 信息差2 情绪1 方法论2 独立1 |
| 2 | ... | ... | ... | ... | ... |

确认这些片段 OK 吗？可以：
- 删除某个（「去掉第3个」）
- 调整时间（「第2个往后延10秒」）
- 补充（「XX那段也加上」）
- 直接说「OK」我就开始剪
```

等用户确认后，后续全部自动执行不再中断。

## Stage 3: 剪切

```bash
SKILL_DIR="$HOME/.cola/skills/video-clip-maker"
OUTPUT_DIR="视频切片-输出"
mkdir -p "$OUTPUT_DIR"

# 生成 clips.csv（start,end,filename 格式）
cat > "$OUTPUT_DIR/clips.csv" << 'EOF'
00:03:21,00:04:45,01-爆点标题.mp4
00:08:12,00:09:30,02-爆点标题.mp4
EOF

# 批量剪切
bash "$SKILL_DIR/scripts/cut-clips.sh" "源视频路径" "$OUTPUT_DIR" "$OUTPUT_DIR/clips.csv"
```

注意：
- 中文文件名报错时脚本会 fallback 到 `clip-01.mp4` 格式
- 大文件（>1GB）每片段 1-3 分钟，提前告知用户
- 可变帧率视频脚本已加 `-vsync cfr` 处理

## Stage 4: 封面生成

### 4.1 提取封面帧

```bash
bash "$SKILL_DIR/scripts/extract-frames.sh" "$OUTPUT_DIR"
```

脚本取片段 1/3 处选帧，避免黑屏和淡出。

### 4.2 生成封面图

对每个片段调用 `listenhub action=generate_image`：

**Prompt 构建规则**：
- 风格：现代社交媒体封面，高对比度，吸引眼球
- 内容：片段核心概念转化为视觉元素
- 文字：封面标题（2-3 个大字）嵌入 prompt
- 配色：深色背景 + 亮色文字（黄/白/红）
- ratio: `3:4`
- output_dir: `$OUTPUT_DIR/covers`

### 敏感词替换（封面文字）

- 商单 → 合作 / 接单
- 割韭菜 → 收智商税 / 踩坑
- 赚钱 → 搞钱 / 副业收入
- 月入X万 → 月X万

## Stage 5: 多平台文案

为每个片段生成 3 个平台的发布文案。

### 小红书
- 标题：20 字内，有悬念/反差/数字
- 正文：口语化，3-5 个 emoji，结尾引导互动
- 标签：5-8 个，大标签+精准小标签混合

### 抖音
- 标题：15 字内，强冲突，疑问句或感叹句
- 正文：1-2 句，信息密度高
- 标签：3-5 个热门标签

### 视频号
- 标题：25 字内，稍正式，信息量大
- 正文：3-4 句，有观点有深度
- 标签：3-5 个

### 文案反 AI 味规则

- 禁止「在这个XXX的时代」开头
- 禁止「让我们一起」「不禁让人」
- 多用短句、口语、网络用语
- 允许不完美句式（真人就是这样写的）

## 输出目录结构

```
视频切片-输出/
├── 01-爆点标题.mp4
├── 02-爆点标题.mp4
├── covers/
│   ├── 01-爆点标题-frame.jpg    （原始帧）
│   ├── 01-cover.png              （生成封面图）
│   └── ...
├── clips.csv                     （剪切参数）
├── source-info.json              （源视频信息）
└── clip-info.md                  （完整交付报告）
```

### clip-info.md 格式

```markdown
# 切片报告

源视频：XXX.mp4
时长：XX:XX:XX | 分辨率：1920x1080 | 大小：X.XGB

## 切片列表

### 1. 爆点标题（03:21-04:45，84s，得分 8/10）

**小红书**
- 标题：XXXX
- 正文：XXXX
- 标签：#xx #xx #xx

**抖音**
- 标题：XXXX
- 正文：XXXX
- 标签：#xx #xx #xx

**视频号**
- 标题：XXXX
- 正文：XXXX
- 标签：#xx #xx #xx

---
### 2. ...
```

## 错误处理

| 情况 | 处理 |
|------|------|
| ffmpeg 未安装 | 告诉用户 `brew install ffmpeg`，停止 |
| 视频 < 3 分钟 | 告知不适合切片 |
| ASR 失败 | 让用户提供 .srt 或文字稿 |
| 剪切失败 | 脚本 fallback 编号文件名；仍失败则跳过并报告 |
| 竖屏视频 | 保持原比例，不强制转横屏 |
| 封面图生成失败 | 退回提取帧方案 |
