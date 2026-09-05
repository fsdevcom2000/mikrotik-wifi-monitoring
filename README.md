# WiFi Device Monitor for RouterOS

A simple WiFi device monitor for MikroTik RouterOS.

The script watches selected WiFi devices by MAC address and sends Telegram notifications when they connect or disconnect.

Supports both:

- `/interface wifi`
    
- `/interface wireless`
    

Tested on RouterOS 7.18.2 stable.

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


