#!/usr/bin/env bash
set -uo pipefail

PASS=0; FAIL=0

check() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo " [OK]  $desc"; ((PASS++))
  else
    echo " [FAIL] $desc (ожидалось: '$expected', получено: '$actual')"; ((FAIL++))
  fi
}

echo "Аудит конфигурации: $(hostname -f), $(date '+%Y-%m-%d %H:%M')"

echo "[1] Служба SSH"
check "Вход от имени root запрещён" "no" "$(sudo sshd -T | awk '/^permitrootlogin/{print $2}')"
check "Парольная аутентификация отключена" "no" "$(sudo sshd -T | awk '/^passwordauthentication/{print $2}')"

# TODO 1: проверьте, что значение параметра port отлично от 22
PORT=$(sudo sshd -T | awk '/^port/{print $2}')
check "Порт SSH нестандартный (не 22)" "2222" "$PORT"

# TODO 2: проверьте, что значение параметра maxauthtries равно 3
MAXAUTH=$(sudo sshd -T | awk '/^maxauthtries/{print $2}')
check "MaxAuthTries равно 3" "3" "$MAXAUTH"

echo "[2] Межсетевой экран"
check "Межсетевой экран активен" "active" "$(sudo ufw status | awk '/^Status:/{print $2}')"

# TODO 3: проверьте, что политика по умолчанию для входящего трафика равна deny
DEFAULT_IN=$(sudo ufw status verbose | grep 'Default:' | grep -oP '(?<=: )deny')
check "Политика по умолчанию для входящего - deny" "deny" "$DEFAULT_IN"

echo "[3] Учётные записи"
awk -F: ' $3>=1000 && $3<65534 {printf " %s (uid=%s)\n",$1,$3}' /etc/passwd

echo "[4] Веб-сервер"
# а) конфигурация nginx синтаксически корректна
sudo nginx -t >/dev/null 2>&1
check "Конфигурация Nginx корректна" "0" "$?"

# б) сертификат истекает не ранее чем через 30 дней
DAYS_LEFT=$(( ($(date -d "$(openssl x509 -in /etc/ssl/certs/devops.crt -noout -enddate | cut -d= -f2)" +%s) - $(date +%s)) / 86400 ))
check "Сертификат действителен более 30 дней" "true" "$( [ "$DAYS_LEFT" -gt 30 ] && echo true || echo false )"

# в) нет файлов, доступных для записи всем
NO_WRITABLE=$(find /var/www/devops-site -perm -o+w | wc -l)
check "Нет файлов с правом записи для всех" "0" "$NO_WRITABLE"

# г) права ключа равны 600
KEY_PERMS=$(sudo stat -c '%a' /etc/ssl/private/devops.key)
check "Права ключа 600" "600" "$KEY_PERMS"

echo "[5] Контейнеризация"
check "Служба Docker активна" "active" "$(systemctl is-active docker)"
DB_HEALTH=$(docker inspect -f '{{.State.Health.Status}}' app-db-1 2>/dev/null || echo "not_found")
check "Контейнер СУБД healthy" "healthy" "$DB_HEALTH"
BAD_PORTS=$(ss -tln | awk '$4 ~ /:5000$/ || $4 ~ /:5432$/ {if ($4 !~ /^127\.0\.0\.1:/) print $4}' | wc -l)
check "Порты 5000 и 5432 только на 127.0.0.1" "0" "$BAD_PORTS"
ENV_PERMS=$(stat -c '%a' ~/app/.env 2>/dev/null || echo "not_found")
check "Права .env равны 600" "600" "$ENV_PERMS"

echo "Пройдено: $PASS, не пройдено: $FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
