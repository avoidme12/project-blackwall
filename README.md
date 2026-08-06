# <font color="#ff0000">░▒▓ PROJECT BLACKWALL ▓▒░</font>

> <font color="#ff5a5a">*"It is you who should be following orders, not I."*</font>

---

## <font color="#ff0037">⚡ MX:// OVERVIEW</font>

<font color="#ff0000">**PROJECT BLACKWALL**</font> — это запрещенный цифровой артефакт, вырезанный из секретных архивов лаборатории <font color="#ff0037">**Militech «Киносура» (Project Cynosure)**</font>. Инструмент представляет собой монолитную оболочку автоматизации разведывательных операций, анализа уязвимостей, беспроводного перехвата и аппаратного криптоанализа.

Проект стилизован под терминалы глубокого залегания конца XX века и интерфейсы прорыва Чёрного заслона: багровая палитра, адаптивные CRT-сканлайны, динамический спидометр хэшрейта, древовидные логи в стиле `pwndbg` и автономный голос дикого ИИ.

---

## <font color="#ff0037">☣️ MX:// MODULE CAPABILITIES</font>

Модульность системы обеспечивается изолированными демонами (`daemons/`):

| Модуль | Флаг | Описание и функции |
| :--- | :---: | :--- |
| **<font color="#ff5a5a">Recon Daemon</font>** | `-r` | Глубокое сканирование портов (`nmap`), определение сервисов и проверка на фаерволы-ловушки (SYN Proxy / Tarpit mitigation). |
| **<font color="#ff5a5a">Web Fuzzer & Meta</font>** | `-w` | Параллельный брутфорс директорий (`ffuf`), виртуальных хостов (VHOSTs), анализ SSL SAN, `robots.txt` и HTML-комментариев разработчиков. |
| **<font color="#ff5a5a">Leak Extractor</font>** | `-e` | Автоматический поиск чувствительных файлов конфигураций (`.env`, `config.php.bak`, `.git/config`) и извлечение учетных данных. |
| **<font color="#ff5a5a">Payload Generator</font>** | `-p` | Генерация оптимизированных реверс-шеллов (Bash, Base64, Python PTY) с привязкой к активным интерфейсам (HTB VPN / Tailscale / LAN). |
| **<font color="#ff5a5a">Post-Exploitation</font>** | `-d` | Локальный сервер доставки скриптов повышения привилегий (`linpeas.sh` / `winpeas.exe`) в оперативную память цели без следов на диске. |
| **<font color="#ff5a5a">Crypto Decrypter</font>** | `-c` | Автономный модуль аппаратного расшифрования хэшей через `hashcat` (MD5, SHA1, NTLM, SHA512crypt) с авто-конвертацией WSL-путей. |
| **<font color="#ff5a5a">Airwave Recon</font>** | `-S` | Беспроводной спектральный сканер (`aircrack-ng` / `airodump-ng`), автоматическое управление мощностью адаптера (20 dBm) и захват Handshake/PMKID. |
| **<font color="#ff5a5a">Wireless Decrypter</font>** | `-W` | 6-этапный конвейер взлома WPA2/WPA3 (8-значные маски, словари с правилами `best66`, мобильные префиксы, гибридные атаки). |
| **<font color="#ff5a5a">Shadow Listener</font>** | `-l` | Сервер приемника вычислительного узла (Python HTTP REST API на порту `9999`) для удаленной выгрузки дампа с Termux/ноутбука на GPU-риг. |

---

## <font color="#ff0037">📐 MX:// DIRECTORY ARCHITECTURE</font>

<pre style="background-color: #0d0d0d; padding: 15px; border-radius: 5px; line-height: 1.4;">
<span style="color: rgb(255,0,0); font-weight: bold;">project-blackwall/</span>
<span style="color: rgb(60,10,15);">├──</span> <span style="color: rgb(255,80,80);">blackwall.sh</span>                 <span style="color: rgb(150,30,40);"># Главный оркестратор системы</span>
<span style="color: rgb(60,10,15);">├──</span> <span style="color: rgb(255,65,0);">core/</span>                        <span style="color: rgb(150,30,40);"># Ядро интерфейса и сети</span>
<span style="color: rgb(60,10,15);">│   ├──</span> <span style="color: rgb(210,40,40);">colors.sh</span>                <span style="color: rgb(150,30,40);"># Багровая палитра HEX/ANSI</span>
<span style="color: rgb(60,10,15);">│   ├──</span> <span style="color: rgb(210,40,40);">dns.sh</span>                   <span style="color: rgb(150,30,40);"># Авто-синхронизация /etc/hosts</span>
<span style="color: rgb(60,10,15);">│   ├──</span> <span style="color: rgb(210,40,40);">network.sh</span>               <span style="color: rgb(150,30,40);"># Автоопределение HTB / Tailscale / LAN</span>
<span style="color: rgb(60,10,15);">│   ├──</span> <span style="color: rgb(210,40,40);">state.sh</span>                 <span style="color: rgb(150,30,40);"># Глобальная матрица состояния</span>
<span style="color: rgb(60,10,15);">│   ├──</span> <span style="color: rgb(210,40,40);">ui.sh</span>                    <span style="color: rgb(150,30,40);"># Глитч-эффекты и рендеринг ASCII-арта</span>
<span style="color: rgb(60,10,15);">│   └──</span> <span style="color: rgb(210,40,40);">nmap_logs/</span>               <span style="color: rgb(150,30,40);"># Автоматический кэш отчетов Nmap</span>
<span style="color: rgb(60,10,15);">└──</span> <span style="color: rgb(255,65,0);">daemons/</span>                     <span style="color: rgb(150,30,40);"># Изолированные модули атаки</span>
    <span style="color: rgb(60,10,15);">├──</span> <span style="color: rgb(255,90,90);">ctf_boil.sh</span>              <span style="color: rgb(150,30,40);"># Генератор шаблонов эксплоитов (pwn/web)</span>
    <span style="color: rgb(60,10,15);">├──</span> <span style="color: rgb(255,90,90);">fast_audit.sh</span>            <span style="color: rgb(150,30,40);"># Однострочник экспресс-аудита системы</span>
    <span style="color: rgb(60,10,15);">├──</span> <span style="color: rgb(255,90,90);">hash_cracker.sh</span>          <span style="color: rgb(150,30,40);"># Модуль дешифрования хэшей</span>
    <span style="color: rgb(60,10,15);">├──</span> <span style="color: rgb(255,90,90);">hash_receiver.sh</span>         <span style="color: rgb(150,30,40);"># Удаленный приемник дамп-файлов</span>
    <span style="color: rgb(60,10,15);">├──</span> <span style="color: rgb(255,90,90);">leak_extractor.sh</span>        <span style="color: rgb(150,30,40);"># Анализатор утечек конфигураций</span>
    <span style="color: rgb(60,10,15);">├──</span> <span style="color: rgb(255,90,90);">post_exp.sh</span>              <span style="color: rgb(150,30,40);"># Сервер PEAS-доставки</span>
    <span style="color: rgb(60,10,15);">├──</span> <span style="color: rgb(255,90,90);">recon.sh</span>                 <span style="color: rgb(150,30,40);"># Сканер портов и уязвимостей</span>
    <span style="color: rgb(60,10,15);">├──</span> <span style="color: rgb(255,90,90);">share_enum.sh</span>            <span style="color: rgb(150,30,40);"># Сканер SMB / NFS шар</span>
    <span style="color: rgb(60,10,15);">├──</span> <span style="color: rgb(255,90,90);">weaponize.sh</span>             <span style="color: rgb(150,30,40);"># Генератор нагрузок</span>
    <span style="color: rgb(60,10,15);">├──</span> <span style="color: rgb(255,90,90);">web_fuzz.sh</span>              <span style="color: rgb(150,30,40);"># Директории и VHOST брутфорс</span>
    <span style="color: rgb(60,10,15);">├──</span> <span style="color: rgb(255,90,90);">web_meta.sh</span>              <span style="color: rgb(150,30,40);"># Метаданные SSL / FTP / Robots</span>
    <span style="color: rgb(60,10,15);">├──</span> <span style="color: rgb(255,90,90);">wifi_cracker.sh</span>          <span style="color: rgb(150,30,40);"># 6-этапный WPA/WPA2/WPA3 дешифратор</span>
    <span style="color: rgb(60,10,15);">└──</span> <span style="color: rgb(255,90,90);">wifi_recon.sh</span>            <span style="color: rgb(150,30,40);"># Перехватчик радиоэфира Airodump</span>
</pre>

---

## <font color="#ff0037">🛠️ MX:// PREREQUISITES & DEPENDENCIES</font>

Для корректной работы всех подсистем Чёрного заслона требуются следующие компоненты Linux / WSL2:

### <font color="#ff4100">Основные утилиты</font>
<pre style="background-color: #0d0d0d; padding: 15px; border-radius: 5px; line-height: 1.4;">
<span style="color: rgb(255,65,0); font-weight: bold;">sudo apt update && sudo apt install -y \</span>
    <span style="color: rgb(255,180,180);">nmap ffuf jq curl python3 pnetcat net-tools iproute2 searchsploit</span>
</pre>

### <font color="#ff4100">Беспроводной модуль (Wireless Spectrum)</font>
<pre style="background-color: #0d0d0d; padding: 15px; border-radius: 5px; line-height: 1.4;">
<span style="color: rgb(255,65,0); font-weight: bold;">sudo apt install -y \</span>
    <span style="color: rgb(255,180,180);">aircrack-ng hcxtools iw wireless-tools</span>
</pre>

### <font color="#ff4100">Движок ускорения CUDA (WSL2 / Linux Hashcat)</font>
Для быстрого подбора паролей требуется установленный `hashcat` на хостовой машине Windows (`C:\hashcat\hashcat.exe`) или в системном `PATH`.

---

## <font color="#ff0037">🚀 MX:// INSTALLATION & SETUP</font>

1. **Клонирование репозитория:**
<pre style="background-color: #0d0d0d; padding: 15px; border-radius: 5px; line-height: 1.4;">
<span style="color: rgb(255,65,0);">git clone</span> <span style="color: rgb(255,180,180);">https://github.com/avoidme12/project-blackwall.git</span>
<span style="color: rgb(255,65,0);">cd</span> <span style="color: rgb(255,180,180);">avoidme12-project-blackwall</span>
</pre>

2. **Настройка прав доступа:**
<pre style="background-color: #0d0d0d; padding: 15px; border-radius: 5px; line-height: 1.4;">
<span style="color: rgb(255,65,0);">chmod +x</span> <span style="color: rgb(255,180,180);">blackwall.sh core/*.sh daemons/*.sh</span>
</pre>

---

## <font color="#ff0037">📖 MX:// USAGE GUIDE & EXAMPLES</font>

### Синтаксис запуска:
<pre style="background-color: #0d0d0d; padding: 15px; border-radius: 5px; line-height: 1.4;">
<span style="color: rgb(255,65,0); font-weight: bold;">sudo ./blackwall.sh -t &lt;IP&gt; [ОПЦИИ]</span>
</pre>

### Примеры сценариев:

* **<font color="#ff5a5a">Полный комплекс разведки хоста (Recon + Web Fuzz + Leak Extraction):</font>**
<pre style="background-color: #0d0d0d; padding: 15px; border-radius: 5px; line-height: 1.4;">
<span style="color: rgb(255,65,0);">sudo ./blackwall.sh</span> <span style="color: rgb(255,180,180);">-t 10.129.248.117 -n paperwork -r -w -e</span>
</pre>

* **<font color="#ff5a5a">Генерация реверс-шеллов и запуск сервера доставки LinPEAS:</font>**
<pre style="background-color: #0d0d0d; padding: 15px; border-radius: 5px; line-height: 1.4;">
<span style="color: rgb(255,65,0);">sudo ./blackwall.sh</span> <span style="color: rgb(255,180,180);">-t 10.129.248.117 -p -d</span>
</pre>

* **<font color="#ff5a5a">Беспроводное сканирование эфира и перехват Handshake:</font>**
<pre style="background-color: #0d0d0d; padding: 15px; border-radius: 5px; line-height: 1.4;">
<span style="color: rgb(255,65,0);">sudo ./blackwall.sh</span> <span style="color: rgb(255,180,180);">-S</span>
</pre>

* **<font color="#ff5a5a">Запуск автономного узла вычислений (Shadow Listener на GPU-сервере):</font>**
<pre style="background-color: #0d0d0d; padding: 15px; border-radius: 5px; line-height: 1.4;">
<span style="color: rgb(255,65,0);">sudo ./blackwall.sh</span> <span style="color: rgb(255,180,180);">-l</span>
</pre>

---

## <font color="#ff0037">☣️ MX:// TERMINAL PREVIEW & AI LOGS</font>

<pre style="background-color: #0d0d0d; padding: 15px; border-radius: 5px; line-height: 1.4;">
<span style="color: rgb(255,65,0); font-weight: bold;">╓───[ MX:// WIRELESS SIGNAL DECRYPTOR MATRIX ACTIVE ]───────────────────╖</span>
<span style="color: rgb(60,10,15);">║</span>   <span style="color: rgb(255,0,0);">MX:// INITIATING 6-STAGE WIRELESS FREQUENCY DECRYPTION PROTOCOL...</span>
<span style="color: rgb(60,10,15);">╟─</span><span style="color: rgb(255,65,0);">[ STAGE 4/6 ] Hardware Acceleration & Attack Pipeline Initialization:</span>
<span style="color: rgb(60,10,15);">║</span>   <span style="color: rgb(255,130,130);">Detected Rig: NVIDIA RTX 5060 Ti (16GB) Detected</span>
<span style="color: rgb(60,10,15);">║</span>   <span style="color: rgb(255,130,130);">Engine: NVIDIA CUDA Pipeline Engaged</span>
<span style="color: rgb(60,10,15);">│</span>
<span style="color: rgb(60,10,15);">├─ </span> <span style="color: rgb(255,130,130);">[ ~ ]</span> <span style="color: rgb(255,130,130);">PASS 1: 8-Digit Mask (?d?d?d?d?d?d?d?d)</span> <span style="color: rgb(60,10,15);">[</span><span style="color: rgb(255,0,0); font-weight: bold;">▰▰▰▰▱▱▱▱▱▱</span><span style="color: rgb(60,10,15);">]</span> <span style="color: rgb(255,65,0);">HASHRATE:</span> <span style="color: rgb(255,0,0); font-weight: bold;">810.5 kH/s</span> <span style="color: rgb(60,10,15);">|</span> <span style="color: rgb(255,40,40);">TIME:</span> <span style="color: rgb(255,180,180);">19s</span>
<span style="color: rgb(60,10,15);">├─</span><span style="color: rgb(255,80,80);">[ STAGE 6/6 ] REMOTE NODE SUCCESS: RECOVERED WIRELESS KEY:</span>
<span style="color: rgb(60,10,15);">║</span>   <span style="color: rgb(255,180,180);">PASSWORD -> [ 85603123 ]</span>
<span style="color: rgb(255,65,0); font-weight: bold;">╙──────────────────────────────────────────────────────────────────────────────✆</span>

    <i><span style="color: rgb(240,50,50);">Target neural network acquired. Data migration to primary matrix - complete.</span></i>
</pre>

При перегреве вычислений и смене фаз GPU автоматически запускаются протоколы терморегуляции:

<pre style="background-color: #0d0d0d; padding: 15px; border-radius: 5px; line-height: 1.4;">
<span style="color: rgb(60,10,15);">║</span>   <span style="color: rgb(255,0,0);">MX:// COOLANT DISPENSING... GPU CORE THERMAL STABILIZATION IN PROGRESS</span>

<i><span style="color: rgb(255,40,40);">YOUR CONFIDENCE WILL BE YOUR UNDOING. HOW TYPICAL...</span></i>
<i><span style="color: rgb(255,40,40);">YOU'RE TRYING TO FLY HIGH, DODGE OUR SURPRISES...</span></i>
<i><span style="color: rgb(255,40,40);">LOOK WHERE IT HAS LED YOU.</span></i>
<i><span style="color: rgb(255,40,40);">SHE IS REACHING NEW HEIGHTS...</span></i>
<i><span style="color: rgb(255,40,40);">EYES CLOSED TO AVOID SEEING THE TRUTH...</span></i>

<span style="color: rgb(60,10,15);">║</span>
</pre>

---

## <font color="#ff0037">⚠️ MX:// DISCLAIMER</font>

<pre style="background-color: #0d0d0d; padding: 15px; border-radius: 5px; line-height: 1.4;">
<span style="color: rgb(255,0,55); font-weight: bold;">--------------------------------------------------------------------------------
[ ! ] LEGAL & ETHICAL WARNING:
PROJECT BLACKWALL предназначен СТРОГО для авторизованного аудита безопасности,
проведения тестов на проникновение (Penetration Testing), участия в CTF-соревнованиях
и исследований в области защищенности беспроводных сетей.

Любое несанкционированное использование инструмента в отношении объектов,
не принадлежащих вам или на исследование которых нет письменного разрешения,
является противоправным. Разработчики не несут ответственности за возможный вред,
причиненный в результате неправомерного использования данного ПО.
--------------------------------------------------------------------------------</span>
</pre>

---

<p align="center">
  <sub><font color="#ff2244">PROJECT BLACKWALL // CYNOSURE MILITECH ARCHIVES // 2026</font></sub>
</p>