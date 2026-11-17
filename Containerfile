FROM archlinux:latest

# 强制刷新软件包数据库，并先升级基础系统。
RUN pacman -Syyu --noconfirm \
    && pacman -Scc --noconfirm

# 安装从 AUR 构建 paru 所需的基础依赖。
RUN pacman -S --noconfirm --needed base-devel sudo \
    && pacman -Scc --noconfirm

# 单独安装 Git；后续用于获取 paru 的 AUR 构建脚本。
RUN pacman -S --noconfirm --needed git \
    && pacman -Scc --noconfirm

# 单独安装 rustup；后续用它安装最新 stable Rust。
RUN pacman -S --noconfirm --needed rustup \
    && pacman -Scc --noconfirm

# 为容器内所有用户共享 rustup 工具链，并提供全局命令入口。
ENV RUSTUP_HOME=/opt/rustup
ENV PATH=/usr/local/bin:${PATH}

# 安装最新 stable 工具链，并创建 rustup 命令代理。
RUN rustup toolchain install stable --profile default \
    && rustup default stable \
    && install -d /usr/local/bin \
    && for command in cargo rustc rustdoc rustfmt cargo-fmt clippy-driver cargo-clippy; do \
        ln -sf /usr/bin/rustup "/usr/local/bin/$command"; \
    done

# 通过 rustup 安装 Rust 格式化和静态检查组件。
RUN rustup component add rustfmt clippy

# 将 fnm 的 Node.js 版本目录放在所有容器用户都能访问的位置。
ENV FNM_DIR=/opt/fnm

# 创建临时构建用户，并允许其在构建期间通过 sudo 安装软件包。
RUN useradd --create-home distrobox-build \
    && printf '%s\n' 'distrobox-build ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/distrobox-build \
    && chmod 0440 /etc/sudoers.d/distrobox-build \
    && visudo -cf /etc/sudoers.d/distrobox-build

# su - 会清除环境变量，因此显式传递共享的 Rust 工具链目录。
RUN su - distrobox-build -c 'git clone https://aur.archlinux.org/paru.git && cd paru && env RUSTUP_HOME=/opt/rustup makepkg --syncdeps --install --noconfirm' \
    && rm -rf /home/distrobox-build/paru \
    && pacman -Scc --noconfirm

# 尽早安装 Fish，并将其设为镜像及新建用户的默认 shell。
RUN su - distrobox-build -c 'paru -S --noconfirm --needed fish' \
    && pacman -Scc --noconfirm

ENV SHELL=/usr/bin/fish

RUN if [ -f /etc/default/useradd ]; then \
        if grep -q '^SHELL=' /etc/default/useradd; then \
            sed -i 's|^SHELL=.*|SHELL=/usr/bin/fish|' /etc/default/useradd; \
        else \
            printf '%s\n' 'SHELL=/usr/bin/fish' >> /etc/default/useradd; \
        fi; \
    else \
        printf '%s\n' 'SHELL=/usr/bin/fish' > /etc/default/useradd; \
    fi

# 单独安装 Starship，并使用宿主机 Home 中的配置主题。
RUN su - distrobox-build -c 'paru -S --noconfirm --needed starship' \
    && pacman -Scc --noconfirm

# 单独安装 .NET SDK，便于后续构建复用其他开发环境层。
RUN su - distrobox-build -c 'paru -Syu --noconfirm --needed dotnet-sdk' \
    && pacman -Scc --noconfirm

# 单独安装 Git LFS 并配置系统级过滤器。
RUN su - distrobox-build -c 'paru -S --noconfirm --needed git-lfs' \
    && git lfs install --system \
    && pacman -Scc --noconfirm

# 单独安装 GitHub CLI。
RUN su - distrobox-build -c 'paru -S --noconfirm --needed github-cli' \
    && pacman -Scc --noconfirm

# 单独安装 Python 包和项目管理工具 uv。
RUN su - distrobox-build -c 'paru -S --noconfirm --needed uv' \
    && pacman -Scc --noconfirm

# 单独安装 fnm。
RUN su - distrobox-build -c 'paru -S --noconfirm --needed fnm' \
    && pacman -Scc --noconfirm

# 通过 LTS 代号安装并设为默认版本的最新 Node.js 26 LTS（Lithium）。
RUN fnm install lts/lithium \
    && fnm default lts/lithium

# 通过系统级 Fish 配置加载 fnm 环境，使新会话直接使用默认 Node.js。
RUN install -d /etc/fish/conf.d \
    && printf '%s\n' 'fnm env --use-on-cd --shell fish | source' > /etc/fish/conf.d/fnm.fish

# 使用 fnm 管理的 Node 全局安装 pnpm；Node 26 已不再内置 Corepack，pnpm 12 也无法由 Corepack 安装。
RUN PATH="/opt/fnm/aliases/default/bin:${PATH}" npm install --global pnpm@latest \
    && rm -rf /root/.npm

# 单独安装 Fish 别名依赖的 eza，减少新增层对前面缓存层的影响。
RUN su - distrobox-build -c 'paru -S --noconfirm --needed eza' \
    && pacman -Scc --noconfirm

# 单独安装系统信息展示工具 fastfetch。
RUN su - distrobox-build -c 'paru -S --noconfirm --needed fastfetch' \
    && pacman -Scc --noconfirm

# 单独安装压缩/解压工具 ouch。
RUN su - distrobox-build -c 'paru -S --noconfirm --needed ouch' \
    && pacman -Scc --noconfirm

# 单独安装 yazi 及全部可选依赖：搜索、预览、剪贴板和图标字体。
RUN su - distrobox-build -c 'paru -S --noconfirm --needed yazi fd ripgrep fzf zoxide ffmpeg 7zip poppler jq imagemagick resvg chafa wl-clipboard xclip xsel ttf-nerd-fonts-symbols' \
    && pacman -Scc --noconfirm

# 单独安装 dotfiles 管理工具 chezmoi。
RUN su - distrobox-build -c 'paru -S --noconfirm --needed chezmoi' \
    && pacman -Scc --noconfirm

# 单独安装轻量编辑器 nano。
RUN su - distrobox-build -c 'paru -S --noconfirm --needed nano' \
    && pacman -Scc --noconfirm

# 单独安装 Vim，并提供 vi 命令兼容入口。
RUN su - distrobox-build -c 'paru -S --noconfirm --needed vim' \
    && ln -sf /usr/bin/vim /usr/local/bin/vi \
    && pacman -Scc --noconfirm

# 单独安装 Neovim。
RUN su - distrobox-build -c 'paru -S --noconfirm --needed neovim' \
    && pacman -Scc --noconfirm

# 单独安装 ffmpeg，提供音视频解码与转码能力。
RUN su - distrobox-build -c 'paru -S --noconfirm --needed ffmpeg' \
    && pacman -Scc --noconfirm

# 单独安装 mpv，便于在容器内直接播放视频。
RUN su - distrobox-build -c 'paru -S --noconfirm --needed mpv' \
    && pacman -Scc --noconfirm

# 单独安装 bat，作为 cat 的进阶替代，提供语法高亮与分页。
RUN su - distrobox-build -c 'paru -S --noconfirm --needed bat' \
    && pacman -Scc --noconfirm

# 删除临时构建用户及其 sudo 权限。
RUN rm -f /etc/sudoers.d/distrobox-build \
    && userdel --remove distrobox-build \
    && pacman -Scc --noconfirm

# 构建结束后将官方源切换为中国大陆镜像，并保留全球 CDN 作为兜底。
# AUR 与 archlinuxcn 不受影响；可用 --build-arg ARCH_MIRROR=... 覆盖首选镜像。
ARG ARCH_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/archlinux
RUN printf '%s\n' \
        '## 中国大陆官方镜像（按顺序回退）' \
        "Server = ${ARCH_MIRROR}/\$repo/os/\$arch" \
        'Server = https://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch' \
        'Server = https://mirrors.nju.edu.cn/archlinux/$repo/os/$arch' \
        'Server = https://mirrors.aliyun.com/archlinux/$repo/os/$arch' \
        '## 全球 CDN 兜底' \
        'Server = https://fastly.mirror.pkgbuild.com/$repo/os/$arch' \
        'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch' \
        > /etc/pacman.d/mirrorlist \
    && chmod 644 /etc/pacman.d/mirrorlist
