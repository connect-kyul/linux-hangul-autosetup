#!/bin/bash

echo "🔧 Fcitx5 + Hangul 입력기 설치 및 설정을 시작합니다..."

# 0. 배포판 감지
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_ID=$ID
else
    echo "❌ 배포판을 감지할 수 없습니다. 수동 설치를 권장합니다."
    exit 1
fi

# 1. 패키지 설치
echo "📦 감지된 배포판: $DISTRO_ID"
PKGS_TO_INSTALL=()
INSTALLED_ALL=true

case "$DISTRO_ID" in
    ubuntu|debian)
        PKGS=(fcitx5 fcitx5-hangul fcitx5-config-qt fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 fcitx5-frontend-qt5)
        for pkg in "${PKGS[@]}"; do
            if ! dpkg -s "$pkg" &>/dev/null; then
                PKGS_TO_INSTALL+=("$pkg")
                INSTALLED_ALL=false
            fi
        done
        ;;
    arch|manjaro)
        PKGS=(fcitx5 fcitx5-hangul fcitx5-configtool fcitx5-gtk fcitx5-qt)
        for pkg in "${PKGS[@]}"; do
            if ! pacman -Qs "$pkg" &>/dev/null; then
                PKGS_TO_INSTALL+=("$pkg")
                INSTALLED_ALL=false
            fi
        done
        ;;
    fedora)
        PKGS=(fcitx5 fcitx5-hangul fcitx5-configtool fcitx5-gtk3 fcitx5-qt)
        for pkg in "${PKGS[@]}"; do
            if ! rpm -q "$pkg" &>/dev/null; then
                PKGS_TO_INSTALL+=("$pkg")
                INSTALLED_ALL=false
            fi
        done
        ;;
    *)
        echo "❌ 지원되지 않는 배포판입니다: $DISTRO_ID"
        exit 1
        ;;
esac

if [ "$INSTALLED_ALL" = true ]; then
    echo "✅ 필요한 패키지가 이미 설치되어 있습니다."
else
    echo "📥 패키지를 설치합니다: ${PKGS_TO_INSTALL[@]}"
    case "$DISTRO_ID" in
        ubuntu|debian)
            sudo apt update && sudo apt install -y "${PKGS_TO_INSTALL[@]}"
            ;;
        arch|manjaro)
            sudo pacman -Sy --noconfirm "${PKGS_TO_INSTALL[@]}"
            ;;
        fedora)
            sudo dnf install -y "${PKGS_TO_INSTALL[@]}"
            ;;
    esac
fi

# 2. 환경 변수 설정 (.pam_environment)
PAM_ENV="$HOME/.pam_environment"
echo "🛠 환경 변수를 $PAM_ENV에 설정합니다..."
touch "$PAM_ENV"
grep -v 'GTK_IM_MODULE\|QT_IM_MODULE\|XMODIFIERS' "$PAM_ENV" > "$PAM_ENV.tmp" && mv "$PAM_ENV.tmp" "$PAM_ENV"
cat >> "$PAM_ENV" <<EOF
GTK_IM_MODULE DEFAULT=fcitx5
QT_IM_MODULE DEFAULT=fcitx5
XMODIFIERS DEFAULT=@im=fcitx5
EOF

# 3. 입력기 설정 (영어+한글만)
mkdir -p ~/.config/fcitx5
cat > ~/.config/fcitx5/profile <<EOF
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=hangul

[Groups/0/Items/0]
Name=keyboard-us
Layout=us

[Groups/0/Items/1]
Name=hangul
Layout=ko

[GroupOrder]
0=Default
EOF

# 4. 한영 전환 키 설정
mkdir -p ~/.config/fcitx5/conf
cat > ~/.config/fcitx5/conf/imswitch.conf <<EOF
TriggerKeys=RightAlt,Alt_R,Hangul
AltTriggerKeys=
EOF

# 5. 자동 시작 설정
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

# 6. 세션 경고 (GNOME + Wayland)
SESSION_TYPE=$(loginctl show-session $(loginctl | grep $(whoami) | awk '{print $1}') -p Type | cut -d= -f2)
DESKTOP_SESSION=${XDG_CURRENT_DESKTOP,,}

if [[ "$SESSION_TYPE" == "wayland" && "$DESKTOP_SESSION" == *"gnome"* ]]; then
    echo -e "\\n⚠️ 현재 GNOME + Wayland 환경에서는 IBus와 Fcitx5가 충돌할 수 있습니다."
    echo "👉 해결 방법:"
    echo "   1. GNOME 설정 → 지역 및 언어 → 입력 소스에서 Fcitx5가 우선인지 확인하세요."
    echo "   2. 'im-config' 명령어를 통해 Fcitx5를 기본 입력기로 설정하세요."
    echo "   3. 또는 로그인 화면에서 'GNOME on Xorg' 세션으로 변경하세요."
fi

# 7. 진단 안내
echo -e "\\n🔍 문제 발생 시 아래 명령어로 진단 가능합니다:"
echo "   fcitx5-diagnose > ~/fcitx5-diagnose.log"

# 8. 완료
echo -e "\\n🎉 Fcitx5 + Hangul 설정이 완료되었습니다!"
echo -e "🔄 시스템을 재시작하거나 로그아웃 후 다시 로그인해주세요."