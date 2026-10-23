# Конфигурация виртуальной машины devops-vm

## 1. Параметры машины
- **Объём памяти:** 2048 МБ
- **Количество ядер:** 2
- **Объём диска:** 25 ГБ (динамически расширяемый)

## 2. Сетевые интерфейсы
- **Адаптер 1 (NAT):** `enp0s3`, IP `10.0.2.15/24`. Назначение: доступ в интернет (репозитории).
- **Адаптер 2 (Host-only):** `enp0s8`, IP `192.168.56.101/24`. Назначение: доступ к VM с хостовой машины.

## 3. Правило проброса портов
- **Хост (Windows):** порт `2222`
- **Гость (VM):** порт `2222` (SSH)

## 4. Учётные записи
- **student:** в группе `sudo`, вход по паролю.
- **devops:** в группе `sudo`, вход по SSH-ключу (`devops_vm`).

## 5. Служба SSH
- **Порт:** `2222`
- **Файл конфигурации:** `/etc/ssh/sshd_config.d/99-hardening.conf`
- **Директивы:** `PermitRootLogin no`, `PasswordAuthentication no`, `MaxAuthTries 3`, `AllowUsers devops`, `LoginGraceTime 30`.

## 6. Правила межсетевого экрана
- **Политики по умолчанию:** `deny incoming`, `allow outgoing`.
- **Правила:** `2222/tcp` (LIMIT), `80/tcp` (ALLOW), `443/tcp` (ALLOW).

## 7. Снимки состояния
- `01-clean-install` — после установки ОС.
- `02-keys-configured` — после настройки SSH-ключей.
- `03-ssh-hardened` — после hardening и UFW.
- `04-dns-configured` — после настройки DNS.

## 8. Веб-сервер
- **Пакет:** `nginx`
- **Конфигурация ресурса:** `/etc/nginx/sites-available/devops-site`
- **Каталог ресурса:** `/var/www/devops-site`, владелец `devops:devops`, права `755` (для каталога), `644` (для файлов).
- **Сертификат:** `/etc/ssl/certs/devops.crt` (права `644`, владелец `root`).
- **Ключ:** `/etc/ssl/private/devops.key` (права `600`, владелец `root`).
- **Команда формирования сертификата:** `sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/devops.key -out /etc/ssl/certs/devops.crt -subj "/CN=devops.local" -addext "subjectAltName=DNS:devops.local" -addext "basicConstraints=critical,CA:TRUE"`
- **Срок действия:** 365 дней (1 год).
