# ░▒▓ PROJECT BLACKWALL ▓▒░

> *"It is you who should be following orders, not I."*

---

## ⚡ MX:// OVERVIEW

**PROJECT BLACKWALL** - это запрещенный цифровой артефакт, вырезанный из секретных архивов лаборатории **Militech «Киносура» (Project Cynosure)**. Инструмент представляет собой монолитную оболочку автоматизации разведывательных операций, анализа уязвимостей, беспроводного перехвата и аппаратного криптоанализа.

Проект стилизован под терминалы глубокого залегания конца XX века и интерфейсы прорыва Чёрного заслона: багровая палитра, адаптивные CRT-сканлайны, динамический спидометр хэшрейта, древовидные логи в стиле `pwndbg` и автономный голос дикого ИИ.

---

## ☣️ MX:// MODULE CAPABILITIES

Модульность системы обеспечивается изолированными демонами (`daemons/`):

| Модуль | Флаг | Описание и функции |
| :--- | :---: | :--- |
| **Recon Daemon** | `-r` | Глубокое сканирование портов (`nmap`), определение сервисов и проверка на фаерволы-ловушки (SYN Proxy / Tarpit mitigation). |
| **Web Fuzzer & Meta** | `-w` | Параллельный брутфорс директорий (`ffuf`), виртуальных хостов (VHOSTs), анализ SSL SAN, `robots.txt` и HTML-комментариев разработчиков. |
| **Leak Extractor** | `-e` | Автоматический поиск чувствительных файлов конфигураций (`.env`, `config.php.bak`, `.git/config`) и извлечение учетных данных. |
| **Payload Generator** | `-p` | Генерация оптимизированных реверс-шеллов (Bash, Base64, Python PTY) с привязкой к активным интерфейсам (HTB VPN / Tailscale / LAN). |
| **Post-Exploitation** | `-d` | Локальный сервер доставки скриптов повышения привилегий (`linpeas.sh` / `winpeas.exe`) в оперативную память цели без следов на диске. |
| **Crypto Decrypter** | `-c` | Автономный модуль аппаратного расшифрования хэшей через `hashcat` (MD5, SHA1, NTLM, SHA512crypt) с авто-конвертацией WSL-путей. |
| **Airwave Recon** | `-S` | Беспроводной спектральный сканер (`aircrack-ng` / `airodump-ng`), автоматическое управление мощностью адаптера (20 dBm) и захват Handshake/PMKID. |
| **Wireless Decrypter** | `-W` | 6-этапный конвейер взлома WPA2/WPA3 (8-значные маски, словари с правилами `best66`, мобильные префиксы, гибридные атаки). |
| **Shadow Listener** | `-l` | Сервер приемника вычислительного узла (Python HTTP REST API на порту `9999`) для удаленной выгрузки дампа с Termux/ноутбука на GPU-риг. |

---

## 📐 MX:// DIRECTORY ARCHITECTURE

```
project-blackwall/
├── blackwall.sh                 # Главный оркестратор системы
├── core/                        # Ядро интерфейса и сети
│   ├── colors.sh                # Багровая палитра HEX/ANSI
│   ├── dns.sh                   # Авто-синхронизация /etc/hosts
│   ├── network.sh               # Автоопределение HTB / Tailscale / LAN
│   ├── state.sh                 # Глобальная матрица состояния
│   └── ui.sh                    # Глитч-эффекты и рендеринг ASCII-арта
└── daemons/                     # Изолированные модули атаки
├── hash_cracker.sh          # Модуль дешифрования хэшей
├── hash_receiver.sh         # Удаленный приемник дамп-файлов
├── leak_extractor.sh        # Анализатор утечек конфигураций
├── post_exp.sh              # Сервер PEAS-доставки
├── recon.sh                 # Сканер портов и уязвимостей
├── share_enum.sh            # Сканер SMB / NFS шар
├── weaponize.sh             # Генератор нагрузок
├── web_fuzz.sh              # Директории и VHOST брутфорс
├── web_meta.sh              # Метаданные SSL / FTP / Robots
└── wifi_cracker.sh          # 6-этапный WPA/WPA2/WPA3 дешифратор
```

---

## 🛠️ MX:// PREREQUISITES & DEPENDENCIES

Для корректной работы всех подсистем Чёрного заслона требуются следующие компоненты Linux / WSL2:

### Основные утилиты
```bash
sudo apt update && sudo apt install -y \
    nmap \
    ffuf \
    jq \
    curl \
    python3 \
    pnetcat \
    net-tools \
    iproute2 \
    searchsploit
```

### Беспроводной модуль (Wireless Spectrum)
```bash
sudo apt install -y \
    aircrack-ng \
    hcxtools \
    iw \
    wireless-tools
```

### Движок ускорения CUDA (WSL2 / Linux Hashcat)
Для быстрого подбора паролей требуется установленнный `hashcat` на хостовой машине Windows (`C:\hashcat\hashcat.exe`) или в системном `PATH`.

---

## 🚀 MX:// INSTALLATION & SETUP

1. **Клонирование репозитория:**
```bash
git clone https://github.com/avoidme12/project-blackwall.git
cd avoidme12-project-blackwall
```

2. **Настройка прав доступа:**
```bash
chmod +x blackwall.sh
chmod +x core/*.sh
chmod +x daemons/*.sh
```

3. **Стилизация Windows Terminal (Необязательно):**
   Для достижения 100% аутентичности терминалов Киносуры установите шрифт **0xProto Nerd Font** или **Share Tech Mono** и примените тему `Cynosure_Militech_Authentic` из файла настройки Windows Terminal (`settings.json`).

---

## 📖 MX:// USAGE GUIDE & EXAMPLES

### Синтаксис запуска:
```bash
sudo ./blackwall.sh -t <IP> [ОПЦИИ]
```

### Примеры сценариев:

* **Полный комплекс разведки хоста (Recon + Web Fuzz + Leak Extraction):**
  ```bash
  sudo ./blackwall.sh -t 10.129.248.117 -n paperwork -r -w -e
  ```

* **Генерация реверс-шеллов и запуск сервера доставки LinPEAS:**
  ```bash
  sudo ./blackwall.sh -t 10.129.248.117 -p -d
  ```

* **Беспроводное сканирование эфира, перехват Handshake и запуск GPU-дешифратора:**
  ```bash
  sudo ./blackwall.sh -S
  # Из меню выберите цель -> запустите -W для локального или удаленного взлома
  ```

* **Запуск автономного узла вычислений (Shadow Listener на GPU-сервере):**
  ```bash
  sudo ./blackwall.sh -l
  # Открывает слушатель на порту 9999 для выгрузки с ноутбуков/Termux через Tailscale
  ```

---

## ☣️ MX:// AI LOGS & TERMINAL INTERACTION

Инструмент сопровождает действия оператора репликами дикого ИИ:

```
  ║   [ MX:// CORE_COGNITION ] » Target neural network acquired. Data migration to primary matrix – complete.
```

При перегреве вычислений и смене фаз GPU автоматически запускаются протоколы терморегуляции:

```
  ║   MX:// COOLANT DISPENSING... GPU CORE THERMAL STABILIZATION IN PROGRESS
  ║   [ MX:// CORE_COGNITION ] » YOUR CONFIDENCE WILL BE YOUR UNDOING. HOW TYPICAL ...
  ║   [ MX:// CORE_COGNITION ] » LOOK WHERE IT HAS LED YOU.
```

---

## ⚠️ MX:// DISCLAIMER

```
--------------------------------------------------------------------------------
[ ! ] LEGAL & ETHICAL WARNING:
PROJECT BLACKWALL предназначен СТРОГО для авторизованного аудита безопасности,
проведения тестов на проникновение (Penetration Testing), участия в CTF-соревнованиях
и исследований в области защищенности беспроводных сетей.

Любое несанкционированное использование инструмента в отношении объектов,
не принадлежащих вам или на исследование которых нет письменного разрешения,
является противоправным. Разработчики не несут ответственности за возможный вред,
причиненный в результате неправомерного использования данного ПО.
--------------------------------------------------------------------------------
```

---

<p align="center">
  <sub>PROJECT BLACKWALL // CYNOSURE MILITECH ARCHIVES // 2026</sub>
</p>
