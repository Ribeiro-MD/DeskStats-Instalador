#!/bin/sh
# Instala o agente do DeskStats para o utilizador atual e liga-o já.
#   sh install.sh           instalar
#   sh install.sh remover   desinstalar
set -e

REPO=https://raw.githubusercontent.com/Ribeiro-MD/DeskStats-Instalador/main
DIR="$HOME/.local/share/deskstats"
UNIT="$HOME/.config/systemd/user/deskstats.service"
AUTOSTART="$HOME/.config/autostart/deskstats.desktop"
PORT=8085

has_systemd() {
    command -v systemctl >/dev/null && systemctl --user show-environment >/dev/null 2>&1
}

# versões antigas chamavam-se "pcmonitor" e ocupavam a mesma porta
if has_systemd; then
    systemctl --user disable --now pcmonitor 2>/dev/null || true
fi
pkill -f "pcmonitor/agent.py" 2>/dev/null || true
rm -rf "$HOME/.local/share/pcmonitor" "$HOME/.config/systemd/user/pcmonitor.service" "$HOME/.config/autostart/pcmonitor.desktop"

if [ "$1" = remover ]; then
    if has_systemd; then
        systemctl --user disable --now deskstats 2>/dev/null || true
    fi
    pkill -f "$DIR/agent.py" 2>/dev/null || true
    rm -rf "$DIR" "$UNIT" "$AUTOSTART"
    has_systemd && systemctl --user daemon-reload
    echo "DeskStats removido."
    exit 0
fi

PY=$(command -v python3 || true)
if [ -z "$PY" ]; then
    echo "Falta o Python 3. Instala-o primeiro, por exemplo:"
    echo "  sudo apt install python3     (Ubuntu, Debian, Mint)"
    echo "  sudo dnf install python3     (Fedora)"
    echo "  sudo pacman -S python        (Arch)"
    exit 1
fi

mkdir -p "$DIR"
# com "curl ... | sh" não há pasta do script, por isso vai buscar o agente ao GitHub
if [ -f "$0" ] && [ -f "$(dirname "$0")/agent.py" ]; then
    cp "$(dirname "$0")/agent.py" "$DIR/agent.py"
elif command -v curl >/dev/null; then
    curl -fsSL "$REPO/agent.py" -o "$DIR/agent.py"
else
    wget -qO "$DIR/agent.py" "$REPO/agent.py"
fi

if has_systemd; then
    systemctl --user disable --now deskstats 2>/dev/null || true
    mkdir -p "$(dirname "$UNIT")"
    rm -f "$UNIT"
    cat > "$UNIT" <<EOF
[Unit]
Description=DeskStats (agente para o widget do telemóvel)
After=network-online.target

[Service]
ExecStart=$PY -u $DIR/agent.py $PORT
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload
    systemctl --user enable --now deskstats
else
    mkdir -p "$(dirname "$AUTOSTART")"
    cat > "$AUTOSTART" <<EOF
[Desktop Entry]
Type=Application
Name=DeskStats
Exec=$PY $DIR/agent.py $PORT
NoDisplay=true
EOF
    pkill -f "$DIR/agent.py" 2>/dev/null || true
    nohup "$PY" "$DIR/agent.py" "$PORT" >/dev/null 2>&1 &
fi

# o telemóvel precisa da porta aberta: TCP para os dados, UDP para o encontrar
if command -v ufw >/dev/null && systemctl is-active -q ufw 2>/dev/null; then
    echo "A abrir a porta $PORT na firewall (pede a password):"
    sudo ufw allow "$PORT" || echo "Não deu. Corre: sudo ufw allow $PORT"
elif command -v firewall-cmd >/dev/null && systemctl is-active -q firewalld 2>/dev/null; then
    echo "A abrir a porta $PORT na firewall (pede a password):"
    { sudo firewall-cmd -q --permanent --add-port="$PORT/tcp" --add-port="$PORT/udp" && sudo firewall-cmd -q --reload; } \
        || echo "Não deu. Corre: sudo firewall-cmd --permanent --add-port=$PORT/tcp --add-port=$PORT/udp && sudo firewall-cmd --reload"
fi

sleep 1
IP=$(ip route get 1.1.1.1 2>/dev/null | sed -n 's/.* src \([0-9.]*\).*/\1/p')
echo
echo "DeskStats instalado e ligado. Arranca sozinho sempre que entras no PC."
echo "Use este ip no seu dispositivo móvel: ${IP:-?}:$PORT"
echo "(ou deixa o campo vazio na app e carrega em Ligar, que ela encontra o PC)"
