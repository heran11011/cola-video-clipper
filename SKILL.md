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

# Video Clip Maker

用户丢一个视频文件 + 说一句「帮我切片」，自动走完全流程，输出一个文件夹包含切好的片段、封面图、平台文案。

## 端到端流程

```
用户给视频 → 探测视频信息 → ASR 转录 → 分析爆点并打分排序
→ 展示候选列表（唯一等用户确认的环节）
→ 用户确认后：自动剪切 → 提取封面帧 → 生成封面图 → 写多平台文案
→ 输出完整交付物
```

**只有一个确认环节**：爆点候选列表展示后等用户说「OK」或调整，之后全部自动跑完。

## 前置检查

开始前必须执行：

```bash
# 1. 检查 ffmpeg
if ! command -v ffmpeg &>/dev/null; then
  echo "需要安装 ffmpeg: brew install ffmpeg"
  exit 1
fi

# 2. 探测视频信息（用 scripts/probe-video.sh）
bash scripts/probe-video.sh "视频文件路径"
```

**拒绝条件**：
- 视频时长 < 3 分钟 → 告诉用户「视频太短，不太适合做切片，建议直接发完整版」
- ffmpeg 不存在 → 给安装命令（`brew install ffmpeg`）
- 视频文件无法读取 → 提示检查路径

## Stage 1: 转录

获取视频文本内容，按以下优先级：

1. **用户已提供字幕文件/文本** → 直接用
2. **用 coli skill 做 ASR** → 优先（如已安装 coli skill）
3. **coli 不可用时用 whisper** →
```bash
# 提取音频
ffmpeg -i "INPUT" -vn -acodec pcm_s16le -ar 16000 -ac 1 -y "/tmp/audio-for-asr.wav"
# 调用 whisper（需要用户已安装）
whisper "/tmp/audio-for-asr.wav" --language zh --output_format srt
```
4. **全部失败** → 告诉用户：「ASR 没搞定，你可以给我一个字幕文件（.srt/.txt），或者直接把文字贴给我」

## Stage 2: 爆点分析

读完整转录文本，用以下 5 项标准对每个潜在片段打分（每项 0-2 分，满分 10）：

| 维度 | 0 分 | 1 分 | 2 分 |
|------|------|------|------|
| **开头抓人** | 开头平淡无感 | 有一定吸引力 | 前 3 秒就让人想看下去 |
| **信息差** | 大家都知道的事 | 有点新意 | 观众大概率不知道、会觉得「卧槽」 |
| **情绪转折** | 情绪平平 | 有起伏但不强 | 明显从 A 情绪到 B 情绪（反转/高潮） |
| **方法论** | 纯聊天无干货 | 有零散信息 | 有可复制的、具体的做法/步骤 |
| **独立性** | 必须看前面才懂 | 稍需背景但能猜到 | 拿出来单独看完全成立 |

### 筛选规则

- 总分 ≥ 6 的片段入选
- 按总分降序排列，取 top 3-7 个（视源视频长度）
- 每个片段控制在 30-180 秒（60-90 秒最佳）
- 不同片段之间不要重叠

### 展示格式（唯一确认环节）

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

**等用户确认后，后续全部自动执行，不再中断。**

## Stage 3: 剪切

用户确认后，执行剪切：

1. 创建输出目录结构
2. 生成 clips.csv 文件
3. 调用脚本批量剪切

```bash
# 创建输出目录
OUTPUT_DIR="视频切片-输出"
mkdir -p "$OUTPUT_DIR"

# 生成 clips.csv（start,end,filename 格式）
cat > "$OUTPUT_DIR/clips.csv" << 'EOF'
00:03:21,00:04:45,01-爆点标题.mp4
00:08:12,00:09:30,02-爆点标题.mp4
EOF

# 批量剪切
bash scripts/cut-clips.sh \
  "源视频路径" "$OUTPUT_DIR" "$OUTPUT_DIR/clips.csv"
```

### 注意事项
- 中文文件名如果 ffmpeg 报错，脚本会自动 fallback 到 `clip-01.mp4` 格式
- 大文件（>1GB）每个片段可能需要 1-3 分钟，提前告知用户
- 源视频如果是可变帧率，脚本已加 `-vsync cfr` 处理

## Stage 4: 封面生成

### 4.1 提取封面帧

```bash
bash scripts/extract-frames.sh "$OUTPUT_DIR"
```

脚本会智能选帧（取片段 1/3 处而非固定时间点，避免黑屏和淡出）。

### 4.2 用 ListenHub 生成封面图

对每个片段，基于内容自动生成封面图 prompt 并调用 `listenhub generate_image`：

**Prompt 构建规则**：
- 风格：现代社交媒体封面，高对比度，吸引眼球
- 内容：提取片段核心概念，转化为视觉元素
- 文字：封面标题文字（2-3 个大字）嵌入 prompt
- 配色：深色背景 + 亮色文字（黄/白/红）

```
调用方式：
listenhub action=generate_image
  prompt="[基于片段内容生成的具体 prompt]"
  ratio="3:4"
  output_dir="$OUTPUT_DIR/covers"
```

每个片段生成一张封面图，保存到 `$OUTPUT_DIR/covers/` 目录。

### 敏感词处理

中文平台封面文字避免：
- 商单 → 合作 / 接单
- 割韭菜 → 收智商税 / 踩坑
- 赚钱 → 搞钱 / 副业收入
- 月入X万 → 月X万（去掉"入"字也可能被限）

## Stage 5: 多平台文案

为每个片段生成 3 个平台的发布文案：

### 小红书风格
- 标题：20 字内，有悬念/反差/数字，像朋友在跟你说话
- 正文：口语化，带 emoji 但不过度（3-5个），结尾引导互动（「你们觉得呢？」「有同款经历吗？」）
- 标签：5-8 个，混合大标签+精准小标签

### 抖音风格
- 标题：15 字内，强冲突，疑问句或感叹句
- 正文：1-2 句话够了，信息密度高
- 标签：3-5 个热门标签

### 视频号风格
- 标题：稍正式，信息量大，可以长一点（25 字内）
- 正文：3-4 句，有观点有深度
- 标签：3-5 个

**文案语气要求**：像一个真人运营写的，不要 AI 味。具体来说：
- 不要用「在这个XXX的时代」开头
- 不要用「让我们一起」「不禁让人」
- 多用短句、口语、网络用语
- 可以有不完美的句式（真人就是这样写的）

## 输出目录结构

```
视频切片-输出/
├── 01-爆点标题.mp4
├── 02-爆点标题.mp4
├── 03-爆点标题.mp4
├── covers/
│   ├── 01-爆点标题-frame.jpg    （原始帧）
│   ├── 01-cover.png              （生成的封面图）
│   ├── 02-爆点标题-frame.jpg
│   ├── 02-cover.png
│   └── ...
├── clips.csv                     （剪切参数记录）
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
| ffmpeg 未安装 | 输出 `brew install ffmpeg` 并停止 |
| 视频 < 3 分钟 | 告知用户不适合切片，建议直接发 |
| ASR 全部失败 | 让用户提供 .srt 或文字稿 |
| ffmpeg 剪切失败 | 脚本自动 fallback 编号文件名；如果还失败则跳过并报告 |
| 视频是竖屏 | 保持原比例剪切，不强制转横屏 |
| 封面图生成失败 | 退回到提取帧 + 文字 spec 方案 |

## 脚本位置

所有辅助脚本在 skill 目录下：

- `scripts/probe-video.sh` — 快速探测视频元信息（时长/分辨率/帧率/文件大小）
- `scripts/cut-clips.sh` — 批量精确剪切，带进度显示
- `scripts/extract-frames.sh` — 智能选帧提取封面素材

调用时使用相对路径（skill 目录下）：`scripts/`
