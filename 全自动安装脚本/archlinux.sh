#!/data/data/com.termux/files/usr/bin/bash
set -e

# 配置颜色输出
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
RESET='\033[0m'

# 函数：输入验证
validate_username() {
  if [[ ! "$1" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
    echo -e "${RED}错误：用户名不符合Linux命名规则！${RESET}"
    echo -e "要求："
    echo "- 只能包含小写字母、数字、连字符(-)和下划线(_)"
    echo "- 首字符必须是小写字母或下划线"
    echo "- 长度1-32字符"
    return 1
  fi
  return 0
}

validate_password() {
  if [ -z "$1" ]; then
    echo -e "${RED}错误：密码不能为空！${RESET}"
    return 1
  fi
  return 0
}

# 用户输入部分
echo -e "${GREEN}>>> 用户配置 ${RESET}"
while : 
do
  read -p "请输入Arch容器用户名（默认archuser）: " ARCH_USER
  ARCH_USER=${ARCH_USER:-archuser}
  validate_username "$ARCH_USER" && break
done

while :
do
  read -sp "请输入用户密码: " ARCH_PASS
  echo
  read -sp "请再次确认密码: " ARCH_PASS_CONFIRM
  echo
  if [ "$ARCH_PASS" != "$ARCH_PASS_CONFIRM" ]; then
    echo -e "${RED}两次输入的密码不一致！${RESET}"
  else
    validate_password "$ARCH_PASS" && break
  fi
done

# 配置Termux镜像源
TERMUX_REPO_URL="https://mirrors.tuna.tsinghua.edu.cn/termux/termux-packages-24"

# 函数：显示进度信息
status() { echo -e "${BLUE}[*] $1${RESET}"; }
success() { echo -e "${GREEN}[√] $1${RESET}"; }
error() { echo -e "${RED}[X] $1${RESET}" >&2; exit 1; }

# 检查Termux环境
if [ ! -d "/data/data/com.termux/files/usr" ]; then
  error "必须在 Termux 环境中运行！"
fi

# 阶段1: Termux基础配置
status "正在配置Termux环境..."
{
  sed -i 's@^$deb.*stable main$$@#\1\ndeb '"${TERMUX_REPO_URL}"' stable main@' $PREFIX/etc/apt/sources.list
  pkg update -y && pkg upgrade -y
  pkg install x11-repo -y
  pkg install termux-x11-nightly -y
  pkg install pulseaudio -y
  pkg install proot-distro -y
} || error "Termux基础配置失败"

# 阶段2: 安装Arch容器
status "正在安装Arch Linux容器..."
{
  proot-distro install archlinux

  # 配置镜像源
  echo -e "${YELLOW}配置镜像源...${RESET}"
  proot-distro login archlinux -- /bin/bash -c "cat > /etc/pacman.d/mirrorlist <<'ARCH_MIRROR'
Server = http://mirrors.aliyun.com/archlinuxarm/\$arch/\$repo
ARCH_MIRROR"

  # 更新软件包索引并安装 nano
  proot-distro login archlinux -- /bin/bash -c "pacman -Sy --noconfirm && pacman -S --noconfirm nano"
} || error "Arch Linux安装失败"

# 阶段3: 容器配置
status "正在配置Arch Linux容器..."
proot-distro login archlinux -- /bin/bash <<EOF
set -e

# 创建用户
echo -e "${YELLOW}创建用户 $ARCH_USER...${RESET}"
pacman -S --noconfirm sudo
useradd -m -G wheel -s /bin/bash $ARCH_USER
echo "$ARCH_USER:$ARCH_PASS" | chpasswd

# 配置sudo权限
echo -e "${YELLOW}配置sudo权限...${RESET}"
sed -i '/^# %wheel ALL=(ALL:ALL) ALL$/s/^# //' /etc/sudoers

# 安装桌面环境
echo -e "${YELLOW}安装Xfce4...${RESET}"
pacman -Sy --noconfirm && pacman -S --noconfirm xfce4

# 中文环境配置
echo -e "${YELLOW}配置中文环境...${RESET}"
sed -i 's/#zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=zh_CN.UTF-8' > /etc/locale.conf
echo 'LANG="zh_CN.UTF-8"' >> /etc/environment
echo 'LANGUAGE="zh_CN:zh:en_US:en"' >> /etc/environment

# 时区配置
echo -e "${YELLOW}配置时区...${RESET}"
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# 安装中文字体
echo -e "${YELLOW}安装中文字体...${RESET}"
pacman -S --noconfirm wqy-zenhei wqy-microhei noto-fonts-cjk
EOF

# 阶段4: 创建启动脚本
status "创建启动脚本..."
cat > $PREFIX/bin/startxfce <<EOF
#!/data/data/com.termux/files/usr/bin/bash

# 清理已有进程
kill -9 \$(pgrep -f "termux.x11") 2>/dev/null

# 启动音频服务
pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1

# 准备X11环境
export XDG_RUNTIME_DIR=\${TMPDIR}
termux-x11 :0 >/dev/null &

# 等待X11启动
sleep 3

# 启动X11应用
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity > /dev/null 2>&1
sleep 1

# 进入容器启动桌面
proot-distro login archlinux --shared-tmp -- /bin/bash -c \\
  'export PULSE_SERVER=127.0.0.1 && \\
   export XDG_RUNTIME_DIR=\${TMPDIR} && \\
   su - $ARCH_USER -c "DISPLAY=:0 dbus-launch startxfce4"'
EOF

chmod +x $PREFIX/bin/startxfce

# 最终输出
success "安装完成！"
echo -e "${GREEN}使用以下命令启动桌面："
echo -e "startxfce${RESET}"

# 作者留言
echo -e "\n${YELLOW}==================================================="
echo -e "感谢使用本安装脚本！"
echo -e "脚本作者：纆泽"
echo -e "B站UID:321858860"
echo -e "QQ：834080913"
echo -e "模拟器交流群：962180826"
echo -e "我的github发布页"
echo -e "https://github.com/moze30?tab=repositories"
echo -e "===================================================${RESET}\n"
