#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOTLAUNCHER_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
MON_ROOT="$(cd "$BOTLAUNCHER_ROOT/.." && pwd)"

PLATFORM="linux-x64"
NAPCAT_VERSION="latest"
PART_SIZE="80m"
FORCE_DOWNLOAD=0
KEEP_WORK=0
RELEASE_ROOT="${MON_NAPCAT_OFFLINE_RELEASE_ROOT:-$MON_ROOT/.release/napcat-offline}"
INSTALLER_URL="${MON_NAPCAT_INSTALLER_URL:-https://raw.githubusercontent.com/NapNeko/NapCat-Installer/main/script/install.sh}"

usage() {
  cat <<'EOF'
用法:
  BotLauncher/Script/Runtime/linux/build_napcat_offline_bundle.sh [选项]

选项:
  --version VERSION       NapCat 版本，默认 latest，例如 v4.18.7
  --platform PLATFORM     linux-x64 或 linux-arm64，默认 linux-x64
  --part-size SIZE        分卷大小，默认 80m
  --release-root PATH     输出根目录，默认 Mon/.release/napcat-offline
  --force                 重新下载已存在的文件
  --keep-work             保留临时工作目录
  -h, --help              显示帮助

环境变量:
  MON_NAPCAT_QQ_URL       覆盖 Linux QQ 下载地址
  MON_NAPCAT_SHELL_URL    覆盖 NapCat.Shell.zip 下载地址
  MON_NAPCAT_INSTALLER_URL 覆盖官方安装器下载地址
EOF
}

need_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[FAIL] 缺少命令: $cmd" >&2
    exit 1
  fi
}

download_file() {
  local url="$1"
  local output="$2"
  local label="$3"

  if [[ -f "$output" && "$FORCE_DOWNLOAD" -eq 0 ]]; then
    echo "[OK] 已存在，跳过下载: $label"
    return 0
  fi

  echo "[*] 下载 $label"
  echo "    $url"
  curl -fL --retry 3 --connect-timeout 20 -o "$output" "$url"
}

json_get() {
  local file="$1"
  local expr="$2"
  node -e '
const fs = require("fs");
const data = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const expr = process.argv[2];
if (expr === "tag") {
  console.log(data.tag_name || "");
} else if (expr === "napcat_shell") {
  const asset = (data.assets || []).find((item) => item.name === "NapCat.Shell.zip");
  console.log(asset ? asset.browser_download_url : "");
}
' "$file" "$expr"
}

default_qq_url() {
  case "$PLATFORM" in
    linux-x64)
      printf '%s\n' "https://dldir1.qq.com/qqfile/qq/QQNT/7516007c/linuxqq_3.2.25-45758_amd64.deb"
      ;;
    linux-arm64)
      printf '%s\n' "https://dldir1.qq.com/qqfile/qq/QQNT/7516007c/linuxqq_3.2.25-45758_arm64.deb"
      ;;
    *)
      echo "[FAIL] 不支持的平台: $PLATFORM" >&2
      exit 1
      ;;
  esac
}

write_install_offline_script() {
  local output="$1"

  cat > "$output" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOTLAUNCHER_ROOT=""
INSTALLER_ARGS=(--docker n --cli n --proxy 0 --confirm y)

usage() {
  cat <<'HELP'
用法:
  ./install-offline.sh [--botlauncher PATH] [-- <NapCat 官方安装器参数>]

示例:
  ./install-offline.sh --botlauncher /home/manager/work/Mon/BotLauncher
  ./install-offline.sh --botlauncher /home/manager/work/Mon/BotLauncher -- --docker n --cli n --proxy 0 --confirm y
HELP
}

find_botlauncher_root() {
  local current="$BUNDLE_DIR"
  while [[ "$current" != "/" ]]; do
    if [[ -f "$current/BotLauncher/.monconfig" ]]; then
      printf '%s\n' "$current/BotLauncher"
      return 0
    fi
    if [[ -f "$current/.monconfig" && "$(basename "$current")" == "BotLauncher" ]]; then
      printf '%s\n' "$current"
      return 0
    fi
    current="$(dirname "$current")"
  done
  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --botlauncher)
      BOTLAUNCHER_ROOT="${2:-}"
      shift 2
      ;;
    --)
      shift
      INSTALLER_ARGS=("$@")
      break
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      BOTLAUNCHER_ROOT="$1"
      shift
      ;;
  esac
done

if [[ -z "$BOTLAUNCHER_ROOT" ]]; then
  BOTLAUNCHER_ROOT="$(find_botlauncher_root || true)"
fi

if [[ -z "$BOTLAUNCHER_ROOT" || ! -f "$BOTLAUNCHER_ROOT/.monconfig" ]]; then
  echo "[FAIL] 未找到 BotLauncher 根目录，请使用 --botlauncher PATH 指定" >&2
  exit 1
fi

NAPCAT_HOME="${MON_NAPCAT_HOME:-$BOTLAUNCHER_ROOT/napcat}"
mkdir -p "$NAPCAT_HOME"

echo "================================================"
echo "NapCat 离线安装"
echo "================================================"
echo "离线包目录: $BUNDLE_DIR"
echo "BotLauncher: $BOTLAUNCHER_ROOT"
echo "部署目录: $NAPCAT_HOME"
echo

for required in install.sh NapCat.Shell.zip QQ.deb; do
  if [[ ! -f "$BUNDLE_DIR/$required" ]]; then
    echo "[FAIL] 离线包缺少文件: $required" >&2
    exit 1
  fi
done

if [[ -d "$BUNDLE_DIR/debs" ]] && compgen -G "$BUNDLE_DIR/debs/*.deb" >/dev/null; then
  echo "[*] 安装离线系统依赖包..."
  sudo apt install -y "$BUNDLE_DIR"/debs/*.deb
fi

cp -f "$BUNDLE_DIR/install.sh" "$NAPCAT_HOME/install.sh"
cp -f "$BUNDLE_DIR/NapCat.Shell.zip" "$NAPCAT_HOME/NapCat.Shell.zip"
cp -f "$BUNDLE_DIR/QQ.deb" "$NAPCAT_HOME/QQ.deb"
chmod +x "$NAPCAT_HOME/install.sh"

echo "[*] 执行官方安装器..."
(
  cd "$NAPCAT_HOME"
  export DEBIAN_FRONTEND=noninteractive
  HOME="$NAPCAT_HOME" bash ./install.sh "${INSTALLER_ARGS[@]}"
)

echo
echo "[NAPCAT_STATUS:OFFLINE_INSTALLED]"
echo "NapCat 离线安装完成。"
EOF

  chmod +x "$output"
}

write_restore_script() {
  local output="$1"
  local archive_name="$2"
  local bundle_name="$3"

  cat > "$output" <<EOF
#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
ARCHIVE_NAME="$archive_name"
BUNDLE_NAME="$bundle_name"
ARCHIVE_PATH="\$SCRIPT_DIR/\$ARCHIVE_NAME"

echo "================================================"
echo "NapCat 离线包恢复"
echo "================================================"
echo "目录: \$SCRIPT_DIR"

if [[ ! -f "\$ARCHIVE_PATH" ]]; then
  cat "\$SCRIPT_DIR"/"\$ARCHIVE_NAME".part* > "\$ARCHIVE_PATH"
fi

if [[ -f "\$SCRIPT_DIR/checksums.sha256" ]]; then
  (cd "\$SCRIPT_DIR" && sha256sum -c checksums.sha256)
fi

tar -xzf "\$ARCHIVE_PATH" -C "\$SCRIPT_DIR"

echo
echo "[NAPCAT_OFFLINE_BUNDLE:\$SCRIPT_DIR/\$BUNDLE_NAME]"
echo "恢复完成。执行安装:"
echo "  \$SCRIPT_DIR/\$BUNDLE_NAME/install-offline.sh --botlauncher /path/to/Mon/BotLauncher"
EOF

  chmod +x "$output"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      NAPCAT_VERSION="${2:-}"
      shift 2
      ;;
    --platform)
      PLATFORM="${2:-}"
      shift 2
      ;;
    --part-size)
      PART_SIZE="${2:-}"
      shift 2
      ;;
    --release-root)
      RELEASE_ROOT="${2:-}"
      shift 2
      ;;
    --force)
      FORCE_DOWNLOAD=1
      shift
      ;;
    --keep-work)
      KEEP_WORK=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[FAIL] 未知参数: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

need_cmd curl
need_cmd node
need_cmd sha256sum
need_cmd tar
need_cmd split

metadata_file="$(mktemp)"
trap 'rm -f "$metadata_file"' EXIT

if [[ "$NAPCAT_VERSION" == "latest" ]]; then
  curl -fsSL https://api.github.com/repos/NapNeko/NapCatQQ/releases/latest -o "$metadata_file"
  NAPCAT_VERSION="$(json_get "$metadata_file" tag)"
  NAPCAT_SHELL_URL="${MON_NAPCAT_SHELL_URL:-$(json_get "$metadata_file" napcat_shell)}"
else
  NAPCAT_SHELL_URL="${MON_NAPCAT_SHELL_URL:-https://github.com/NapNeko/NapCatQQ/releases/download/$NAPCAT_VERSION/NapCat.Shell.zip}"
fi

if [[ -z "$NAPCAT_VERSION" || -z "$NAPCAT_SHELL_URL" ]]; then
  echo "[FAIL] 无法解析 NapCat 版本或下载地址" >&2
  exit 1
fi

QQ_URL="${MON_NAPCAT_QQ_URL:-$(default_qq_url)}"
release_dir="$RELEASE_ROOT/dist/napcat/$PLATFORM/$NAPCAT_VERSION"
work_root="$RELEASE_ROOT/work"
bundle_name="NapCat-$PLATFORM-$NAPCAT_VERSION-offline"
bundle_dir="$work_root/$bundle_name"
archive_name="$bundle_name.tar.gz"
archive_path="$RELEASE_ROOT/work/$archive_name"

rm -rf "$release_dir" "$bundle_dir"
mkdir -p "$release_dir" "$bundle_dir" "$work_root"

echo "================================================"
echo "NapCat 离线包构建"
echo "================================================"
echo "Mon 根目录: $MON_ROOT"
echo "输出目录: $release_dir"
echo "版本: $NAPCAT_VERSION"
echo "平台: $PLATFORM"
echo

download_file "$INSTALLER_URL" "$bundle_dir/install.sh" "NapCat 官方安装器"
download_file "$NAPCAT_SHELL_URL" "$bundle_dir/NapCat.Shell.zip" "NapCat.Shell.zip"
download_file "$QQ_URL" "$bundle_dir/QQ.deb" "Linux QQ"
chmod +x "$bundle_dir/install.sh"
write_install_offline_script "$bundle_dir/install-offline.sh"

cat > "$bundle_dir/README.md" <<EOF
# NapCat Linux 离线包

- NapCat: $NAPCAT_VERSION
- Platform: $PLATFORM
- Target: BotLauncher/napcat

安装:

\`\`\`bash
./install-offline.sh --botlauncher /path/to/Mon/BotLauncher
\`\`\`
EOF

rm -f "$archive_path"
tar -czf "$archive_path" -C "$work_root" "$bundle_name"

split --bytes="$PART_SIZE" --numeric-suffixes=1 --suffix-length=3 "$archive_path" "$release_dir/$archive_name.part"
write_restore_script "$release_dir/restore-napcat-offline.sh" "$archive_name" "$bundle_name"

(
  cd "$release_dir"
  sha256sum "$archive_name".part* > checksums.sha256
)

part_json="$(find "$release_dir" -maxdepth 1 -type f -name "$archive_name.part*" -printf '%f\n' | sort | node -e '
const fs = require("fs");
const files = fs.readFileSync(0, "utf8").trim().split(/\n/).filter(Boolean);
console.log(JSON.stringify(files));
')"

archive_sha="$(sha256sum "$archive_path" | awk '{print $1}')"
created_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

node - <<EOF > "$release_dir/manifest.json"
const fs = require("fs");
const path = require("path");
const releaseDir = "$release_dir";
const parts = $part_json;
const stat = (name) => fs.statSync(path.join(releaseDir, name));
const manifest = {
  name: "napcat-offline-runtime",
  version: "$NAPCAT_VERSION",
  platform: "$PLATFORM",
  createdAt: "$created_at",
  archive: {
    name: "$archive_name",
    sha256: "$archive_sha",
    parts: parts.map((name) => ({ name, size: stat(name).size })),
  },
  files: [
    { name: "manifest.json" },
    { name: "checksums.sha256" },
    { name: "restore-napcat-offline.sh" },
  ],
  install: {
    target: "BotLauncher/napcat",
    command: "./install-offline.sh --botlauncher /path/to/Mon/BotLauncher"
  },
  sources: {
    installer: "$INSTALLER_URL",
    napcatShell: "$NAPCAT_SHELL_URL",
    linuxQQ: "$QQ_URL"
  }
};
console.log(JSON.stringify(manifest, null, 2));
EOF

if [[ "$KEEP_WORK" -eq 0 ]]; then
  rm -rf "$bundle_dir" "$archive_path"
fi

echo
echo "[NAPCAT_OFFLINE_DIST:$release_dir]"
echo "NapCat 离线包构建完成。"
