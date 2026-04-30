# Cola Video Clipper

Cola skill：长视频一键切成爆款短视频。自动转录、找爆点、剪切、生封面、写文案。

> A Cola skill that turns long videos into viral short clips — auto-transcribe, find highlights, cut, generate covers & captions.

## 功能

- 🎯 智能爆点分析（5 维度评分）
- ✂️ ffmpeg 精确剪切
- 🖼️ AI 封面生成
- 📝 小红书 / 抖音 / 视频号 三套文案
- ⚡ 快速模式（直接指定时间段，跳过分析）

## 安装

在 Cola 中说：

> "安装视频切片 skill"

或手动克隆：

```bash
git clone https://github.com/heran11011/cola-video-clipper.git ~/.cola/skills/video-clip-maker
```

## 依赖

- [ffmpeg](https://ffmpeg.org/) — `brew install ffmpeg`

## 使用

把视频丢给 Cola，说：

```
帮我切片
```

```
帮我切 03:21-04:45 和 08:12-09:30
```

```
Clip this video into viral shorts
```

Cola 全自动执行，唯一需要你确认的是爆点候选列表。

## 输出

```
视频切片-输出/
├── 01-爆点标题.mp4
├── 02-爆点标题.mp4
├── covers/
│   ├── 01-cover.png
│   └── 02-cover.png
├── clips.csv
├── source-info.json
└── clip-info.md          ← 完整报告（含多平台文案）
```

## License

MIT © [heran11011](https://github.com/heran11011)
