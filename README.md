# dsh-whale-preset

给 [DeepSeek Harness](https://github.com/deepseek-ai) 加一个**额外的 agent 预设 `whale`**：
它是官方 `standard` 预设的**逐字副本**，插件列表、顺序、`disabled` 标记、长 section 全一样，
只改了两处名字：

| | standard | whale |
|---|---|---|
| Loader 行 id | `preset-standard` | `preset-whale` |
| 预设 config id | `standard` | `whale` |

就这两行不一样。所以装它**不会改变任何行为**——它的用处是「给一类会话一个独立的预设身份」。

> English: an extra DSH agent preset `whale`, byte-for-byte the shipped `standard`
> declaration except its preset id. Nothing behaves differently; it exists so that
> plugins which scope themselves by preset name can treat one preset differently.

---

## 为什么需要这一份

有些插件按「预设名」判断「这条会话归不归我管」。例如 `dsh-world`（给她一个房间/日记/人设的插件）里：

```js
// dsh-world/lib/sourceArchive.js
export function belongsToWorld(session, config) {
  const header = session.header;
  return header.agentPreset === config.agentPreset
      && header.origin !== 'subagent'
      && (header.delegationDepth ?? 0) === 0;
}
```

它把「世界人设」注入到所有 `agentPreset === config.agentPreset` 的会话里。
默认两边都是 `standard`，于是**你随便开一个窗口也会被塞进那个人设**——白吃几千 token，
而且你会分不清「我在跟谁说话」。

`whale` 的作用就一个：**给那个世界一个专属预设名**。之后

- 那个世界的会话 → `agentPreset: whale` → 有它自己的人设；
- 你其它的窗口 → `agentPreset: standard` → 干干净净。

同一套机制对任何「按预设名分流」的插件都成立，不只 `dsh-world`。

---

## 安装

要求：DeepSeek Harness 桌面版 / Web 版，能找到 `<DSH_HOME>`（Windows 默认 `%USERPROFILE%\.dsh`，
macOS/Linux 默认 `~/.dsh`），profile 目录名默认 `desktop`。

### 方式一：脚本（推荐）

```powershell
# Windows
git clone https://github.com/xjtnb667/dsh-whale-preset
cd dsh-whale-preset
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

```bash
# macOS / Linux
git clone https://github.com/xjtnb667/dsh-whale-preset
cd dsh-whale-preset
bash ./install.sh
```

脚本做三件事：把 bundle 复制到 `<DSH_HOME>/profiles/desktop/local-bundles/whale-preset`；
在 profile 的 `package.json` 里登记依赖 `link:./local-bundles/whale-preset`；
把 `dsh-whale-preset` 追加进 `dsh.profile.bundles`。改之前会自动备份 `package.json`。

### 方式二：手动（30 秒）

1. 复制本仓库三个文件到 `<DSH_HOME>/profiles/desktop/local-bundles/whale-preset/`
   （`cordis.patch.yml`、`package.json`、`LICENSE`）

2. 打开 `<DSH_HOME>/profiles/desktop/package.json`，加两处：

```json
{
  "dependencies": {
    "dsh-whale-preset": "link:./local-bundles/whale-preset"
  },
  "dsh": {
    "profile": {
      "bundles": [
        "@deepseek-ai/dsh-base",
        "dsh-world",
        "dsh-whale-preset"
      ]
    }
  }
}
```

（`dependencies` 和 `bundles` 里原有的内容别删，只在末尾加一行。）

3. **重启 DSH**。

---

## 用法

装完之后有两种用法：

**A. 手动给某条会话指定预设** —— 新建会话时选 `whale`（GUI 里有预设选择），这条会话就用 whale。

**B. 让插件自动用它** —— 例如 `dsh-world` 的配置里把 `agentPreset` 改掉：

```yaml
# <DSH_HOME>/profiles/desktop/cordis.patch.yml
- id: dsh-world
  config:
    agentPreset: whale
```

改完重启。之后那个插件自己建出来的会话（房间、闹钟唤醒的新家）就是 `whale`，你的窗口还是 `standard`。

---

## 验证是否生效

1. 重启后新建一条会话，检查它的 header 里 `agentPreset` 是不是 `whale`。
2. 或者看效果：用 `standard` 开一个窗口，确认**没有**被塞进那个插件的人设/房间提示。
3. 预设列表里应该多出 `whale` 一项。

---

## 卸载

删掉 `dsh.profile.bundles` 里的 `dsh-whale-preset`、`dependencies` 里的那一行，删掉
`local-bundles/whale-preset` 目录，重启。已经用 `whale` 建过的会话会变成「找不到预设」，
把它们归档或删掉即可。

---

## 兼容性与注意

- **这份 patch 是某个 DSH 版本的 `standard` 快照**（2026-11 的桌面版）。DSH 升级后如果
  `standard` 里增删了插件，这一份不会自动跟着变——需要重新照抄一次。查看当前版本的标准预设：
  `resources/app.asar` 里 `@deepseek-ai/dsh-web-app/presets/standard.patch.yml`。
- `whale` 这个名字要求**小写字母**（预设 id 的校验就是这么写的）。
- patch 里每个 `name` 都是官方包名（`@deepseek-ai/dsh-tool-fs` 等），它们随宿主一起提供，
  **不需要另外 npm install**。所以这个仓库没有运行时依赖，也不用打包。
- 用了 `billion-context` 的人：把 `cordis.patch.yml` 换成 `cordis.patch.billion-context.yml`
  （多一行 `inject: [biliBasicCompactionPolicy]`，官方 standard 也是靠这一行挂上 compaction policy）。
  没装那个插件的人**不要**用带 inject 的版本，会引用不存在的行。
- 这个仓库不含任何个人数据：没有人名、没有路径、没有房间内容，只有一份预设声明。

## License

MIT
