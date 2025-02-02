# termux-archlinux
用于在termux上使用proot容器安装archlinux并且安装桌面环境的流程
# 注意事项
请检查是否已经给予termux储存权限，如果没有请输入以下命令并回车，不起作用请手动给予

    termux-setup-storage

# 首先更换termux的包源
输入命令回车后找到中国的镜像源进行更换

    termux-change-repo
    pkg update
    pkg install git -y

# 安装x11与声音组件的依赖

    pkg update -y
    pkg install x11-repo -y
    pkg install termux-x11-nightly -y
    pkg install pulseaudio -y
    
# 安装proot容器后下载archlinux并登录

    pkg install proot-distro -y
    proot-distro install archlinux
    proot-distro login archlinux

# 切换arch的镜像源（刚开始可能会很慢，请耐心等待）

    pacman -Sy
    pacman -S nano
    nano /etc/pacman.d/mirrorlist

把原来的源#掉，然后在另一行空白处加上国内源

    Server = http://mirrors.aliyun.com/archlinuxarm/$arch/$repo

Ctrl+o Ctrl+x（记得按回车键）
# 创建新用户

    pacman -S sudo
    sudo useradd -m -s /bin/bash moze

（注意，此处我是以我自己的创建用户习惯来创建的，用户名是我自己名字的字母，用户名可以随意设置，但是在后面的流程中必须保持与此处的用户名想一致，就是把所有的moze改成你自己的用户名）

    passwd moze
    nano /etc/sudoers
    moze ALL=(ALL:ALL) ALL
Ctrl+o Ctrl+x
# 验证一下用户权限

    su - moze
    whoami
    sudo whoami
如果有报错请检查之前的步骤是否遗漏或错误

# 安装桌面环境（这里安装的是xfce4）

    sudo pacman -S xfce4

# 配置中文环境(包括xfce4桌面)
查看当前语言环境是否有中文环境

    echo $LANG

没有的话进行添加

    nano /etc/locale.gen

往下拉到最底部找到#zh_CN.UTF-8 UTF-8这一行，把#去掉，如果没找到，就在底部加上

    zh_CN.UTF-8 UTF-8

 Ctrl+o Ctrl+x

生成中文环境（终端）

    locale-gen

修改中文环境（xfce4桌面）

    nano /etc/locale.conf

全部内容改成

    LANG=zh_CN.UTF-8

Ctrl+o Ctrl+x

    nano /etc/environment

在底部加上

    LANG="zh_CN.UTF-8"
    LANGUAGE="zh_CN:zh:en_US:en"

Ctrl+o Ctrl+x

在终端页面设置中文

    export LANG=zh_CN.UTF-8

在bash.bashrc中加入变量，修改为一进入终端就是中文环境

    nano /etc/bash.bashrc

在底部加上

    export LANG=zh_CN.UTF-8

Ctrl+o Ctrl+x

输入date检查是否已经改成了中文环境

输入以下命令更正时区与时间

    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

再次输入date检查时间

安装中文字体包

    sudo pacman -S wqy-zenhei wqy-microhei noto-fonts-cjk

# 配置桌面启动命令
在termux中输入以下命令添加软连接方便访问usr

    ln -s /data/user/0/com.termux/files/usr/ /data/user/0/com.termux/files/home/usr
进入指定目录

    cd usr/bin

创建启动脚本

    nano startx11

把这段脚本粘贴进去（脚本中也有对应用户名，请注意更改）

    #!/data/data/com.termux/files/usr/bin/bash



    # Kill open X11 processes

    kill -9 $(pgrep -f "termux.x11") 2>/dev/null



    # Enable PulseAudio over Network

    pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1



    # Prepare termux-x11 session

    export XDG_RUNTIME_DIR=${TMPDIR}

    termux-x11 :0 >/dev/null &



    # Wait a bit until termux-x11 gets started.

    sleep 3



    # Launch Termux X11 main activity

    am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity > /dev/null 2>&1

    sleep 1



    # Login in PRoot Environment. Do some initialization for PulseAudio, /tmp directory

    # and run KDE as user droidmaster.

    # See also: https://github.com/termux/proot-distro

    # Argument -- acts as terminator of proot-distro login options processing.

    # All arguments behind it would not be treated as options of PRoot Distro.

    proot-distro login archlinux --shared-tmp -- /bin/bash -c 'export PULSE_SERVER=127.0.0.1 && export XDG_RUNTIME_DIR=${TMPDIR} && su - moze -c "DISPLAY=:0 dbus-launch startxfce4"'



    exit 0

Ctrl+o Ctrl+x
# 给予权限

    chmod +x startx11

启动xfce4桌面环境的命令为startx11
