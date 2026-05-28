# WiFi Device Monitor for RouterOS

Monitor Wi-Fi devices on MikroTik and receive Telegram notifications when devices connect or disconnect from Wi-Fi.

Supports both **RouterOS WiFi (`/interface wifi`)** and **legacy Wireless (`/interface wireless`)** drivers.


# Монитор Wi-Fi-устройств для RouterOS

Мониторинг Wi-Fi-устройств на MikroTik и получение уведомлений в Telegram при подключении или отключении устройств от Wi-Fi.

Поддерживает как драйверы WiFi RouterOS (`/interface wifi`), так и устаревшие драйверы Wireless (`/interface wireless`).

---

# 🇬🇧 English

## Features

- Wi-Fi device monitoring by MAC address
    
- Telegram notifications for connect/disconnect events
    
- False positive protection (`FailThreshold`)
    
- Boot protection after router restart (`BootGracePeriod`)
    
- Supports RouterOS WiFi and legacy Wireless drivers
    
- Concurrent execution protection
    
- Automatic stale state cleanup
    

---

## How it works

The script checks devices from the **Access List** and verifies whether they exist in the **registration-table**.

If a device disappears for several checks in a row, a disconnect notification is sent.

When the device comes back online, a reconnect notification is sent.

---

## Requirements

### 1. RouterOS

Supported:

- RouterOS 6 (`wireless`)
    
- RouterOS 7 (`wifi` package)
    

---

### 2. Telegram script

Before using this monitor, a script named:

```routeros
send_to_telegram
```

must exist.

The script must accept the parameter:

```routeros
strMessageText
```

Example:

```routeros
$SendTelegramMessage strMessageText="Hello"
```

---

## Installation

### 1. Create script

Go to:

```text
System → Scripts
```

Create a new script:

```text
monitor
```

Paste the script code.

---

### 2. Add devices to Access List

Go to:

#### RouterOS 7 (wifi)

```text
WiFi → Access List
```

#### RouterOS 6 / wireless

```text
Wireless → Access List
```

Add devices you want to monitor.

Use the comment format:

```text
MONITOR:Device Name
```

Examples:

```text
MONITOR:John Phone
MONITOR:Office Laptop
MONITOR:Front Door Camera
```

Only entries with the prefix:

```text
MONITOR:
```

will be monitored.

---

### 3. Configure Scheduler

Go to:

```text
System → Scheduler
```

Create a task:

**Name**

```text
monitor
```

**Interval**

```text
30s
```

**On Event**

```routeros
/system script run monitor
```

---

## Configuration

Available settings:

```routeros
:local FailThreshold 4
:local BootGracePeriod 120
:local SchedulerInterval 30
```

### FailThreshold

Number of failed checks before a device is considered offline.

Example:

```text
FailThreshold = 4
Scheduler = 30 sec
```

Device will be marked offline after about:

```text
2 minutes
```

---

### BootGracePeriod

Delay after router reboot.

Prevents false offline alerts while Wi-Fi services are still starting.

Example:

```text
120
```

= 120 seconds.

---

### SchedulerInterval

Scheduler interval in seconds.

Must match your scheduler configuration.

Example:

```text
30
```

if the scheduler runs every 30 seconds.

---

## Example notifications

Connected:

```text
O - John Phone connected to Wi-Fi (MikroTik)
```

Disconnected:

```text
X - John Phone disconnected from Wi-Fi (MikroTik)
```

---

# 🇷🇺 Русский

## Возможности

- Мониторинг Wi-Fi устройств по MAC-адресу
    
- Уведомления в Telegram о подключении и отключении устройств
    
- Защита от ложных срабатываний (`FailThreshold`)
    
- Защита после перезагрузки роутера (`BootGracePeriod`)
    
- Поддержка RouterOS 6/7 (`wireless` и `wifi`)
    
- Защита от одновременного запуска
    
- Автоматическая очистка старых данных
    

---

## Как это работает

Скрипт проверяет список устройств в **Access List** и отслеживает их наличие в **registration-table**.

Если устройство исчезает из сети несколько проверок подряд — отправляется уведомление об отключении.

Если устройство появляется снова — отправляется уведомление о подключении.

---

## Требования

### 1. RouterOS

Поддерживаются:

- RouterOS 6 (`wireless`)
    
- RouterOS 7 (`wifi` package)
    

---

### 2. Telegram скрипт

Перед использованием должен существовать скрипт:

```routeros
send_to_telegram
```

Скрипт должен принимать параметр:

```routeros
strMessageText
```

Пример вызова:

```routeros
$SendTelegramMessage strMessageText="Hello"
```

---

## Установка

### 1. Создайте script

Перейдите:

```text
System → Scripts
```

Создайте новый script, например:

```text
monitor
```

Вставьте код скрипта.

---

### 2. Добавьте устройства в Access List

Перейдите:

#### RouterOS 7 (wifi)

```text
WiFi → Access List
```

#### RouterOS 6 / wireless

```text
Wireless → Access List
```

Добавьте устройство.

Обязательно используйте комментарий в формате:

```text
MONITOR:Device Name
```

Примеры:

```text
MONITOR:John Phone
MONITOR:Office Laptop
MONITOR:Front Door Camera
```

Только записи с префиксом:

```text
MONITOR:
```

будут отслеживаться.

---

### 3. Настройте Scheduler

Перейдите:

```text
System → Scheduler
```

Создайте задачу:

**Name**

```text
monitor
```

**Interval**

```text
30s
```

**On Event**

```routeros
/system script run monitor
```

---

## Настройка параметров

В начале скрипта доступны настройки:

```routeros
:local FailThreshold 4
:local BootGracePeriod 120
:local SchedulerInterval 30
```

### FailThreshold

Количество неудачных проверок перед сообщением об отключении.

Пример:

```text
FailThreshold = 4
Scheduler = 30 sec
```

Устройство будет считаться offline примерно через:

```text
2 минуты
```

---

### BootGracePeriod

Время ожидания после перезагрузки роутера.

Нужно, чтобы избежать ложных уведомлений во время запуска Wi-Fi.

Пример:

```text
120
```

= 120 секунд.

---

### SchedulerInterval

Интервал запуска scheduler в секундах.

Должен совпадать с настройкой Scheduler.

Пример:

```text
30
```

если scheduler запускается каждые 30 секунд.

---

## Пример уведомлений

Подключение:

```text
O - John Phone connected to Wi-Fi (MikroTik)
```

Отключение:

```text
X - John Phone disconnected from Wi-Fi (MikroTik)
```

