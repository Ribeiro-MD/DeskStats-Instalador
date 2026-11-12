# DeskStats – instalador para Linux

Ferramenta que mostra status do computador (CPU, GPU, RAM e temperaturas do PC), em widget no android.

## Telemóvel

Descarrega e instala o [DeskStats.apk](https://github.com/Ribeiro-MD/DeskStats-Instalador/releases/latest/download/DeskStats.apk)


## Instalar no PC (Linux)

Precisa só de Python 3 (já vem na maioria das distros).

```
curl -fsSL https://raw.githubusercontent.com/Ribeiro-MD/DeskStats-Instalador/main/install.sh | sh
```

Arranca sozinho sempre que entras no PC (mostra o IP a usar no telemóvel.)
Na app basta deixar o campo "IP" vazio e carregar em **Ligar**, que ela procura o PC, se houver vários PCs na rede, aí sim deverá usar o IP.

O PC e o telemóvel têm de estar na mesma rede Wi-Fi.
Se houver firewall (ufw ou firewalld) o instalador abre a porta 8085.

## Desinstalar

```
curl -fsSL https://raw.githubusercontent.com/Ribeiro-MD/DeskStats-Instalador/main/install.sh | sh -s remover
```
