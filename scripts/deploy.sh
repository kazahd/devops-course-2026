#!/usr/bin/env bash
set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
LOCAL_DIR="$(git rev-parse --show-toplevel)/site/"

# 1. Разбор аргумента --dry-run
DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=1
fi

# 2. Проверка: есть ли файл site/index.html (требование 4)
if [[ ! -f "${LOCAL_DIR}/index.html" ]]; then
    echo "Ошибка: файл site/index.html не найден" >&2
    exit 1
fi

# Проверка: нет ли незафиксированных изменений (требование 5)
if [[ -n "$(git status --porcelain)" ]]; then
    echo "Ошибка: есть незафиксированные изменения в репозитории" >&2
    exit 1
fi

# 3. Синхронизация каталога (требование 3, 8)
RSYNC_CMD=(rsync -avz --delete --chmod=D755,F644 -e "ssh -o BatchMode=yes -o ConnectTimeout=5")

if [[ ${DRY_RUN} -eq 1 ]]; then
    RSYNC_CMD+=(--dry-run)
fi

echo "Синхронизация ${LOCAL_DIR} на ${REMOTE}:${REMOTE_DIR}..."
"${RSYNC_CMD[@]}" "${LOCAL_DIR}" "${REMOTE}:${REMOTE_DIR}/"

# 4. При --dry-run — завершение с кодом 0 без проверки доступности (требование 1)
if [[ ${DRY_RUN} -eq 1 ]]; then
    echo "Dry-run завершен."
    exit 0
fi

# 5. Проверка доступности (требование 6)
# Используем -k, так как в учебном стенде самоподписанный сертификат, а WSL не доверяет ему
echo "Проверка доступности ${SITE_URL}..."
if ! curl -sSf -k -o /dev/null "${SITE_URL}"; then
    echo "Ошибка: ресурс ${SITE_URL} недоступен" >&2
    exit 1
fi

# 7. Вывод короткого хеша доставленного коммита (требование 7)
echo "Успешно доставлен коммит: $(git rev-parse --short HEAD)"
