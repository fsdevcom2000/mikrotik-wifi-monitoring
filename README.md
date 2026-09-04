# WiFi Device Monitor for RouterOS

A simple WiFi device monitor for MikroTik RouterOS.

The script watches selected WiFi devices by MAC address and sends Telegram notifications when they connect or disconnect.

Supports both:

- `/interface wifi`
    
- `/interface wireless`
    

Tested on RouterOS 7.18.2 stable.

---

# 🇷🇺 Русский

Простой монитор WiFi устройств для MikroTik RouterOS.

Скрипт отслеживает выбранные устройства по MAC-адресу и отправляет уведомления в Telegram при подключении и отключении.

Поддерживаются оба варианта WiFi:

- `/interface wifi`
    
- `/interface wireless`
    

Протестировано на RouterOS 7.18.2 stable.

---

## Features

- Monitor WiFi devices by MAC address
    
- Telegram notifications on connect/disconnect
    
- Protection against false disconnect notifications
    
- Boot protection after router restart
    
- Automatic WiFi driver detection
    
- Supports both `wifi` and legacy `wireless`
    
- Protection against multiple script instances
    
- Persistent device state
    
- Automatic cleanup of old device states
    
- Error handling with `:onerror`
    
- Telegram errors do not stop the monitor
    
- MAC address cache for faster checks
    
- Safe initialization on the first run
    

---

## How it works

Devices are added to the WiFi Access List.

The comment must start with:

```text
MONITOR:
```

For example:

```text
MONITOR:Kitchen TV
MONITOR:Phone
MONITOR:Laptop
```

The text after `MONITOR:` is used as the device name in Telegram notifications.

The script:

1. Reads monitored devices from the Access List.
    
2. Detects the available WiFi driver.
    
3. Reads the registration table.
    
4. Builds a list of currently connected MAC addresses.
    
5. Checks monitored devices against this list.
    
6. Counts consecutive failed checks for missing devices.
    
7. Marks the device as offline after the configured threshold.
    
8. Marks it online again when it appears in the registration table.
    
9. Sends a Telegram notification when the state changes.
    
10. Saves the current state and failure counter.
    

---

## Requirements

- MikroTik RouterOS 7.x
    
- Tested on RouterOS 7.18.2 stable
    
- WiFi interface using either `wifi` or `wireless`
    
- Telegram bot
    
- Telegram sender script
    

The WiFi driver is detected automatically.

---

# Telegram Scripts

There are three Telegram-related scripts in the project.

### 1. `send_to_telegram`

The standard Telegram sender.

It uses RouterOS native URL conversion:

```routeros
:convert $strMessageText to=url
```

This works well for ASCII/Latin text.

For example:

```text
WiFi device connected
```

The script expects the message in:

```text
strMessageText
```

---

### 2. `cp1251_to_utf8_url`

A small helper script for Cyrillic text.

Cyrillic text read from RouterOS configuration fields behaves as CP1251-compatible bytes in the tested environment.

For example:

```text
Кухня
```

is read as:

```text
CA F3 E5 ED FF
```

The helper converts it to UTF-8 URL encoding:

```text
%D0%9A%D1%83%D1%85%D0%BD%D1%8F
```

Input:

```text
strInputText
```

Output:

```text
strEncodedText
```

The script also handles normal ASCII characters, spaces and special characters.

---

### 3. Telegram sender with Cyrillic support

There is also an alternative version of `send_to_telegram_rus`.

The difference is that it runs:

```text
cp1251_to_utf8_url
```

before sending the message.

For example:

```text
MONITOR:Кухня & TV
```

becomes:

```text
MONITOR%3a%D0%9A%D1%83%D1%85%D0%BD%D1%8F%20%26%20TV
```

This version should be used if device names or notification text can contain Cyrillic characters.

### Which version should I use?

| Script                             | Cyrillic | ASCII | Extra script         |
| ---------------------------------- | -------- | ----- | -------------------- |
| `send_to_telegram`                 | Limited  | Yes   | No                   |
| Alternative `send_to_telegram_rus` | Yes      | Yes   | `cp1251_to_utf8_url` |

If you only use English/Latin text, the standard sender is enough.

If you use Russian or other Cyrillic text, use the alternative sender together with `cp1251_to_utf8_url`.

---

## Telegram configuration

Edit the Telegram sender and set:

```routeros
:local tgBotToken "YOUR_BOT_TOKEN"
:local tgChatID "YOUR_CHAT_ID"
```

The sender uses the Telegram Bot API:

```text
https://api.telegram.org
```

The router must be able to connect to Telegram over HTTPS.

The actual Telegram request is used as the delivery attempt. There is no separate HTTPS check before every message.

---

# Installation

## 1. Create the monitor script

Create a new System Script in RouterOS and add the main monitoring script.

For example:

```text
monitor
```

---

## 2. Create the Telegram scripts

Create:

```text
send_to_telegram
```

If you need Cyrillic support, also create:

```text
cp1251_to_utf8_url
```

Then use the alternative Telegram sender.

---

## 3. Add devices to the Access List

Add the devices you want to monitor to the WiFi Access List.

Use the following format in the Comment field:

```text
MONITOR:Device Name
```

Examples:

```text
MONITOR:Kitchen TV
MONITOR:Phone
MONITOR:Laptop
```

The MAC address is used to identify the device.

---

## 4. Add a Scheduler

The default interval is 30 seconds.

Example:

```routeros
/system scheduler
add interval=30s on-event="/system script run monitor" name=monitor
```

The scheduler interval should match the `SchedulerInterval` value in the monitor script.

---

# Configuration

The monitor has a few main parameters.

## FailThreshold

Default:

```text
4
```

Number of consecutive checks where the device is missing before it is marked as offline.

With a 30 second scheduler:

```text
4 x 30 seconds = about 2 minutes
```

This helps to avoid false disconnect notifications.

---

## BootGracePeriod

Default:

```text
120
```

Time in seconds after router startup during which the monitor initializes its state.

This prevents false offline notifications after a reboot.

---

## SchedulerInterval

Default:

```text
30
```

Expected scheduler interval in seconds.

This value is also used by the execution lock.

---

# Execution Lock

The monitor uses an execution lock to prevent multiple instances from running at the same time.

This can happen if:

- the previous run takes longer than expected
    
- the script is started manually
    
- the scheduler starts while another instance is still running
    

The lock uses:

```text
:timestamp
```

and:

```text
:tonsec
```

The lock has an expiration time, so a broken or interrupted script run does not leave the monitor permanently locked.

---

# Error Handling

The main monitoring process is protected with RouterOS `:onerror`.

Telegram sending is also isolated from the main monitoring code.

If Telegram is unavailable, the monitor itself continues working.

RouterOS can show the actual `/tool fetch` error in the log, for example:

```text
Download from api.telegram.org FAILED: Idle timeout - connecting
```

The Telegram script also logs:

```text
SendTelegram failed: Telegram API unavailable or request failed
```

---

# State Management

The monitor stores state information globally.

For each device it keeps:

```text
<MAC>-state
```

and:

```text
<MAC>-fail
```

MAC addresses are converted to safe storage keys.

For example:

```text
AA:BB:CC:DD:EE:FF
```

becomes:

```text
AA-BB-CC-DD-EE-FF
```

This allows the monitor to keep the device state between script runs.

---

# First Run

On the first run the monitor initializes the state of all configured devices.

It does not immediately send offline notifications for devices that are currently not connected.

This prevents a lot of false notifications after:

- installation
    
- router reboot
    
- script restart
    
- configuration changes
    

---

# Automatic Cleanup

When a device is removed from the Access List, its old state is also removed.

This keeps the global state storage clean and prevents old device entries from accumulating.

---

# Example Notifications

English:

```text
🟢 Device connected: Kitchen TV
```

```text
🔴 Device disconnected: Kitchen TV
```

With Cyrillic:

```text
🟢 Устройство подключено: Кухня ТВ
```

```text
🔴 Устройство отключено: Кухня ТВ
```

For Cyrillic messages use:

```text
cp1251_to_utf8_url
```

together with the alternative Telegram sender.

---

# Compatibility Testing

The scripts were tested on RouterOS 7.18.2 stable.

The following RouterOS features were checked during development:

- Dynamic array keys
    
- Array key removal
    
- `foreach key,value`
    
- `registration-table as-value`
    
- `access-list as-value`
    
- `:totime`
    
- Global array replacement
    
- `:timestamp`
    
- `:tonsec`
    
- Timestamp arithmetic
    
- `:onerror`
    
- `:convert ... to=url`
    
- `:convert ... to=hex`
    
- Cyrillic text from RouterOS configuration fields
    
- CP1251-compatible byte conversion
    
- UTF-8 URL encoding
    
- Telegram HTTP POST requests
    
- Telegram error handling
    

Some RouterOS scripting constructs caused compatibility problems during testing, so the final version avoids them.

---

# 🇷🇺 Русский

## Возможности

- Мониторинг WiFi устройств по MAC-адресу
    
- Уведомления в Telegram при подключении и отключении
    
- Защита от ложных уведомлений об отключении
    
- Защита после перезагрузки роутера
    
- Автоматическое определение WiFi драйвера
    
- Поддержка `wifi` и старого `wireless`
    
- Защита от одновременного запуска нескольких экземпляров
    
- Сохранение состояния устройств
    
- Автоматическая очистка старых состояний
    
- Обработка ошибок через `:onerror`
    
- Ошибки Telegram не останавливают мониторинг
    
- Кэш MAC-адресов для более быстрой проверки
    
- Безопасная инициализация при первом запуске
    

---

## Как это работает

Устройства добавляются в WiFi Access List.

Комментарий должен начинаться с:

```text
MONITOR:
```

Например:

```text
MONITOR:Kitchen TV
MONITOR:Phone
MONITOR:Laptop
```

Текст после `MONITOR:` используется как имя устройства в уведомлении Telegram.

Скрипт:

1. Читает устройства из Access List.
    
2. Определяет доступный WiFi драйвер.
    
3. Читает registration table.
    
4. Создаёт список подключённых MAC-адресов.
    
5. Проверяет по нему отслеживаемые устройства.
    
6. Считает последовательные пропуски устройства.
    
7. После достижения заданного порога считает устройство отключённым.
    
8. При появлении устройства снова считает его подключённым.
    
9. Отправляет уведомление в Telegram.
    
10. Сохраняет состояние и счётчик ошибок.
    

---

## Требования

- MikroTik RouterOS 7.x
    
- Протестировано на RouterOS 7.18.2 stable
    
- WiFi интерфейс с `wifi` или `wireless`
    
- Telegram bot
    
- Telegram sender script
    

WiFi драйвер определяется автоматически.

---

# Telegram-скрипты

В проекте используются три скрипта, связанные с Telegram.

### 1. `send_to_telegram`

Обычная версия отправителя сообщений в Telegram.

Использует встроенное преобразование RouterOS:

```routeros
:convert $strMessageText to=url
```

Подходит для ASCII и Latin текста.

Сообщение передаётся через переменную:

```text
strMessageText
```

---

### 2. `cp1251_to_utf8_url`

Вспомогательный скрипт для работы с кириллицей.

Кириллица, прочитанная из конфигурационных полей RouterOS, в протестированном окружении ведёт себя как CP1251-совместимые байты.

Например:

```text
Кухня
```

читается как:

```text
CA F3 E5 ED FF
```

Скрипт преобразует эти байты в UTF-8 URL encoding:

```text
%D0%9A%D1%83%D1%85%D0%BD%D1%8F
```

Вход:

```text
strInputText
```

Выход:

```text
strEncodedText
```

---

### 3. Альтернативный Telegram sender с поддержкой кириллицы

Альтернативная версия `send_to_telegram_rus` сначала запускает:

```text
cp1251_to_utf8_url
```

а затем отправляет получившуюся строку в Telegram.

Например:

```text
MONITOR:Кухня & TV
```

преобразуется в:

```text
MONITOR%3a%D0%9A%D1%83%D1%85%D0%BD%D1%8F%20%26%20TV
```

Если названия устройств или сообщения содержат кириллицу, рекомендуется использовать именно эту версию.

### Какую версию использовать?

| Скрипт                                | Кириллица   | ASCII | Дополнительный скрипт |
| ------------------------------------- | ----------- | ----- | --------------------- |
| `send_to_telegram`                    | Ограниченно | Да    | Нет                   |
| Альтернативный `send_to_telegram_rus` | Да          | Да    | `cp1251_to_utf8_url`  |

Если используются только английские/Latin символы, достаточно обычного sender.

Если используются русские или другие кириллические символы, используйте альтернативный sender вместе с `cp1251_to_utf8_url`.

---

## Настройка Telegram

В Telegram sender укажите:

```routeros
:local tgBotToken "YOUR_BOT_TOKEN"
:local tgChatID "YOUR_CHAT_ID"
```

Для отправки используется:

```text
https://api.telegram.org
```

MikroTik должен иметь возможность установить HTTPS-соединение с Telegram.

Отдельная проверка Telegram перед каждой отправкой не выполняется. Сам запрос к Telegram API используется как попытка отправки сообщения.

---

# Установка

## 1. Создайте основной скрипт

Создайте System Script с кодом мониторинга.

Например:

```text
monitor
```

---

## 2. Создайте Telegram-скрипты

Создайте:

```text
send_to_telegram
```

Если нужна поддержка кириллицы:

```text
cp1251_to_utf8_url
```

После этого используйте альтернативную версию Telegram sender.

---

## 3. Добавьте устройства в Access List

Добавьте нужные устройства в WiFi Access List.

В поле Comment используйте:

```text
MONITOR:Device Name
```

Например:

```text
MONITOR:Kitchen TV
MONITOR:Phone
MONITOR:Laptop
```

MAC-адрес используется для идентификации устройства.

---

## 4. Добавьте Scheduler

По умолчанию используется интервал 30 секунд.

Пример:

```routeros
/system scheduler
add interval=30s on-event="/system script run monitor" name=monitor
```

Интервал Scheduler должен соответствовать значению `SchedulerInterval` в основном скрипте.

---

# Настройка параметров

## FailThreshold

По умолчанию:

```text
4
```

Количество последовательных проверок, во время которых устройство отсутствует, прежде чем оно будет признано отключённым.

При интервале 30 секунд:

```text
4 x 30 секунд = примерно 2 минуты
```

Это помогает избежать ложных уведомлений.

---

## BootGracePeriod

По умолчанию:

```text
120
```

Время в секундах после загрузки роутера.

В этот период скрипт инициализирует состояние устройств и не отправляет ложные уведомления об отключении.

---

## SchedulerInterval

По умолчанию:

```text
30
```

Интервал запуска скрипта в секундах.

Это значение также используется execution lock.

---

# Execution Lock

Скрипт использует блокировку выполнения, чтобы несколько экземпляров не работали одновременно.

Это может произойти, например, если:

- предыдущий запуск ещё не завершился;
    
- скрипт запустили вручную;
    
- Scheduler запустил новый экземпляр до завершения предыдущего.
    

Для работы блокировки используются:

```text
:timestamp
```

и:

```text
:tonsec
```

У блокировки есть время истечения, поэтому зависший или прерванный запуск не оставляет монитор заблокированным навсегда.

---

# Обработка ошибок

Основной процесс защищён через `:onerror`.

Ошибки Telegram отделены от основного процесса мониторинга.

Если Telegram недоступен, мониторинг WiFi продолжает работать.

В логах RouterOS может появиться исходная ошибка `/tool fetch`, например:

```text
Download from api.telegram.org FAILED: Idle timeout - connecting
```

Telegram sender дополнительно пишет:

```text
SendTelegram failed: Telegram API unavailable or request failed
```

---

# Управление состоянием

Скрипт хранит состояние устройств глобально.

Для каждого устройства используются:

```text
<MAC>-state
```

и:

```text
<MAC>-fail
```

MAC-адрес преобразуется в ключ для хранения.

Например:

```text
AA:BB:CC:DD:EE:FF
```

становится:

```text
AA-BB-CC-DD-EE-FF
```

Благодаря этому состояние сохраняется между запусками скрипта.

---

# Первый запуск

При первом запуске скрипт инициализирует состояние всех настроенных устройств.

Он не отправляет сразу уведомления об отключении устройств, которые в данный момент не подключены.

Это предотвращает большое количество ложных сообщений после:

- установки
    
- перезагрузки роутера
    
- перезапуска скрипта
    
- изменения конфигурации
    

---

# Автоматическая очистка

Если устройство удалить из Access List, его старое состояние также удаляется.

Это предотвращает накопление старых записей.

---

# Примеры уведомлений

На английском:

```text
🟢 Device connected: Kitchen TV
```

```text
🔴 Device disconnected: Kitchen TV
```

С кириллицей:

```text
🟢 Устройство подключено: Кухня TV
```

```text
🔴 Устройство отключено: Кухня TV
```

Для кириллицы используйте:

```text
cp1251_to_utf8_url
```

вместе с альтернативным Telegram sender.

---

# Тестирование совместимости

Скрипты протестированы на RouterOS 7.18.2 stable.

Во время разработки отдельно проверялись:

- динамические ключи массивов
    
- удаление ключей массивов
    
- `foreach key,value`
    
- `registration-table as-value`
    
- `access-list as-value`
    
- `:totime`
    
- замена глобального массива
    
- `:timestamp`
    
- `:tonsec`
    
- арифметика timestamp
    
- `:onerror`
    
- `:convert ... to=url`
    
- `:convert ... to=hex`
    
- кириллица из конфигурационных полей RouterOS
    
- преобразование CP1251-совместимых байтов
    
- UTF-8 URL encoding
    
- HTTP POST запросы к Telegram
    
- обработка ошибок Telegram
    

Некоторые конструкции RouterOS во время тестирования показали проблемы совместимости, поэтому в финальной версии они не используются.

