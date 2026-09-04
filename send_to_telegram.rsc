# ==========================================
#
# Telegram Message Sender for RouterOS
# Sends notifications via Telegram Bot API
# Requires parameter: strMessageText
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

    :local strSendText [:convert $strMessageText to=url]

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

    # Generic script error handler

    :log error "SendTelegram failed"
}