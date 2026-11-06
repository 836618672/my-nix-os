# Mini PC NixOS 配置

用于单块 NVMe SSD、UEFI 启动的 x86_64 Mini PC。当前包含稳定版 NixOS 26.05、Disko、NetworkManager、SSH、zram、DDNS-Go、Mihomo/ClashTUI 和通用 CLI。项目语言环境以后用各项目的 `nix develop` 管理。

## 安装前必须完成

> [!WARNING]
> **执行 Disko / nixos-anywhere 前，必须在 Mini PC 的安装器中运行 `lsblk`，确认真实目标磁盘。Disko 会清除目标磁盘全部数据。** `hosts/minipc/disko.nix` 中的 `device = "/dev/nvme0n1";` 只是暂定值。核对容量、型号及设备路径；如果有稳定的 `/dev/disk/by-id/...` 路径，优先改用它。不要照抄示例设备名直接安装。

1. 在 `flake.nix` 的 `username` 设置开发用户名称（当前为 `yulinye`）。
2. `modules/ssh.nix` 已填入本机 `~/.ssh/id_ed25519.pub`，指纹为 `SHA256:pgGrErFjUqFEfnN4RcAeXSPVdxX66rXVcTUfxNgEMpA`。安装前确认 Mac 登录时使用的正是这把私钥；若换钥匙，先更新 `openssh.authorizedKeys.keys`。**公钥列表为空或私钥不匹配时绝对不要安装或重启到新系统**：目标系统禁用 root 登录、密码 SSH 和键盘交互 SSH，届时无法远程登录。
3. 确认 Mini PC 是 UEFI 启动且目标 SSD 可以完整清除。`/boot` 是 1 GiB FAT32 ESP；其余是 Btrfs 的 `@root`、`@nix`、`@home`、`@persist`。没有磁盘 swap；启用 zram。
4. 在 Mac 上准备可运行的 Nix，且 `nix flake` 可用。本仓库不安装或修改 Mac 的 Nix。先用 `git add` 跟踪新文件，再执行 `nix flake lock` 生成并提交 `flake.lock`，最后执行 `nix flake check`。如果首次运行提示实验特性未启用，可对单条命令加 `--extra-experimental-features 'nix-command flakes'`。

`hosts/minipc/hardware-configuration.nix` 已包含当前 Mini PC 的硬件配置。`hosts/minipc/default.nix` 仅在该文件存在时导入它；若安装到另一台机器，应先移除旧硬件配置，首装使用通用 NVMe/USB/SATA initrd 模块及 Disko 生成的文件系统配置。安装后重新生成对应机器的硬件配置，过程见下文。`system.stateVersion = "26.05"` 是首装状态版本，以后升级 NixOS 时不要随手改动。

## 1. 在 Mini PC 的 NixOS Minimal ISO 中准备网络和 SSH

在 Mini PC 本地屏幕与键盘操作。Minimal ISO 通常有 `nmtui`；运行 `sudo nmtui`，进入 **Activate a connection** 选择 Wi-Fi、输入密码。这个密码只留在安装器运行环境，不写入仓库。检查联网并查看地址：

```bash
ip -br addr
```

安装器的 `nixos` 用户已具备临时免密码 sudo。**在 Mini PC 本地键盘**为这个安装器用户设置临时密码，并确认 SSH 服务运行：

```bash
sudo passwd nixos
sudo systemctl start sshd
```

这是安装器的临时密码，不会写入仓库，也不会成为新系统 `yulinye` 的密码。从 Mac 确认能登录，并验证安装器用户可使用免密码 sudo：

```bash
ssh nixos@<INSTALLER_IP>
ssh nixos@<INSTALLER_IP> 'sudo -n true'
```

首次 SSH 连接会提示核对安装器的主机指纹。第二条命令返回成功即可；不要把安装器的 `nixos` 用户和新系统的 `yulinye` 用户混淆。Mini PC 安装完成后，新系统仍按 `modules/ssh.nix` 只允许普通用户使用配置好的公钥登录。

若 ISO 无法使用 `nmtui`，先确认安装介质版本与无线网卡支持；必要时用有线网络完成安装。不要在 Wi-Fi 未稳定连接时启动远程安装。

## 2. 在安装器中核对磁盘

**只读取信息，先不要分区或格式化。** 在 Mini PC 安装器本地运行：

```bash
lsblk -o NAME,PATH,SIZE,MODEL,TRAN,TYPE,MOUNTPOINTS
ls -l /dev/disk/by-id/
```

将唯一目标 SSD 的路径与容量、型号逐项核对，再修改 `hosts/minipc/disko.nix` 中唯一的 `device` 值。确保路径指向**整块磁盘**，不是分区，也不是安装 U 盘。若路径与预期不符，停止安装。

## 3. 在 Mac 上锁定并验证配置

在本仓库根目录执行：

```bash
git add README.md flake.nix hosts modules
nix flake lock
git add flake.lock
nix flake check
```

建议将 `flake.nix`、`flake.lock`、所有模块及公钥配置提交到 Git，再运行安装；Nix 对 Git flake 只会包含 Git 已跟踪的文件。提交前再检查一次 `username`、SSH 公钥及 `device`。可选的 `--vm-test` 会在 VM 的虚拟磁盘中运行 Disko，但只应在具备安全虚拟化环境时使用；本安装流程不依赖它。

## 4. 从 Mac 运行 nixos-anywhere

Mini PC 已经运行 Minimal ISO，并通过 Wi-Fi 连网。**以下命令只在 Mac 的本仓库根目录运行，不在 Mini PC 安装器里运行**；`--flake .#minipc` 中的 `.` 指 Mac 上的当前仓库。nixos-anywhere 能识别 NixOS 安装器并跳过 kexec；这里显式运行 `disko,install` 两个阶段，保留安装器会话，以便复制 Wi-Fi 连接和设置新系统的本地用户密码：

```bash
nix --extra-experimental-features 'nix-command flakes' run github:nix-community/nixos-anywhere -- \
  --option substituters 'https://mirrors.ustc.edu.cn/nix-channels/store?priority=10 https://cache.nixos.org/' \
  --phases disko,install \
  --flake .#minipc \
  --target-host nixos@<INSTALLER_IP>
```

**运行此命令将按 `hosts/minipc/disko.nix` 清除目标磁盘并安装 NixOS。** 仅在前述磁盘、用户名和公钥检查都完成后执行。Mac 若无法本地构建 Linux 配置，nixos-anywhere 的默认 `--build-on auto` 会选择合适的构建位置；安装器必须保持联网。若安装工具报告能力或资源不足，先排查，不要反复运行 Disko。

`--option substituters` 让这次安装中的 Nix 命令优先尝试中科大二进制缓存，并保留官方缓存作为后备。新系统启动后的相同设置在 `modules/base.nix`。如果安装命令已经在运行，修改仓库不会改变那个进程的下载源；**不要在不清楚 Disko 是否执行的情况下直接重跑 `disko,install`**。

安装完成后先不要重启。若想让新系统首次启动时自动连接安装器当前使用的 Wi-Fi，可在 **Mini PC 安装器本地**把对应的 NetworkManager 连接文件复制进已安装系统。先确认 `/mnt` 仍是新系统的挂载点，然后找出当前连接及其文件：

```bash
findmnt /mnt
nmcli -f NAME,TYPE,DEVICE connection show --active
sudo ls -l /etc/NetworkManager/system-connections/ /run/NetworkManager/system-connections/
sudo grep -H '^id=' /etc/NetworkManager/system-connections/*.nmconnection /run/NetworkManager/system-connections/*.nmconnection 2>/dev/null
```

选择当前 Wi-Fi 对应的 `.nmconnection` 文件。下面的 `<SOURCE_PROFILE>` 必须替换成找到的**完整文件路径**，通常在 `/etc/NetworkManager/system-connections/`，也可能在 `/run/NetworkManager/system-connections/`；`<PROFILE_FILE>` 是它的文件名。只复制这个连接，不要把 Wi-Fi 密码或连接文件放进 Git：

```bash
sudo install -d -m 700 /mnt/etc/NetworkManager/system-connections
sudo install -o root -g root -m 600 \
  '<SOURCE_PROFILE>' \
  '/mnt/etc/NetworkManager/system-connections/<PROFILE_FILE>'
```

用 `nmcli -g connection.autoconnect connection show '<当前连接名>'` 确认结果为 `yes`。普通 WPA/WPA2 家用网络可用 `sudo grep -q '^psk=' '<SOURCE_PROFILE>' && echo 'PSK saved'` 检查密码是否已保存在文件中；该命令不会打印密码。NetworkManager 要求包含密码的连接文件只能由 root 读写，否则会忽略它。若找不到文件或无法确认密码是否已保存，保留下面的控制台登录与 `nmtui` 步骤作为恢复路径。

在仍运行的安装器里，为新系统的普通用户设置**本地控制台密码**，供首次启动后配置 Wi-Fi 和 `sudo` 使用：

```bash
sudo nixos-enter --root /mnt -c 'passwd yulinye'
```

若修改过 `username`，把 `yulinye` 换成实际用户名。`passwd` 的输入不会写进 Git。确认密码设置成功后，在 Mini PC 本地重启：

```bash
sudo reboot
```

## 5. 首次启动、Wi-Fi 和 SSH

安装器中临时建立的 Wi-Fi 连接**默认不会自动成为新系统的 NetworkManager 连接**。若已按上一步复制连接文件，新系统应尝试自动连接；先从 Mac 验证能否 SSH 登录。若未自动连接，在 Mini PC 本地控制台以刚设置的普通用户和密码登录，执行：

```bash
sudo nmtui
ip -br addr
```

在 `nmtui` 中重新连接 Wi-Fi。该连接保存于新系统的 NetworkManager，不进入 Git。记下新 IP，然后在 Mac 上登录：

```bash
ssh yulinye@<NEW_IP>
```

用户名要按 `flake.nix` 中的实际值替换。系统重装后 SSH host key 会变化；核对 IP 确实是 Mini PC 后，再按 SSH 提示处理旧 host key。只要公钥正确，SSH 无需用户密码；`sudo` 仍会询问本地用户密码。

## 6. 生成真实硬件配置与后续更新

第一次登录新系统后，在本仓库的工作副本中生成硬件配置。先在 Mini PC 上获取本仓库（例如 `git clone <你的仓库地址> ~/nixos-config`），然后：

```bash
cd ~/nixos-config
sudo nixos-generate-config --no-filesystems --show-hardware-config > hosts/minipc/hardware-configuration.nix
test -s hosts/minipc/hardware-configuration.nix
git add hosts/minipc/hardware-configuration.nix
nix flake check
```

`--show-hardware-config` 直接将检测结果输出到当前仓库；不要在已运行的系统上使用 `--root /`，生成器会报错且不会写文件。检查生成文件中没有重复定义 Disko 管理的 `/`、`/boot` 等 `fileSystems` 或 `swapDevices`；`--no-filesystems` 正是为此使用。确认模块、驱动和固件配置后提交它。也可把生成的文件传回 Mac 仓库，审阅并提交后再部署。未来修改配置：

```bash
cd ~/nixos-config
git pull
sudo nixos-rebuild switch --flake .#minipc
```

`sudo` 执行 flake 构建时需确保工作副本中的变更已经 `git add`，且 `flake.lock` 已存在。新的配置会生成新的 systemd-boot 启动项。若一次 `switch` 出问题，可在本地控制台运行 `sudo nixos-rebuild --rollback switch` 回到上一代；若无法正常启动，在 systemd-boot 菜单选择之前的 NixOS generation，再修复配置。

## 7. 配置 DDNS-Go

`modules/ddns-go.nix` 通过 systemd 启动 nixpkgs 中的 `ddns-go`，开机自动运行。Web 管理页面仅监听 Mini PC 的 `127.0.0.1:9876`，无需开放防火墙端口。DNS 平台令牌、域名和 DDNS-Go 的登录信息通过页面配置，保存在 Mini PC 的 `/var/lib/ddns-go/config.yaml`；不要将该文件或令牌加入 Git。

本次提交推送到远端后，在 **Mini PC** 的仓库中运行：

```bash
cd ~/nixos-config
git pull --ff-only
nix flake check
sudo nixos-rebuild switch --flake .#minipc
systemctl status ddns-go --no-pager
```

`hardware-configuration.nix` 已在仓库中。若 Mini PC 的工作副本还有未提交改动，先审阅并处理，再执行 `git pull --ff-only`。

在 **Mac** 的另一个终端建立 SSH 隧道（保持终端运行）：

```bash
ssh -N -L 9876:127.0.0.1:9876 yulinye@<MINIPC_IP>
```

然后在 Mac 浏览器打开 `http://127.0.0.1:9876`，设置 DDNS-Go 登录账号、DNS 平台和要更新的域名。若修改过 `username`，同步修改 SSH 用户名；若 Mac 的 9876 端口被占用，可将命令中第一个 `9876` 改为其他空闲端口，并在浏览器打开对应端口。服务日志用 `journalctl -u ddns-go -e --no-pager` 查看。选择公网 IP 获取方式时，留意家庭网络是否处于运营商 NAT 下：DDNS 只能更新 DNS 记录，不能替代公网地址或端口转发。

## 8. 安装和更新 Codex CLI

Codex CLI 由社区维护的 [codex-cli-nix](https://github.com/sadjow/codex-cli-nix) flake 提供，无需全局 Node/npm。`flake.lock` 固定输入版本，Nix 通过系统 generations 管理升级和回滚。Codex 登录凭据保存在用户主目录，不写入 Git。

安装或应用已有配置：

```bash
cd ~/nixos-config
sudo nixos-rebuild switch --flake .#minipc
codex --version
codex login --device-auth
```

SSH 服务器上使用 `--device-auth`，按终端提示在 Mac 浏览器完成登录。不要用 `sudo codex`：普通用户的登录状态和项目文件都属于该用户。

更新 Codex 时，更新该 flake 的锁定版本并重建：

```bash
cd ~/nixos-config
nix flake update codex-cli-nix
sudo nixos-rebuild switch --flake .#minipc
codex --version
```

更新后可将 `flake.lock` 的变化提交到 Git，以便在其他机器上复现。

OpenCode 2 CLI 由社区维护的 [llm-agents.nix](https://github.com/numtide/llm-agents.nix) 提供。运行 `opencode`（或 `opencode2`）启动；使用以下命令更新：

```bash
cd ~/nixos-config
nix flake update llm-agents
sudo nixos-rebuild switch --flake .#minipc
opencode --version
```

## 9. Mihomo 与 ClashTUI：订阅节点和规则自动更新

使用 Nixpkgs 已收录的 `mihomo`、`clashtui` 和 `metacubexd`，由 `modules/mihomo.nix` 配置。订阅下载、配置合并、当前订阅重载使用 **ClashTUI 的现成命令**；NixOS 的 systemd timer 每 6 小时调用一次。无需安装其他发行版的安装脚本、Docker 或桌面环境。

当前锁定的 ClashTUI 是 **0.2.3**，以下操作按该版本的[官方说明](https://github.com/JohanChane/clashtui/blob/v0.2.3/README_ZH.md)和源码核对。新版本文档里的 `profile update --all` 不适用于此版本；这里使用 `clashtui -u`。

### 启用与导入完整 YAML 订阅

代码同步到 Mini PC 后，在 Mini PC 的仓库运行：

```bash
git pull --ff-only
nix flake check
sudo nixos-rebuild switch --flake .#minipc
```

重新建立 SSH 登录，使新增的 `mihomo` 组权限生效，然后运行：

```bash
clashtui
```

在 **Profile** 页按 `i`，填写订阅名称和订阅商的完整 Clash/Mihomo YAML URL；按 `a` 下载订阅及其依赖资源，再按 `Enter` 选择它。按 `?` 查看当前页快捷键，完成后退出。初始配置只有 `MATCH,DIRECT`，导入并选中订阅后才会使用代理节点。

订阅 URL 只在 Mini PC 的界面中输入，保存到 `~/.config/clashtui/`；下载缓存也在该目录。最终运行配置在 `/var/lib/mihomo/config.yaml`。**这些目录可能包含订阅令牌和节点密码，不要放进仓库，也不要贴出其完整内容或完整日志。** 配置目录只对当前用户开放，核心配置目录只对 `mihomo` 用户及组开放。

ClashTUI 0.2.3 会从完整 YAML 同步 `proxies`、`proxy-groups`、`proxy-providers`、`rules`、`rule-providers`、`sub-rules`。端口、DNS、TUN 等基础字段由本地的 `~/.config/clashtui/basic_clash_config.yaml` 保留，**不会逐字段照搬订阅商整个 YAML**。当前默认模板启用 TUN，NixOS 服务通过 `tunMode = true` 授予网络管理能力；DNS 服务仍禁用，使用系统 DNS。mixed 代理监听 `127.0.0.1:7890`，控制 API 监听 `127.0.0.1:9090`。

模板设置 `device: Meta`、`auto-route: true` 和 `auto-detect-interface: true`，自动将流量路由到 TUN，并自动选择网络出口；进入 Mihomo 后仍按规则决定直连或使用代理节点。模板未启用 `auto-redirect` 或 DNS 劫持，选项说明见 [Mihomo TUN 文档](https://wiki.metacubex.one/config/inbound/tun/)。防火墙信任名为 `Meta` 的接口，并使用宽松反向路径检查；若在本地配置中指定其他 TUN 设备名，应同步调整 `trustedInterfaces`。现有文件不会随重建被模板覆盖，应以本地配置和实际路由为准；已有安装需要在 `~/.config/clashtui/basic_clash_config.yaml` 中设置上述字段，再在 ClashTUI 中重新选择当前 Profile。

如果订阅依赖其特定的 DNS、嗅探或其他基础字段，需要审阅后补入本地 `basic_clash_config.yaml`，重新打开 ClashTUI 并选择该 Profile。若含有 `PROCESS-NAME` 等进程规则，当前未授权额外的进程读取能力，需要另行调整。订阅包含外部 `rule-providers` 时，其规则集内容更新按订阅 YAML 中的 `interval` 由 Mihomo 执行；定时更新订阅会更新内联规则及规则集定义。首次导入时按 `a` 会同时下载规则资源。

### 自动更新与检查

每 6 小时运行一次 `clashtui -c ~/.config/clashtui -u`，开机时补执行错过的任务。该命令更新订阅并重载当前选中的 Profile；无需每次重新构建 NixOS。检查计划和手动更新：

```bash
systemctl list-timers mihomo-subscription-update.timer
clashtui -u
journalctl -u mihomo-subscription-update -n 50 --no-pager
systemctl status mihomo --no-pager
```

ClashTUI 0.2.3 的更新命令即使部分订阅失败，也可能返回退出码 0；应同时检查输出是否有 `Err` / `Not updated`，不能只凭定时任务显示成功判断。此版本不保证配置更新的原子替换或自动备份；首次成功导入后，建议在 Mini PC 上为 `/var/lib/mihomo/config.yaml` 和 `~/.config/clashtui/` 留一份受权限保护的本地备份。不要在手动操作 ClashTUI 时同时启动更新任务。

默认文件只在不存在时复制；`nixos-rebuild` 保留已导入的订阅和本地设置。以后修改模块中的默认模板不会覆盖现有文件；修改用户的本地基础配置后重新选择订阅即可生效。升级核心和 ClashTUI 则通过更新 Flake 的 Nixpkgs 锁定版本并重新构建系统。

### 管理节点与让下载走代理

在 Mac 建立隧道：

```bash
ssh -N -L 9090:127.0.0.1:9090 yulinye@yback.v6.rocks
```

浏览器打开 `http://127.0.0.1:9090/ui/`，在 MetaCubeXD 中连接 `http://127.0.0.1:9090`，即可选择节点和查看规则。当前控制 API 密钥为空，因其只监听本机；Mini PC 上的其他本地进程也可访问。若以后改成对外监听，先设置密钥和访问控制。

在 Mini PC 测试代理并让当前终端的 Git/curl 等工具使用它：

```bash
curl -I --proxy http://127.0.0.1:7890 --connect-timeout 15 https://github.com
export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
export no_proxy=localhost,127.0.0.1,::1
```

上述环境变量作用于支持 HTTP 代理的进程；系统路由是否变化取决于实际 TUN 配置。Git 的 HTTPS 地址可使用这些代理变量；`git@github.com:...` 的 SSH 地址不会自动使用 HTTP 代理。

**Nix 下载由系统 `nix-daemon` 执行，不能只依靠终端里的 `export`。** 完成订阅导入、确认代理可用后，可在 `modules/mihomo.nix` 的模块属性集中添加以下声明，再执行 `sudo nixos-rebuild switch --flake .#minipc`：

```nix
systemd.services.nix-daemon.environment = {
  http_proxy = "http://127.0.0.1:7890";
  https_proxy = "http://127.0.0.1:7890";
  no_proxy = "localhost,127.0.0.1,::1";
};
```

该设置也用于 Nix 固定输出下载（例如 Codex 发布文件）。首次安装代理工具本身仍需要直连或已经可用的代理；若现有重建仍卡在 Codex 下载，可以先把 `modules/development.nix` 中追加 Codex 包的部分暂时去掉，应用代理配置，再恢复 Codex 包并重建。不要重跑 Disko 或 nixos-anywhere。代理不可用时先移除上述 daemon 环境配置并重建；普通终端可用 `unset http_proxy https_proxy no_proxy` 恢复。

## 10. Dokploy：部署本机应用

DDNS-Go 已验证，域名为 `yback.v6.rocks`。Dokploy 管理 Docker 应用、数据库和部署；NixOS 的网络、SSH、DDNS 和 Mihomo 仍由本仓库管理。

`modules/dokploy.nix` 启用 Docker，开放 TCP 80/443 和 UDP 443。3000 不开放给物理网络：Docker 的 `DOCKER-USER` 规则拦截来自当前 Wi-Fi 接口 `wlp3s0` 的面板访问，首次初始化通过 SSH 隧道完成。若更换网络接口，应同步调整该规则。单机部署不需要对公网开放 Swarm 的 2377、7946 和 4789 端口。

在 **Mini PC 本机终端**执行（sudo 需要本地用户密码）：

```bash
cd ~/nixos-config
git add modules/dokploy.nix scripts/dokploy-install.sh
nix flake check
sudo nixos-rebuild switch --flake .#minipc
sudo docker info
sudo env ADVERTISE_ADDR=192.168.2.106 bash scripts/dokploy-install.sh
sudo docker service ls
sudo docker ps
```

`192.168.2.106` 是安装准备时本机的 Wi-Fi 地址；执行前用 `ip -br addr` 核实，并在路由器设置 DHCP 地址保留。Swarm 通告地址使用实际局域网地址，不使用 DDNS 域名或代理出口地址。

安装脚本基于已审阅的 [Dokploy 官方安装脚本](https://dokploy.com/install.sh)，由 NixOS 提供 Docker，不运行其他发行版的 Docker 安装器；已有 Swarm 时拒绝安装，不强制退出 Swarm，不删除现有网络。此脚本是一次性安装入口，不要配置为开机任务。它检测最新稳定 Dokploy 镜像版本，数据库及认证秘密保存为 Docker Secrets。若中途失败，先查看 `sudo docker service ls` 和 `sudo docker service logs --tail 50 dokploy`，不要重新安装或清除数据。

在 **Mac** 建立隧道：

```bash
ssh -N -L 3000:127.0.0.1:3000 yulinye@yback.v6.rocks
```

浏览器打开 `http://localhost:3000`，创建管理员。然后在 Settings → Server 的 Web Server 设置中，将 Host 设为 `yback.v6.rocks`，启用 HTTPS 并选择 Let's Encrypt，填写自己的证书联系邮箱。配置方法见 [Dokploy 官方说明](https://docs.dokploy.com/docs/core/guides/cloudflare-tunnels)中的 Web Server 设置和 [Settings API](https://docs.dokploy.com/docs/api/settings)。

HTTPS 前必须确认域名对应的公网地址可以从外网访问本机 80/443：IPv4 NAT 需要路由器端口转发，IPv6 需要路由器入站防火墙放行；DDNS 成功只说明 DNS 更新正常。若仅有 AAAA 记录，访问端也需要 IPv6。初始化后从 Mac 打开 `https://yback.v6.rocks` 验证证书和登录；无需转发 3000。

数据位于 `/etc/dokploy` 及 `/var/lib/docker`（数据库、Docker volumes 和 Swarm 状态），不会进入 Git，也不会因 NixOS generation 回滚而回滚。应用上线前为 Dokploy 数据库和应用卷配置备份。日常通过面板管理应用，Docker 和系统配置变更通过 NixOS 重建。

## 配置边界与资料

已加入 Docker 配置和 Dokploy 安装流程；尚未启用 Tailscale，也没有安装项目级编译器和语言运行时。`/persist` 只是普通 Btrfs 子卷，不启用 impermanence。

- [NixOS 26.05 官方手册](https://nixos.org/manual/nixos/stable/)
- [Disko 官方 Btrfs 子卷示例](https://github.com/nix-community/disko/blob/master/example/btrfs-subvolumes.nix)
- [nixos-anywhere Quickstart](https://github.com/nix-community/nixos-anywhere/blob/main/docs/quickstart.md)
- [nixos-anywhere：从 NixOS 安装介质安装](https://nix-community.github.io/nixos-anywhere/howtos/no-os.html)
- [中科大 Nix 二进制缓存镜像说明](https://mirrors.ustc.edu.cn/help/nix-channels.html)
- [nixos-anywhere CLI 选项](https://github.com/nix-community/nixos-anywhere/blob/main/docs/cli.md)
- [DDNS-Go 官方说明](https://github.com/jeessy2/ddns-go/blob/master/README.md)
- [Codex CLI 官方说明](https://github.com/openai/codex/blob/main/README.md)
- [ClashTUI 0.2.3 官方说明](https://github.com/JohanChane/clashtui/blob/v0.2.3/README_ZH.md)
- [Mihomo 配置说明](https://wiki.metacubex.one/config/)
