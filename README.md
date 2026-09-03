# WiFi Device Monitor for RouterOS

Monitor Wi-Fi devices on MikroTik routers and receive Telegram notifications when devices connect or disconnect from Wi-Fi.

The script supports both RouterOS WiFi (`/interface wifi`) and legacy Wireless (`/interface wireless`) drivers.

**Tested on RouterOS 7.18.2 (stable).**

---

# Монитор Wi-Fi-устройств для RouterOS

Мониторинг Wi-Fi-устройств на MikroTik и получение уведомлений в Telegram при подключении или отключении устройств от Wi-Fi.

Скрипт поддерживает как RouterOS WiFi (`/interface wifi`), так и legacy Wireless (`/interface wireless`).

**Протестировано на RouterOS 7.18.2 (stable).**

---

# 🇬🇧 English

## Features

* Wi-Fi device monitoring by MAC address
* Telegram notifications for connect/disconnect events
* False positive protection using consecutive failure threshold
* Boot protection after router restart
* Automatic WiFi driver detection
* Supports RouterOS WiFi and legacy Wireless drivers
* Concurrent execution protection with fail-safe lock expiration
* Persistent device state between scheduler runs
* Automatic stale state cleanup
* Global error handling with RouterOS `:onerror`
* Telegram error isolation
* Optimized online-device detection using an in-memory MAC cache
* Safe first-run initialization without unnecessary notifications

---

## How it works

The script monitors devices configured in the **Access List** and checks whether their MAC addresses are present in the **registration-table**.

The registration table is first converted into an in-memory MAC cache. Each monitored device is then checked against this cache.

If a device is missing for several consecutive checks, it is considered offline and a disconnect notification is sent.

When the device appears again, it is marked as online and a reconnect notification is sent.

The device state and failure counter are stored globally between scheduler executions.

---

## Requirements

### RouterOS

The final version has been tested on:

```text
RouterOS 7.18.2 (stable)
```

The script automatically detects the available WiFi interface implementation:

```text
/interface wifi
```

or:

```text
/interface wireless
```

> Compatibility with other RouterOS versions may depend on the available scripting and WiFi interface features. RouterOS 7.18.2 is the currently tested version.

---

### Telegram script

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

### 1. Create the monitor script

Go to:

```text
System → Scripts
```

Create a new script, for example:

```text
monitor
```

Paste the WiFi Device Monitor script code.

---

### 2. Add devices to Access List

Go to:

#### RouterOS WiFi

```text
WiFi → Access List
```

#### Legacy Wireless

```text
Wireless → Access List
```

Add the devices you want to monitor.

Use the following comment format:

```text
MONITOR:Device Name
```

Examples:

```text
MONITOR:John Phone
MONITOR:Office Laptop
MONITOR:Front Door Camera
```

Only Access List entries with the prefix:

```text
MONITOR:
```

will be monitored.

If the device name is empty, its MAC address will be used as the device name.

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

The scheduler interval should match the `SchedulerInterval` value in the script.

---

## Configuration

The main configuration is located at the beginning of the script:

```routeros
:local FailThreshold 4
:local BootGracePeriod 120
:local SchedulerInterval 30
```

### FailThreshold

Number of consecutive failed checks before a device is considered offline.

Example:

```text
FailThreshold = 4
Scheduler = 30 sec
```

The device will be considered offline after approximately:

```text
2 minutes
```

The exact time depends on when the device disappears relative to the scheduler cycle.

This mechanism prevents temporary WiFi interruptions from generating false disconnect notifications.

---

### BootGracePeriod

Grace period after router startup.

During this period the monitor does not process devices.

Example:

```text
120
```

= 120 seconds.

This prevents false offline notifications while the router and WiFi interfaces are still initializing.

---

### SchedulerInterval

Scheduler interval in seconds.

This value should match the actual RouterOS Scheduler interval.

Example:

```text
30
```

when the scheduler runs every 30 seconds.

The value is also used by the execution lock to determine its fail-safe expiration period.

---

## Execution Lock

The monitor uses a global execution lock to prevent multiple instances from running simultaneously.

The lock is based on:

```text
:timestamp
:tonsec
```

rather than the current time of day.

The lock automatically expires after two scheduler intervals.

This provides a fail-safe mechanism in case a previous execution is interrupted unexpectedly.

---

## Error Handling

The main monitoring process is protected by RouterOS `:onerror`.

Unexpected errors are written to the RouterOS log.

Telegram errors are handled separately so that a temporary Telegram failure does not terminate the monitoring process.

---

## State Management

Each monitored device maintains:

```text
<MAC>-state
<MAC>-fail
```

Example:

```text
AA-BB-CC-DD-EE-FF-state
AA-BB-CC-DD-EE-FF-fail
```

The MAC address is converted into a safe storage key by replacing `:` with `-`.

On the first run:

* an online device is initialized as `online`;
* an offline device is initialized as `offline`;
* no Telegram notification is sent during initial state detection.

---

## Automatic Cleanup

When a device is removed from the monitored Access List, its old state entries are automatically removed from the global storage.

The script rebuilds the storage array using only active devices instead of modifying the array while iterating over it.

---

## Example Notifications

Connected:

```text
O - John Phone connected to Wi-Fi (MikroTik)
```

Disconnected:

```text
X - John Phone disconnected from Wi-Fi (MikroTik)
```

---

## Compatibility Testing

The script was tested on:

```text
RouterOS 7.18.2 (stable)
```

The compatibility tests covered:

* dynamic array keys
* array key removal
* `foreach key,value`
* `registration-table as-value`
* `access-list as-value`
* `:totime` uptime conversion
* array rebuilding
* global array replacement
* `:timestamp`
* `:tonsec`
* timestamp arithmetic
* `:onerror`

The final production version does not use the RouterOS constructs that were confirmed to fail during testing on RouterOS 7.18.2.

---

# 🇷🇺 Русский

## Возможности

* Мониторинг Wi-Fi-устройств по MAC-адресу
* Уведомления в Telegram о подключении и отключении устройств
* Защита от ложных срабатываний через последовательные неудачные проверки
* Защита после перезагрузки роутера
* Автоматическое определение используемого WiFi-драйвера
* Поддержка RouterOS WiFi и legacy Wireless
* Защита от одновременного запуска с fail-safe блокировкой
* Сохранение состояния устройств между запусками scheduler
* Автоматическая очистка устаревших данных
* Глобальная обработка ошибок через RouterOS `:onerror`
* Изоляция ошибок Telegram
* Оптимизированное определение подключённых устройств через кэш MAC-адресов
* Безопасная инициализация устройств при первом запуске без лишних уведомлений

---

## Как это работает

Скрипт отслеживает устройства, добавленные в **Access List**, и проверяет наличие их MAC-адресов в **registration-table**.

Сначала registration table преобразуется в кэш MAC-адресов. Затем каждое контролируемое устройство проверяется по этому кэшу.

Если устройство отсутствует несколько последовательных проверок, оно считается отключённым и отправляется уведомление в Telegram.

Когда устройство снова появляется в registration table, оно считается подключённым и отправляется уведомление о восстановлении соединения.

Состояние устройства и счётчик ошибок сохраняются в глобальном хранилище между запусками scheduler.

---

## Требования

### RouterOS

Финальная версия протестирована на:

```text
RouterOS 7.18.2 (stable)
```

Скрипт автоматически определяет доступную реализацию WiFi:

```text
/interface wifi
```

или:

```text
/interface wireless
```

> Совместимость с другими версиями RouterOS может зависеть от доступных возможностей scripting и WiFi-интерфейсов. На данный момент протестированной версией является RouterOS 7.18.2.

---

### Telegram скрипт

Перед использованием должен существовать скрипт:

```text
send_to_telegram
```

Он должен принимать параметр:

```text
strMessageText
```

Пример вызова:

```routeros
$SendTelegramMessage strMessageText="Hello"
```

---

## Установка

### 1. Создайте monitor script

Перейдите:

```text
System → Scripts
```

Создайте новый script, например:

```text
monitor
```

Вставьте код WiFi Device Monitor.

---

### 2. Добавьте устройства в Access List

#### RouterOS WiFi

```text
WiFi → Access List
```

#### Legacy Wireless

```text
Wireless → Access List
```

Добавьте устройства, которые необходимо отслеживать.

Используйте формат комментария:

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

Если имя устройства не указано, в качестве имени будет использоваться его MAC-адрес.

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

Интервал Scheduler должен соответствовать значению `SchedulerInterval` в скрипте.

---

## Настройка параметров

В начале скрипта доступны основные параметры:

```routeros
:local FailThreshold 4
:local BootGracePeriod 120
:local SchedulerInterval 30
```

### FailThreshold

Количество последовательных неудачных проверок перед тем, как устройство будет считаться отключённым.

Пример:

```text
FailThreshold = 4
Scheduler = 30 sec
```

Устройство будет считаться отключённым примерно через:

```text
2 минуты
```

Точное время зависит от момента исчезновения устройства относительно очередного запуска scheduler.

Этот механизм предотвращает ложные уведомления при кратковременных проблемах с Wi-Fi.

---

### BootGracePeriod

Период ожидания после запуска роутера.

В течение этого времени монитор не выполняет обработку устройств.

Пример:

```text
120
```

= 120 секунд.

Это предотвращает ложные уведомления во время запуска роутера и WiFi-интерфейсов.

---

### SchedulerInterval

Интервал запуска Scheduler в секундах.

Значение должно соответствовать фактическому интервалу RouterOS Scheduler.

Пример:

```text
30
```

если scheduler запускается каждые 30 секунд.

Это значение также используется execution lock для расчёта периода его автоматического истечения.

---

## Execution Lock

Монитор использует глобальную блокировку выполнения для предотвращения одновременного запуска нескольких экземпляров.

Для lock используются:

```text
:timestamp
:tonsec
```

вместо текущего времени суток.

Lock автоматически истекает через два интервала Scheduler.

Это обеспечивает fail-safe поведение, если предыдущий запуск был неожиданно прерван.

---

## Обработка ошибок

Основной процесс мониторинга защищён через RouterOS `:onerror`.

Непредвиденные ошибки записываются в системный лог RouterOS.

Ошибки Telegram обрабатываются отдельно, поэтому временная проблема с Telegram не должна останавливать сам мониторинг.

---

## Управление состоянием

Для каждого устройства сохраняются:

```text
<MAC>-state
<MAC>-fail
```

Например:

```text
AA-BB-CC-DD-EE-FF-state
AA-BB-CC-DD-EE-FF-fail
```

MAC-адрес преобразуется в безопасный ключ хранения: символы `:` заменяются на `-`.

При первом запуске:

* подключённое устройство получает состояние `online`;
* отключённое устройство получает состояние `offline`;
* Telegram-уведомление при первоначальном определении состояния не отправляется.

---

## Автоматическая очистка

Если устройство удаляется из отслеживаемого Access List, его старые записи автоматически удаляются из глобального хранилища.

Скрипт пересобирает массив хранилища только из актуальных устройств вместо изменения массива непосредственно во время его обхода.

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

---

## Тестирование совместимости

Скрипт протестирован на:

```text
RouterOS 7.18.2 (stable)
```

Тестами на совместимость были проверены:

* dynamic array keys
* удаление ключей массива
* `foreach key,value`
* `registration-table as-value`
* `access-list as-value`
* преобразование uptime через `:totime`
* пересборка массивов
* замена глобального массива
* `:timestamp`
* `:tonsec`
* арифметика timestamp
* `:onerror`

Финальная production-версия не использует конструкции RouterOS, которые во время тестирования были подтверждены как неработающие на RouterOS 7.18.2.
