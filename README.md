# 自定义 Arch Linux Distrobox image

## Arch Linux Distrobox 开发镜像

`Containerfile` 定义了一个使用 Arch Linux 官方镜像的 Distrobox 镜像；构建结束时会把软件源切换为中国大陆官方镜像。
镜像包含 .NET SDK、通过 rustup 安装的最新 stable Rust 工具链（含 rustfmt、clippy）、
Go 编译器工具链、Git、Git LFS、GitHub CLI（`gh`）、Python 包管理工具 `uv`、默认 shell Fish、`eza`、fastfetch、ouch、终端文件管理器 `yazi`、dotfiles 管理工具 `chezmoi`、`ffmpeg`、`mpv`、`bat`、`nano`、Vim、Neovim 和 Starship，
以及通过 fnm 安装并设为默认的最新 Node.js 26 LTS（Lithium）和通过其 npm 安装的 `pnpm`。`yazi` 同时安装搜索、预览、剪贴板和图标字体等可选依赖。系统级 Fish
配置会自动加载 fnm 环境。rust-analyzer 由连接到容器的 VS Code
扩展提供，无需安装在镜像中。Distrobox 默认共享宿主机 Home，因此 Fish 配置和
`~/.config/starship.toml` 主题配置会直接生效。
构建时用 pacman 安装基础构建依赖，再从 AUR 构建 paru；之后通过 paru 安装开发工具。
开发工具（Git、Rust、.NET SDK、Go、Git LFS、GitHub CLI、`uv`、fnm/Node.js、`pnpm`、Fish、`eza`、fastfetch、`ouch`、`yazi`、`chezmoi`、`ffmpeg`、`mpv`、`bat`、`nano`、Vim、Neovim、Starship）分别位于独立层，新增工具时可复用此前未变化的镜像层。
容器内可直接用 `mpv <文件>` 通过宿主机窗口和音频播放视频，或用 `bat` 代替 `cat` 查看带语法高亮的文件。

```sh
podman build -f Containerfile -t localhost/arch-distrobox:latest .
distrobox create --name arch-dev --image localhost/arch-distrobox:latest
```

## 构建时的系统升级

Arch Linux 是滚动发行版，不支持部分升级。镜像构建后面还要用 pacman/paru 安装多个包，
因此构建开头会先执行一次全量升级，避免新软件包链接到旧库。官方 `archlinux` OCI 基础镜像
不包含内核，Distrobox 容器也直接使用宿主机内核，所以这里的全量升级不会产生“两个内核”的问题。
当前使用 `pacman -Syyu`；其中双 `-y` 会强制重新下载数据库，通常只在更换镜像源或数据库异常时
才需要，常规构建使用 `-Syu` 即可。若更看重可复现性，可固定基础镜像的 digest，或改用
Arch Linux Archive 的快照源，而不是取消升级。

## 软件源

最终镜像的 `/etc/pacman.d/mirrorlist` 在构建最后被写入以下官方镜像，按顺序
自动回退：清华 TUNA、中科大 USTC、南京大学、阿里云，最后是 Arch 的全球 CDN
（`fastly.mirror.pkgbuild.com`、`geo.mirror.pkgbuild.com`）。构建过程本身仍使用
基础镜像自带的默认 CDN，因此不会拖慢 GitHub Actions 等海外构建环境。
这些地址都是 Arch Linux 官方镜像列表中的站点，不涉及 AUR 或 archlinuxcn。
镜像可用性可在 <https://archlinux.org/mirrors/status/> 查看。

需更换首选镜像时，可通过构建参数覆盖，例如：

```sh
podman build --build-arg ARCH_MIRROR=https://mirrors.ustc.edu.cn/archlinux \
    -f Containerfile -t localhost/arch-distrobox:latest .
```

运行时执行 `pacman -Syu` 会从这些镜像重新下载数据库。注意 `pacman-mirrorlist`
包升级后可能安装 `.pacnew` 并覆盖该文件，届时需要重新切换。

## 自动构建

GitHub Actions 使用 Podman，在针对 `main` 的推送、手动触发以及每周一北京时间
05:00 的定时任务中构建镜像；推送到 `main` 时会发布到 GitHub Container Registry，
镜像名为 `ghcr.io/linkcccp/arch-distrobox`。每次构建会添加上海时区的
`YYYYMMDDHHmm` 版本 tag（例如 `202611141229`）；默认分支构建也会更新 `latest` tag。

## 软件包变更记录

每次构建都会读取当前镜像的 `pacman -Q` 清单，并与上一个 GitHub
Release 附件中的 `packages.tsv` 对比，然后创建一个 `build-YYYYMMDDHHmm` Release。
Release 正文列出升级、降级、新增和删除的软件包；附件包含 `packages.tsv`、
`packages.json`、`changes.json` 和 `changes.md`。首次构建没有历史基线，只记录完整清单。

变更记录可在 <https://github.com/linkcccp/arch-distrobox/releases> 查看。

```sh
version=$(TZ=Asia/Shanghai date +%Y%m%d%H%M)
podman build -f Containerfile -t "localhost/arch-distrobox:$version" -t localhost/arch-distrobox:latest .
distrobox create --name arch-dev --image localhost/arch-distrobox:latest
```
