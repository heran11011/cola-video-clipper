# Cola Video Clipper

长视频一键切成爆款短视频——自动转录、找爆点、剪切、生封面、写文案。

> One-shot long video → viral short clips: auto-transcribe, find highlights, cut, generate covers & captions.

## ✨ 功能 / Features

- 🎯 **智能爆点分析** — 5 维度评分体系，自动找到最值得切的片段
- ✂️ **精确剪切** — ffmpeg 精确到帧，自动处理可变帧率
- 🖼️ **AI 封面生成** — 智能选帧 + AI 生成社交媒体封面图
- 📝 **多平台文案** — 小红书 / 抖音 / 视频号 三套风格，一步到位
- 🤖 **全自动流程** — 确认爆点列表后全程无需干预

## 📦 安装 / Install

**方式 1**：在 Cola 中直接说：

> "安装 video clipper skill"

**方式 2**：手动安装

```bash
git clone https://github.com/heran11011/cola-video-clipper.git ~/.cola/skills/video-clip-maker
```

## 🔧 前置依赖 / Prerequisites

- [ffmpeg](https://ffmpeg.org/) — `brew install ffmpeg`
- [Cola](https://github.com/anthropics/cola) AI assistant

## 🚀 使用 / Usage

把视频丢给 Cola，说一句话就行：

```
帮我切片
```

```
这个视频帮我找爆点，剪成短视频
```

```
Clip this video into viral shorts
```

Cola 会自动：转录 → 分析爆点 → 展示候选列表 → 你说 OK → 剪切 + 封面 + 文案，全部搞定。

## 📁 输出结构 / Output

```
视频切片-输出/
├── 01-爆点标题.mp4
├── 02-爆点标题.mp4
├── covers/
│   ├── 01-cover.png
│   └── 02-cover.png
├── clips.csv
├── source-info.json
└── clip-info.md          ← 完整交付报告（含多平台文案）
```

## 📜 License

MIT © [heran11011](https://github.com/heran11011)
