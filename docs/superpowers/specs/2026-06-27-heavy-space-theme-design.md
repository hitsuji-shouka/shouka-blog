# 重型星际主题网站设计

> 日期：2026-06-27  
> 状态：待用户复核  
> 范围：将现有博客前端重构为接近参考项目的星际穿越 / HUD / TARS 风格，并引入 Three.js 级别的重型视觉特效。

## 背景

当前博客是明亮插画风格，导航、文章卡片、助理面板都偏轻量。参考项目「Kimi_Agent_网站设计」更接近用户理想：深色星际背景、黑洞/星空、HUD 扫描线、warp 页面转场、TARS 风格助手面板和发光控制台卡片。

本次改造目标不是简单换色，而是把网站视觉系统升级为“星际穿越式个人知识站”。业务能力保持不变：文章数据、理财早报、音频早报、RAG 问答助手接口都继续沿用。

## 目标

- 首页首屏建立强烈的第一印象：黑洞、星云、星空、HUD 文案和分类入口。
- 页面切换有 warp 粒子转场，增强“穿梭感”。
- 科技、理财、随笔入口具备星系导航观感。
- 文章卡片、音频模块、详情页元数据统一为 HUD 控制台风格。
- 助手面板改造成 TARS 风格全息面板，但仍调用现有问答 API。
- 桌面端完整特效，移动端自动降级，保证不卡顿、不黑屏。
- 前端测试和构建通过。

## 非目标

- 不改后端文章接口和数据库模型。
- 不改理财早报 pipeline、MiniMax TTS、发布逻辑。
- 不新增复杂后台配置。
- 不把参考项目整套复制进来；只吸收视觉语言和关键特效。
- 不在第一版实现完整物理级黑洞光线追踪。

## 视觉系统

### 色彩

使用深色星际色系：

- `--deep-space`: 近黑背景。
- `--void`: 面板底色。
- `--nebula`: 次级面板底色。
- `--starlight`: 主文字。
- `--dim`: 次级文字。
- `--cyan`: HUD 主光色。
- `--amber`: 关键状态和强调。
- `--mars`: 危险/用户消息强调。
- `--violet`: 星云过渡色。

避免全站只有单一蓝紫色。青色用于 HUD，琥珀色用于焦点，红/紫用于星云和状态点。

### 字体与排版

- 中文正文继续优先使用系统中文字体，保证可读性。
- 导航、状态码、元数据使用等宽字体，形成控制台感。
- Hero 标题用更大字号和紧凑行高，但文章正文保持舒适阅读行宽。

### 卡片

文章卡片从 AntD 默认卡片改为 HUD 面板：

- 半透明深色底。
- 1px 青色低透明边框。
- hover 时边框变亮、轻微上浮、内外发光。
- 标签、日期、音频状态以小型状态 chip 呈现。

## 页面设计

### 首页

首屏为全屏沉浸式 hero：

- 背景：Three.js 黑洞 / 星云 / 星点场景。
- 左侧：品牌名 `shouka.blog`、一句短描述、分类入口。
- 右侧或背景层：黑洞/星云 3D 场景。
- 首屏底部露出最新文章区，避免像纯 landing page。

首屏之后是最新文章列表，使用 HUD 文章卡片。

### 分类页

保留现有分类路由：

```text
/category/科技
/category/理财
/category/随笔
```

分类页顶部增加 HUD 标题带，理财/科技继续按“原创 / 每日报告”分区。列表卡片使用统一 HUD 风格。

### 文章详情页

文章详情保持阅读优先：

- 顶部显示 HUD 风格标题、分类、日期、标签。
- 如果有 `audio` 字段，显示控制台式音频模块。
- 正文区域不做过多动画，保证长文阅读稳定。
- 代码块、引用、链接改为深色主题样式。

### 助手面板

保留现有 `sendChat` 流式问答逻辑，重做 UI：

- 浮动按钮从 Totoro 图标改为 TARS 呼吸条按钮。
- 面板为全息 HUD 样式。
- 用户消息用琥珀色边框，助手消息用青色边框。
- 来源标签保留，样式改为 HUD chip。
- 输入区使用深色控制台输入框。

## 特效设计

### BlackHoleScene

新增 `BlackHoleScene` 组件：

- 使用 `three` + `@react-three/fiber`。
- 第一版使用 shader plane 或 points + ring 的简化黑洞视觉。
- 包含事件视界暗核、吸积盘、星点背景和缓慢旋转。
- 桌面端默认开启。
- 移动端降低粒子数量和像素比。

### GalaxyNav

新增 `GalaxyNav` 组件：

- 三个分类作为轨道节点。
- 节点点击进入对应分类页。
- 节点 hover 有发光和轨道提示。
- 移动端退化为横向 HUD 按钮组。

### WarpCanvas

新增 `WarpCanvas`：

- 独立全屏 canvas 层。
- 路由变化时触发粒子加速、穿梭、减速和淡出。
- 不阻塞页面真实路由太久，动画完成后滚动回顶部。
- 如果用户开启 `prefers-reduced-motion`，跳过 warp。

### ScrollProgress

右侧增加细线滚动进度条：

- 使用 CSS/scroll 事件。
- 青色低亮度，滚动时更新高度。
- 移动端可保留，宽度更细。

## 移动端性能兜底

移动端不是关闭特效，而是自动降级：

- 降低 Three.js 粒子数量。
- 限制 `devicePixelRatio`，避免超高清渲染导致发热。
- 关闭或减弱复杂 glow、blur、色差效果。
- `prefers-reduced-motion: reduce` 时禁用 warp 转场和大幅动画。
- WebGL 初始化失败时显示 CSS 星空背景。
- 首屏文字和导航优先渲染，3D 场景可延后加载。

## 技术方案

新增依赖：

```text
three
@react-three/fiber
@react-three/drei
gsap
lucide-react
```

主要新增/修改文件：

- `frontend/src/components/BlackHoleScene.tsx`
- `frontend/src/components/WarpCanvas.tsx`
- `frontend/src/components/GalaxyNav.tsx`
- `frontend/src/components/ScrollProgress.tsx`
- `frontend/src/components/ReducedMotion.ts`
- `frontend/src/components/AssistantPanel.tsx`
- `frontend/src/components/PostCard.tsx`
- `frontend/src/components/PostAudio.tsx`
- `frontend/src/pages/Home.tsx`
- `frontend/src/pages/Category.tsx`
- `frontend/src/pages/Post.tsx`
- `frontend/src/main.tsx`
- `frontend/src/index.css`
- 前端相关测试文件

## 数据与接口

不新增后端接口。继续使用：

- `listPosts()`
- `listPosts(category)`
- `getPost(slug)`
- `sendChat(...)`

`audio` 字段继续由文章详情页读取，样式改为 HUD 音频模块。

## 测试与验证

- 单元测试：文章卡片、音频模块、warp/reduced-motion 辅助逻辑。
- 构建验证：`npm test`、`npm run build`。
- 浏览器验证：
  - 桌面：1440x900，确认黑洞/星云、warp、HUD 卡片、助手面板正常。
  - 移动：390x844，确认特效降级、导航可用、文字不重叠。
  - reduced motion：确认关闭 warp 和大幅动画。

## 验收标准

- 首页首屏出现深色星际 hero，包含 3D 黑洞/星空效果。
- 点击导航或文章时有 warp 转场；减少动态效果时不播放。
- 三个分类入口有星系导航或移动端 HUD 入口。
- 文章列表和详情页统一为深色 HUD 风格。
- 助手面板使用 TARS 风格，但问答功能保持可用。
- 理财早报音频播放器在深色主题下可用、清晰。
- 移动端无明显横向溢出、文字重叠或白屏。
- `npm test` 和 `npm run build` 通过。
