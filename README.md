# ChooseMyLLM

**Find the right model for you.**

ChooseMyLLM 是一个用 Swift 和 SwiftUI 编写的 macOS 应用。填写用途、设备和偏好后，即可获得一个首选模型和最多两个备选，以及推荐理由和下一步使用方法。

```text
选择用途 → 确认设备 → 设置偏好 → 获取推荐 → 查看使用方法
```

## 功能

- **按需求推荐**：支持日常问答、编程、写作和学习，结合速度、质量、中文和免费偏好筛选模型。
- **识别 Mac 配置**：自动读取内存容量及 Apple silicon / Intel 类型，也可以手动调整。
- **本地与云端选择**：根据运行位置、内存和服务可用性筛选候选。
- **连接 Hugging Face**：刷新模型文件大小、访问限制和云端推理服务商状态，也提供独立的模型搜索入口。
- **提供使用指引**：本地模型提供可复制的 Ollama 命令；云端模型提供模型页和服务商入口。
- **缓存与离线回退**：网络不可用时使用缓存或内置数据，并显示数据状态。
- **原生启动体验**：欢迎页显示名称、版本和署名，随后自动进入可调整大小的主窗口。

## 运行项目

当前工程的最低系统版本设为 **macOS 27.0**，使用 **Xcode 27 或更新版本**打开。应用界面目前为英文。

```bash
git clone https://github.com/qixuan-xu/ChooseMyLLM.git
cd ChooseMyLLM
open ChooseMyLLM.xcodeproj
```

在 Xcode 中选择 `ChooseMyLLM` scheme 和 `My Mac`，按 **⌘R** 运行。如果 Xcode 要求配置签名，在 **Signing & Capabilities** 中选择自己的开发团队。

浏览公开模型资料无需 Hugging Face Token。只有实际在外部运行模型时，才需要安装 Ollama，或配置相应云端服务商的账号。

## 使用流程

1. 在 **Purpose** 选择用途。
2. 在 **Device** 选择本地、云端或两者皆可，并确认芯片与内存。
3. 在 **Preferences** 设置速度 / 均衡 / 质量、中文偏好和是否仅接受免费选项。
4. 点击 **Find my model** 查看推荐，再用 **Choose & see setup** 保存选择并查看运行指引。

如需手动探索其他模型，可以进入 **Browse HF**。模型的下载、运行和对话由 Ollama 或云端服务完成；ChooseMyLLM 当前负责推荐与使用指引。

## 推荐如何产生

当前内置 **9 个精选候选**，配置位于 [`recommendation-catalog.json`](ChooseMyLLM/recommendation-catalog.json)。推荐过程在本地完成：

1. 按运行位置、免费要求、中文偏好、访问限制和设备条件过滤候选。
2. 结合指定模型文件的大小与预留内存，估算本地运行需求；云端候选检查是否存在可用推理服务商。
3. 按人工维护的用途适配、速度和质量评分排序，返回最多三个结果。
4. 后台从 Hugging Face 更新候选资料，并据此更新结果。

Hugging Face 提供模型资料；用途和性能评分由项目维护，下载量与点赞数不参与自动推荐排名。

### 当前范围

- 候选库不覆盖全部 Hugging Face 模型，评分不是设备实测或公开 benchmark 排名。
- 本地推荐按 **Apple silicon** 评估；Intel 本地运行兼容性尚未评估。
- 内存估算基于指定量化版本、约 4K 上下文的短文本对话，并额外预留 5 GiB。更长上下文、图片和其他应用可能增加内存需求。
- 当前候选库没有已验证的免费云端服务，因此选择「云端 + 仅免费」可能没有匹配结果。
- 网络不可用时，缓存中的文件与服务商状态可能已经变化。

## 修改名称、版本与欢迎页

编辑根目录的 [`AppConfig.xcconfig`](AppConfig.xcconfig)，然后重新编译运行。Debug 和 Release 共用此配置，无需逐个修改 Swift 页面。

| 配置项 | 用途 | 当前值 |
| --- | --- | --- |
| `APP_DISPLAY_NAME` | 应用显示名称 | `ChooseMyLLM` |
| `MARKETING_VERSION` | 对用户显示的版本号 | `1.0` |
| `CURRENT_PROJECT_VERSION` | 内部构建号 | `1` |
| `APP_TAGLINE` | 欢迎页介绍 | `Find the right model for you.` |
| `APP_CREDIT` | 欢迎页署名 | `Created by Qixuan Xu` |
| `SPLASH_DURATION_SECONDS` | 欢迎页停留秒数；`0` 为立即进入 | `1.5` |

配置通过 [`ConfigInfo.plist`](ConfigInfo.plist) 写入应用，由 `AppConfiguration.swift` 统一读取。这是构建时配置，修改后需要重新构建应用。

## 项目结构

```text
ChooseMyLLM/
├── AppConfig.xcconfig               # 版本与品牌配置
├── ConfigInfo.plist                 # 应用元数据模板
├── ChooseMyLLM.xcodeproj/           # Xcode 工程
├── ChooseMyLLM/
│   ├── ChooseMyLLMApp.swift         # 启动流程与窗口管理
│   ├── AppConfiguration.swift      # 统一读取配置
│   ├── WelcomePage.swift           # 欢迎页
│   ├── MainView.swift              # 需求填写与主界面
│   ├── UserRequirements.swift      # 需求数据与硬件检测
│   ├── ModelRecommendations.swift  # 推荐规则与资料更新
│   ├── RecommendationResultsView.swift # 推荐结果与使用指引
│   ├── HuggingFaceClient.swift     # HF API、数据解析与缓存
│   ├── HuggingFaceModelsView.swift # 手动搜索模型
│   ├── recommendation-catalog.json # 精选候选与资料快照
│   └── hf-offline-models.json      # 搜索页离线数据
└── Tests/
    ├── RecommendationChecks.swift
    └── run-recommendation-checks.sh
```

## 检查推荐逻辑

在仓库根目录运行：

```bash
zsh Tests/run-recommendation-checks.sh
```

脚本使用 Xcode 的 Swift 工具链编译并执行独立检查，覆盖用途与偏好排序、内存筛选、免费云端无匹配、模型不可用等情况。检查使用本地目录数据，不需要联网或下载模型。

## 数据与网络

设备信息和推荐条件在本地处理。更新模型资料时，应用会向 Hugging Face 请求相应仓库的信息；手动搜索时会发送搜索词与筛选条件。网络请求直接使用公开的 Hugging Face Hub API，无需单独部署后端。

模型资料缓存在本机，所选模型 ID 保存在应用偏好中。应用当前不包含模型推理或聊天功能，也不会自动执行界面中提供的下载命令。
