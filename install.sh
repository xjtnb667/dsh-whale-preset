#!/usr/bin/env bash
# 给 DeepSeek Harness 装一个额外的 agent 预设 `whale`（官方 standard 的逐字副本）。
#
# 用法:
#   bash ./install.sh                       # 默认找 $DSH_HOME 或 ~/.dsh，profile=desktop
#   DSH_HOME=/path/to/.dsh bash ./install.sh
#   bash ./install.sh --profile web --dry-run
#
# 做三件事：复制 bundle 到 local-bundles/whale-preset；登记 dependencies；
# 追加到 dsh.profile.bundles。改 package.json 前会自动备份。
set -euo pipefail

PKG_NAME="dsh-whale-preset"
PROFILE="desktop"
DRY_RUN=0
DSH_HOME_ARG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --home)    DSH_HOME_ARG="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "未知参数: $1" >&2; exit 2 ;;
  esac
done

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -n "$DSH_HOME_ARG" ]; then
  DSH_HOME_DIR="$DSH_HOME_ARG"
elif [ -n "${DSH_HOME:-}" ]; then
  DSH_HOME_DIR="$DSH_HOME"
else
  DSH_HOME_DIR="$HOME/.dsh"
fi

PROFILE_DIR="$DSH_HOME_DIR/profiles/$PROFILE"
PROFILE_PKG="$PROFILE_DIR/package.json"
DEST_DIR="$PROFILE_DIR/local-bundles/whale-preset"

echo "DSH home : $DSH_HOME_DIR"
echo "profile  : $PROFILE_DIR"

[ -d "$PROFILE_DIR" ]  || { echo "profile 目录不存在：$PROFILE_DIR（用 --profile 指定）" >&2; exit 1; }
[ -f "$PROFILE_PKG" ]  || { echo "找不到 profile 的 package.json：$PROFILE_PKG" >&2; exit 1; }
for f in cordis.patch.yml package.json LICENSE; do
  [ -f "$HERE/$f" ] || { echo "缺少文件：$HERE/$f" >&2; exit 1; }
done

echo
echo "[1/3] 复制 bundle -> $DEST_DIR"
if [ "$DRY_RUN" = "1" ]; then
  echo "      (dry-run) 会复制 cordis.patch.yml / package.json / LICENSE"
else
  mkdir -p "$DEST_DIR"
  cp -f "$HERE/cordis.patch.yml" "$DEST_DIR/"
  cp -f "$HERE/package.json"     "$DEST_DIR/"
  cp -f "$HERE/LICENSE"          "$DEST_DIR/"
  echo "      已复制 3 个文件"
fi

echo
echo "[2/3] 登记依赖"
echo "[3/3] 追加到 dsh.profile.bundles"

EDITED=""
for CAND in python3 python; do
  if command -v "$CAND" >/dev/null 2>&1; then
    if "$CAND" -c "import json,sys" >/dev/null 2>&1; then EDITED="$CAND"; break; fi
  fi
done

if [ -z "$EDITED" ]; then
  cat <<EOF

找不到 python3/python，请手动改 $PROFILE_PKG：

  "dependencies": { "$PKG_NAME": "link:./local-bundles/whale-preset" }
  "dsh": { "profile": { "bundles": [ ...原有..., "$PKG_NAME" ] } }

EOF
  exit 0
fi

export MC_PKG="$PROFILE_PKG" MC_NAME="$PKG_NAME" MC_DRY="$DRY_RUN"
"$EDITED" - <<'PY'
import json, os, shutil, sys, time

path  = os.environ["MC_PKG"]
name  = os.environ["MC_NAME"]
dry   = os.environ.get("MC_DRY") == "1"
value = "link:./local-bundles/whale-preset"

raw = open(path, encoding="utf-8").read()
pkg = json.loads(raw)

deps = pkg.setdefault("dependencies", {})
if deps.get(name) == value:
    print("      依赖已存在，保持不动")
else:
    if name in deps:
        print("      依赖值不同：%r -> %r" % (deps[name], value))
    deps[name] = value
    print("      已加依赖 %s = %s" % (name, value))

profile = pkg.setdefault("dsh", {}).setdefault("profile", {})
bundles = profile.get("bundles", [])
if not isinstance(bundles, list):
    bundles = []
if name in bundles:
    print("      bundles 里已有，保持不动")
else:
    bundles.append(name)
    profile["bundles"] = bundles
    print("      已追加：%s" % ", ".join(bundles))

if dry:
    print("\n(dry-run) 没有写任何文件。")
    sys.exit(0)

backup = path + ".bak-" + time.strftime("%Y%m%d-%H%M%S")
shutil.copy2(path, backup)
with open(path, "w", encoding="utf-8", newline="\n") as f:
    json.dump(pkg, f, ensure_ascii=False, indent=2)
    f.write("\n")
print("\n备份：%s" % backup)
print("已写入：%s" % path)
PY

cat <<EOF

装好了。下一步：

  1. 完全退出 DSH，再重新打开（bundle 只在启动时读）
  2. 新建会话时预设选 'whale'，或者让插件用它：
       $DSH_HOME_DIR/profiles/$PROFILE/cordis.patch.yml 里给那个插件加
       agentPreset: whale
  3. 验证：用 standard 开一个窗口，确认它没有被塞进那个插件的人设

撤销：把 $PROFILE_PKG.bak-* 覆盖回 package.json，删掉 $DEST_DIR，重启。
EOF
