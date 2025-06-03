#!/bin/bash

# fcitx5-hangul-universal-setup.sh
# 다양한 리눅스 배포판에서 Fcitx5와 Hangul 입력기를 설치하고 설정하는 스크립트입니다.

set -e

echo "🔧 Fcitx5 + Hangul 설치를 시작합니다..."

# 1. 배포판 정보 감지
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_ID=${ID,,}
    DISTRO_LIKE=${ID_LIKE,,}
else
    echo "❌ /etc/os-release 파일이 없어 배포판 감지 실패. 수동 설치 권장."
    exit 1
fi

echo "📦 감지된 배포판: $DISTRO_ID"
echo "🔍 기반 계열: ${DISTRO_LIKE:-없음}"

# 2. 패키지 설치 명령 정의
PKGS=(fcitx5 fcitx5-hangul)
EXTRA_PKGS=()
INSTALL_CMD=""

case "$DISTRO_ID" in
    ubuntu|debian|linuxmint|pop|elementary|zorin|neon|kubuntu|lubuntu|xubuntu|ubuntu-mate|galliumos|linuxlite|deepin|mx|endless|tuxedo|vanilla|proxmox|truenas|volumio)
        EXTRA_PKGS=(fcitx5-config-qt fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 fcitx5-frontend-qt5)
        INSTALL_CMD="sudo apt update && sudo apt install -y"
        ;;
    arch|manjaro|arcolinux|endeavouros|antergos|archbang|chakra|archcraft|steamos)
        EXTRA_PKGS=(fcitx5-configtool fcitx5-gtk fcitx5-qt)
        INSTALL_CMD="sudo pacman -Sy --noconfirm"
        ;;
    fedora|rhel|rocky|alma|centos|scientific|oracle|navix|amazon|asahi)
        EXTRA_PKGS=(fcitx5-configtool fcitx5-gtk3 fcitx5-qt)
        INSTALL_CMD="sudo dnf install -y"
        ;;
    opensuse*|suse)
        INSTALL_CMD="sudo zypper install -y"
        ;;
    alpine)
        INSTALL_CMD="sudo apk add"
        ;;
    void)
        INSTALL_CMD="sudo xbps-install -Sy"
        ;;
    gentoo|funtoo)
        INSTALL_CMD="sudo emerge"
        ;;
    slackware)
        echo "⚠️ Slackware는 수동 설치 권장. 'fcitx5' 및 관련 패키지를 slackbuilds에서 설치하세요."
        exit 1
        ;;
    *)
        echo "⚠️ 알 수 없는 배포판입니다. 다음 패키지를 수동 설치하세요:"
        echo "   ${PKGS[*]}"
        exit 1
        ;;
esac

ALL_PKGS=("${PKGS[@]}" "${EXTRA_PKGS[@]}")

# 3. 패키지 설치
echo "📥 설치할 패키지: ${ALL_PKGS[*]}"
eval "$INSTALL_CMD ${ALL_PKGS[*]}"

# 4. 환경 변수 설정
PAM_ENV="$HOME/.pam_environment"
mkdir -p "$(dirname "$PAM_ENV")"
touch "$PAM_ENV"
grep -v 'GTK_IM_MODULE\|QT_IM_MODULE\|XMODIFIERS' "$PAM_ENV" > "$PAM_ENV.tmp" && mv "$PAM_ENV.tmp" "$PAM_ENV"
cat >> "$PAM_ENV" <<EOF
GTK_IM_MODULE DEFAULT=fcitx5
QT_IM_MODULE DEFAULT=fcitx5
XMODIFIERS DEFAULT=@im=fcitx5
EOF

# 5. Fcitx5 프로파일 설정
mkdir -p ~/.config/fcitx5
cat > ~/.config/fcitx5/profile <<EOF
[Groups/0]
Name=Default
Default Layout=ko
DefaultIM=hangul

[Groups/0/Items/0]
Name=keyboard-us
Layout=us

[Groups/0/Items/1]
Name=keyboard-ko
Layout=ko

[Groups/0/Items/2]
Name=hangul
Layout=ko

[GroupOrder]
0=Default
EOF

# 6. 한영 전환 키 설정 (RightAlt, Alt_R, Hangul 키)
mkdir -p ~/.config/fcitx5/conf
cat > ~/.config/fcitx5/conf/imswitch.conf <<EOF
TriggerKeys=RightAlt,Alt_R,Hangul
AltTriggerKeys=
EOF

# 7. 자동 시작 등록
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/fcitx5.desktop <<EOF
[Desktop Entry]
Type=Application
Exec=fcitx5
Hidden=false
X-GNOME-Autostart-enabled=true
Name=Fcitx5
Comment=Start fcitx5 input method
EOF

# 8. Wayland + GNOME 경고
SESSION_TYPE=$(loginctl show-session $(loginctl | grep "$(whoami)" | awk '{print $1}') -p Type | cut -d= -f2)
DESKTOP_SESSION=${XDG_CURRENT_DESKTOP,,}

if [[ "$SESSION_TYPE" == "wayland" && "$DESKTOP_SESSION" == *"gnome"* ]]; then
    echo -e "\n⚠️ 현재 GNOME + Wayland 환경에서는 IBus와 Fcitx5가 충돌할 수 있습니다."
    echo "👉 해결 방법:"
    echo "   1. GNOME 설정 > 지역 및 언어 > 입력 소스에서 Fcitx5가 있는지 확인."
    echo "   2. 'im-config'로 fcitx5를 기본 입력기로 설정."
    echo "   3. 로그인 시 'GNOME on Xorg'로 로그인 권장."
fi

# 9. 진단 안내
echo -e "\n🔍 진단: fcitx5-diagnose > ~/fcitx5-diagnose.log 로 확인 가능"

# 10. 완료
echo -e "\n🎉 설치 및 설정이 완료되었습니다!"
echo "🔄 시스템을 재시작하거나 로그아웃 후 다시 로그인해 주세요."
