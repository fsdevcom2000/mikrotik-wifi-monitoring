# ==========================================
#
# CP1251 to UTF-8 URL Encoder for RouterOS
#
# Converts text stored in RouterOS CP1251 encoding
# to UTF-8 percent-encoded format suitable for
# HTTP requests and Telegram Bot API.
#
# Input variable:  strInputText
# Output variable: strEncodedText
#
# Supports Cyrillic characters, spaces and
# special characters used in URL/form encoding.
#
# Author: fsdevcom2000
# Github: https://github.com/fsdevcom2000/mikrotik-wifi-monitoring
#
# ==========================================

:global strInputText
:global strEncodedText ""

:local cyrMap {
    "a8"="%D0%81";
    "b8"="%D1%91";

    "c0"="%D0%90";
    "c1"="%D0%91";
    "c2"="%D0%92";
    "c3"="%D0%93";
    "c4"="%D0%94";
    "c5"="%D0%95";
    "c6"="%D0%96";
    "c7"="%D0%97";
    "c8"="%D0%98";
    "c9"="%D0%99";
    "ca"="%D0%9A";
    "cb"="%D0%9B";
    "cc"="%D0%9C";
    "cd"="%D0%9D";
    "ce"="%D0%9E";
    "cf"="%D0%9F";

    "d0"="%D0%A0";
    "d1"="%D0%A1";
    "d2"="%D0%A2";
    "d3"="%D0%A3";
    "d4"="%D0%A4";
    "d5"="%D0%A5";
    "d6"="%D0%A6";
    "d7"="%D0%A7";
    "d8"="%D0%A8";
    "d9"="%D0%A9";
    "da"="%D0%AA";
    "db"="%D0%AB";
    "dc"="%D0%AC";
    "dd"="%D0%AD";
    "de"="%D0%AE";
    "df"="%D0%AF";

    "e0"="%D0%B0";
    "e1"="%D0%B1";
    "e2"="%D0%B2";
    "e3"="%D0%B3";
    "e4"="%D0%B4";
    "e5"="%D0%B5";
    "e6"="%D0%B6";
    "e7"="%D0%B7";
    "e8"="%D0%B8";
    "e9"="%D0%B9";
    "ea"="%D0%BA";
    "eb"="%D0%BB";
    "ec"="%D0%BC";
    "ed"="%D0%BD";
    "ee"="%D0%BE";
    "ef"="%D0%BF";

    "f0"="%D1%80";
    "f1"="%D1%81";
    "f2"="%D1%82";
    "f3"="%D1%83";
    "f4"="%D1%84";
    "f5"="%D1%85";
    "f6"="%D1%86";
    "f7"="%D1%87";
    "f8"="%D1%88";
    "f9"="%D1%89";
    "fa"="%D1%8A";
    "fb"="%D1%8B";
    "fc"="%D1%8C";
    "fd"="%D1%8D";
    "fe"="%D1%8E";
    "ff"="%D1%8F"
}

:local hex [:convert $strInputText to=hex]
:local result ""

:for i from=0 to=([:len $hex] - 2) step=2 do={

    :local byte [:pick $hex $i ($i + 2)]
    :local mapped ($cyrMap->$byte)

    :if ([:typeof $mapped] != "nothing") do={

        :set result ($result . $mapped)

    } else={

        :local char [:pick $strInputText ($i / 2) (($i / 2) + 1)]
        :set result ($result . [:convert $char to=url])
    }
}

:set strEncodedText $result