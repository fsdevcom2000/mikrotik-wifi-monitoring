# ==========================================
#
# Telegram Message Sender for RouterOS
# Sends notifications via Telegram Bot API
# Requires parameter: strMessageText
#
# Alternative version with Cyrillic encoding support.
#
# Difference from the main version:
# Uses the external cp1251_to_utf8_url script
# to convert Cyrillic text from RouterOS CP1251
# encoding to UTF-8 URL encoding before sending
# the message to Telegram.
#
# The main version uses only:
# :convert $strMessageText to=url
#
# Author: fsdevcom2000
# Github: https://github.com/fsdevcom2000/mikrotik-wifi-monitoring
#
# ==========================================


:do {

    # Telegram configuration

    :local tgBotToken "1234567890:AAbbccddeeff"
    :local tgChatID "12345678"
    :local strParseMode "HTML"

    # Message text received from caller script

    :global strInputText
    :global strEncodedText

    :set strInputText $strMessageText

    /system script run cp1251_to_utf8_url

    :local strSendText $strEncodedText

    # Check internet connectivity using Google DNS

    :local pingResult [/ping 8.8.8.8 count=3]

    :if ($pingResult > 0) do={

        # Send message via Telegram Bot API

        /tool fetch \
            url=("https://api.telegram.org/bot" . $tgBotToken . "/sendMessage") \
            http-method=post \
            http-data=("chat_id=" . $tgChatID . "&text=" . $strSendText . "&parse_mode=" . $strParseMode . "&disable_web_page_preview=true") \
            output=none

        :log info ("Telegram message sent: " . $strSendText)

    } else={

        # Internet unavailable

        :log warning "No internet connection. Telegram message was not sent"
    }

} on-error={

    # Telegram API or other script error

    :log error "SendTelegram failed: Telegram API unavailable or request failed"
}
