# Mini PC NixOS 配置

用于单块 NVMe SSD、UEFI 启动的 x86_64 Mini PC。当前只包含稳定版 NixOS 26.05、Disko、NetworkManager、SSH、zram 和通用 CLI。项目语言环境以后用各项目的 `nix develop` 管理。

## 安装前必须完成

> [!WARNING]
> **执行 Disko / nixos-anywhere 前，必须在 Mini PC 的安装器中运行 `lsblk`，确认真实目标磁盘。Disko 会清除目标磁盘全部数据。** `hosts/minipc/disko.nix` 中的 `device = "/dev/nvme0n1";` 只是暂定值。核对容量、型号及设备路径；如果有稳定的 `/dev/disk/by-id/...` 路径，优先改用它。不要照抄示例设备名直接安装。

1. 在 `flake.nix` 的 `username` 设置开发用户名称（当前为 `yulinye`）。
2. `modules/ssh.nix` 已填入本机 `~/.ssh/id_ed25519.pub`，指纹为 `SHA256:pgGrErFjUqFEfnN4RcAeXSPVdxX66rXVcTUfxNgEMpA`。安装前确认 Mac 登录时使用的正是这把私钥；若换钥匙，先更新 `openssh.authorizedKeys.keys`。**公钥列表为空或私钥不匹配时绝对不要安装或重启到新系统**：目标系统禁用 root 登录、密码 SSH 和键盘交互 SSH，届时无法远程登录。
3. 确认 Mini PC 是 UEFI 启动且目标 SSD 可以完整清除。`/boot` 是 1 GiB FAT32 ESP；其余是 Btrfs 的 `@root`、`@nix`、`@home`、`@persist`。没有磁盘 swap；启用 zram。
4. 在 Mac 上准备可运行的 Nix，且 `nix flake` 可用。本仓库不安装或修改 Mac 的 Nix。先用 `git add` 跟踪新文件，再执行 `nix flake lock` 生成并提交 `flake.lock`，最后执行 `nix flake check`。如果首次运行提示实验特性未启用，可对单条命令加 `--extra-experimental-features 'nix-command flakes'`。

`hosts/minipc/hardware-configuration.nix` 在首次安装前**不存在**。`hosts/minipc/default.nix` 仅在该文件存在时导入它；首装使用通用 NVMe/USB/SATA initrd 模块及 Disko 生成的文件系统配置。安装后再生成真实硬件配置，过程见下文。`system.stateVersion = "26.05"` 是首装状态版本，以后升级 NixOS 时不要随手改动。

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
sudo nixos-generate-config --no-filesystems --root /
sudo cp /etc/nixos/hardware-configuration.nix hosts/minipc/hardware-configuration.nix
sudo chown "$USER" hosts/minipc/hardware-configuration.nix
git add hosts/minipc/hardware-configuration.nix
nix flake check
```

检查生成文件中没有重复定义 Disko 管理的 `/`、`/boot` 等 `fileSystems` 或 `swapDevices`；`--no-filesystems` 正是为此使用。确认模块、驱动和固件配置后提交它。也可把生成的文件传回 Mac 仓库，审阅并提交后再部署。未来修改配置：

```bash
cd ~/nixos-config
git pull
sudo nixos-rebuild switch --flake .#minipc
```

`sudo` 执行 flake 构建时需确保工作副本中的变更已经 `git add`，且 `flake.lock` 已存在。新的配置会生成新的 systemd-boot 启动项。若一次 `switch` 出问题，可在本地控制台运行 `sudo nixos-rebuild --rollback switch` 回到上一代；若无法正常启动，在 systemd-boot 菜单选择之前的 NixOS generation，再修复配置。

## 配置边界与资料

第一阶段未启用 Docker、Dokploy 或 Tailscale，也没有安装项目级编译器和语言运行时。`/persist` 只是普通 Btrfs 子卷，不启用 impermanence。

- [NixOS 26.05 官方手册](https://nixos.org/manual/nixos/stable/)
- [Disko 官方 Btrfs 子卷示例](https://github.com/nix-community/disko/blob/master/example/btrfs-subvolumes.nix)
- [nixos-anywhere Quickstart](https://github.com/nix-community/nixos-anywhere/blob/main/docs/quickstart.md)
- [nixos-anywhere：从 NixOS 安装介质安装](https://nix-community.github.io/nixos-anywhere/howtos/no-os.html)
- [中科大 Nix 二进制缓存镜像说明](https://mirrors.ustc.edu.cn/help/nix-channels.html)
- [nixos-anywhere CLI 选项](https://github.com/nix-community/nixos-anywhere/blob/main/docs/cli.md)
