# ==================================================================
#
# WiFi Device Monitor for RouterOS
# Monitors Wi-Fi devices via access-list
# Requires script: send_to_telegram
# Comment format for Access-List:
# MONITOR:Device Name
#
# Author: fsdevcom2000
# Github: https://github.com/fsdevcom2000/mikrotik-wifi-monitoring
#
# ==================================================================

# CONFIG

:local FailThreshold 4
:local BootGracePeriod 120
:local SchedulerInterval 30

:local RouterName [/system identity get name]
:local CommentFilter "MONITOR:"

# LOCK (fail-safe)

:global WifiMonitorLockUntil

:if ([:typeof $WifiMonitorLockUntil] = "nothing") do={
    :set WifiMonitorLockUntil 0s
}

:local CurrentTime [:totime [/system clock get time]]

:if ($WifiMonitorLockUntil > $CurrentTime) do={
    :log warning "WiFi Monitor: already running, skipping execution."
    :error "Already running"
}

# lock for 2 scheduler intervals
:set WifiMonitorLockUntil ($CurrentTime + ($SchedulerInterval * 2))

# SAFE WRAPPER

:do {

    # BOOT GRACE PERIOD

    :local Uptime [/system resource get uptime]

    :if ([:totime $Uptime] < ($BootGracePeriod * 1s)) do={

        :log info ("WiFi Monitor: boot grace active (" . $Uptime . ")")

        :set WifiMonitorLockUntil 0s
        :error "Boot grace period active"
    }

    # TELEGRAM SCRIPT

    :local ScriptObj [/system script find where name="send_to_telegram"]

    :if ([:len $ScriptObj] = 0) do={
        :log error "WiFi Monitor: telegram script missing"

        :set WifiMonitorLockUntil 0s
        :error "Missing telegram script"
    }

    :local SendTelegramMessage [:parse [/system script get $ScriptObj source]]

    # GLOBAL STORAGE

    :global WifiMonitorStorage

    :if ([:typeof $WifiMonitorStorage] != "array") do={
        :set WifiMonitorStorage [:toarray ""]
    }

    # DRIVER DETECT

    :local RegTable
    :local DeviceList
    :local UseWifi false

    :do {
        /interface wifi print count-only
        :set UseWifi true
    } on-error={
        :set UseWifi false
    }

    :if ($UseWifi = true) do={

        :set RegTable [/interface wifi registration-table print as-value]
        :set DeviceList [/interface wifi access-list print as-value]

    } else={

        :set RegTable [/interface wireless registration-table print as-value]
        :set DeviceList [/interface wireless access-list print as-value]
    }

    # ONLINE CACHE

    :local OnlineMacs [:toarray ""]

    :foreach r in=$RegTable do={

        :local mac ($r->"mac-address")

        :if ([:typeof $mac] != "nothing" && [:len $mac] > 0) do={
            :set ($OnlineMacs->$mac) true
        }
    }

    # ACTIVE KEYS

    :local ActiveKeys [:toarray ""]

    # DEVICE LOOP

    :foreach dev in=$DeviceList do={

        :local DeviceMac ($dev->"mac-address")
        :local RawComment ($dev->"comment")

        :if ([:len $DeviceMac] = 0) do={
            :continue
        }

        # FILTER COMMENT

        :if ([:len $RawComment] < [:len $CommentFilter]) do={
            :continue
        }

        :if ([:pick $RawComment 0 [:len $CommentFilter]] != $CommentFilter) do={
            :continue
        }

        # NAME

        :local DeviceName [:pick $RawComment [:len $CommentFilter] [:len $RawComment]]

        :if ($DeviceName = "") do={
            :set DeviceName $DeviceMac
        }

        # KEY (MAC → safe key)

        :local Key ""

        :for i from=0 to=([:len $DeviceMac] - 1) do={

            :local ch [:pick $DeviceMac $i]

            :if ($ch = ":") do={
                :set ch "-"
            }

            :set Key ($Key . $ch)
        }

        :local StateKey ($Key . "-state")
        :local FailKey ($Key . "-fail")

        :set ($ActiveKeys->$StateKey) true
        :set ($ActiveKeys->$FailKey) true

        # STATE

        :local State ($WifiMonitorStorage->$StateKey)
        :local Fail ($WifiMonitorStorage->$FailKey)

        :if ([:typeof $State] = "nothing") do={
            :set State "unknown"
        }

        :if ([:typeof $Fail] = "nothing") do={
            :set Fail 0
        }

        # ONLINE CHECK

        :local Online false

        :if (($OnlineMacs->$DeviceMac) = true) do={
            :set Online true
        }

        # FIRST RUN INIT

        :if ($State = "unknown") do={

            :if ($Online = true) do={

                :set ($WifiMonitorStorage->$StateKey) "online"
                :set ($WifiMonitorStorage->$FailKey) 0

            } else={

                :set ($WifiMonitorStorage->$StateKey) "offline"
                :set ($WifiMonitorStorage->$FailKey) $FailThreshold
            }

            :log info ("WiFi Monitor init: " . $DeviceName)

        } else={

            # DEVICE ONLINE

            :if ($Online = true) do={

                :set Fail 0
                :set ($WifiMonitorStorage->$FailKey) 0

                :if ($State != "online") do={

                    :set ($WifiMonitorStorage->$StateKey) "online"

                    :local msg (
                        "O " . $DeviceName .
                        " connected to Wi-Fi (" .
                        $RouterName . ")"
                    )

                    $SendTelegramMessage strMessageText=$msg

                    :log info (
                        "WiFi UP: " .
                        $DeviceName
                    )
                }

            } else={

                # DEVICE OFFLINE

                :set Fail ($Fail + 1)
                :set ($WifiMonitorStorage->$FailKey) $Fail

                :log info (
                    "WiFi fail " .
                    $DeviceName .
                    " = " .
                    $Fail .
                    "/" .
                    $FailThreshold
                )

                :if ($Fail >= $FailThreshold) do={

                    :if ($State != "offline") do={

                        :set ($WifiMonitorStorage->$StateKey) "offline"

                        :local msg (
                            "X " . $DeviceName .
                            " disconnected from Wi-Fi (" .
                            $RouterName . ")"
                        )

                        $SendTelegramMessage strMessageText=$msg

                        :log warning (
                            "WiFi DOWN: " .
                            $DeviceName
                        )
                    }
                }
            }
        }
    }

    # GARBAGE COLLECTION

    :foreach key,value in=$WifiMonitorStorage do={

        :if ([:typeof ($ActiveKeys->$key)] = "nothing") do={

            :unset ($WifiMonitorStorage->$key)

            :log info (
                "WiFi Monitor: removed stale key " .
                $key
            )
        }
    }

} on-error={

    :log error (
        "WiFi Monitor failed: " .
        $message
    )
}

# RELEASE LOCK

:set WifiMonitorLockUntil 0s