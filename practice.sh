#!/bin/bash

LONG="host,user,help"

show_help() {
  echo "Использование: $0 [--host] [--user]"
  echo "  --host Вывести информацию о системе"
  echo "  --user Вывести информацию о пользователях системы"
  echo "  --help Показать краткую справку"
  exit 1
}

show_host() {
  echo "=== Информация о системе ==="

  echo "Кол-во ядер - $(nproc)"
  echo "Всего памяти - $(awk '/^MemTotal:/ {print $2}' /proc/meminfo) kB"
  echo "Использовано памяти: $(awk '/^MemTotal:/ {t=$2} /^MemAvailable:/ {a=$2} END {print t-a}' /proc/meminfo) kB"
  echo "Load Average: $(awk '{print $1, $2, $3}' /proc/loadavg)"
  echo "Текущее время: $(date +%H:%M:%S)"
  echo "Время работы системы: $(uptime -p)"
  echo "Информация по дискам в системе:"
  show_disk
  echo "Информация по сетевым интерфейсам:"
  ip -br -4 addr show
  awk 'NR > 2 {printf "Интерфейс: %s\n  Входящие:  Байт: %s | Пакет: %s | Ошибок: %s\n  Исходящие: Байт: %s | Пакет: %s | Ошибок: %s\n\n", $1, $2, $3, $4, $10, $11, $12}' /proc/net/dev
  echo "Список портов которые слушаются в системе:"
  ss -tuln | awk 'NR>1 {print $1, $5}' | nl
  echo ""
}

show_user() {
  echo "=== Информация о пользователях в системе ==="

  echo "Список всех пользователей в системе:"
  echo "$(cut -d: -f1 /etc/passwd | nl)"

  echo "Список всех root пользователей в системе:"
  echo "$(awk -F: '$3 == 0 {print $1}' /etc/passwd | nl)"
  echo "Список всех пользователей с правами sudo в системе:"
  echo "$(getent group sudo wheel 2>/dev/null | cut -d: -f4 | tr ',' '\n' | sort -u | nl)"
  echo "Список залогиненных пользователей в системе:"
  echo "$(w -h | awk '{print $1}' | sort -u | nl)"
  echo ""
}

show_disk() {
  echo "Список дисков в системе:"
  lsblk -d -n -o NAME,SIZE | while read -r name size; do
  hex_errors=$(cat /sys/class/block/"$name"/device/ioerr_cnt 2>/dev/null)
  if [ -n "$hex_errors" ]; then
    errors=$(( hex_errors ))
  else
    errors=0
  fi
  echo "  Диск: $name"
  echo "    Размер: $size"
  echo "    Кол-во ошибок: $errors"
  echo "    Разделы:"
  parts=$(lsblk -r -n -o NAME,MOUNTPOINT "/dev/$name" | grep -v "^$name\s\|^$name$")
  #parts=$(lsblk -r -n -o NAME "/dev/$name" | grep -v "^$name$")
  if [ -z "$parts" ]; then
    echo "    error: Диск не примонтирован"
  else
    echo "$parts" | while read -r part_name mount_point; do
      if [ -n "$mount_point" ]; then
        df_info=$(df -h "$mount_point" | tail -n 1 | awk '{print "Размер: " $2 ", Свободно: " $4}')
        echo "  -> Раздел: $part_name | Монтирование: $mount_point | $df_info"
      else
        echo "  -> Раздел: $part_name | Не примонтирован"
      fi
    done
  fi
done
}

if [ $# -eq 0 ]; then
  show_help
fi

if [[ " $@ " =~ " --help " ]]; then
    show_help
fi

for arg in "$@"; do
  if [[ "$arg" =~ ^-{1,2}$ ]]; then
    echo "error: Неверно использованы аргументы"
    show_help
  fi
done

PARSED=$(getopt --options "" --long "$LONG" -- "$@" 2&>/dev/null)

if [ $? -ne 0 ]; then
  echo "error: Неверно использованы аргументы"
  show_help
  exit 1
fi

[[ " $@ " =~ " --host " ]] && show_host
[[ " $@ " =~ " --user " ]] && show_user
