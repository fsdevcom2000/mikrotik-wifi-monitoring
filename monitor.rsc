# ==================================================================
#
# WiFi Device Monitor for RouterOS
#
# Monitors Wi-Fi devices via access-list and registration-table.
#
# Requires script:
#   send_to_telegram
#
# Access-List comment format:
#   MONITOR:Device Name
#
# Tested on:
#   RouterOS 7.18.2
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

# LOCK
:global WifiMonitorLockUntilNs

:if ([:typeof $WifiMonitorLockUntilNs] = "nothing") do={
    :set WifiMonitorLockUntilNs 0
}

:local NowNs [:tonsec [:timestamp]]
:local LockDurationNs (($SchedulerInterval * 2) * 1000000000)

:if ($WifiMonitorLockUntilNs > $NowNs) do={
    :log warning "WiFi Monitor: already running, skipping execution."
} else={

    :set WifiMonitorLockUntilNs ($NowNs + $LockDurationNs)

    # MAIN
    :onerror ErrorMessage in={

        :local MonitorRun true

        # BOOT GRACE
        :local Uptime [/system resource get uptime]

        :if ([:totime $Uptime] < ($BootGracePeriod * 1s)) do={
            :log info ("WiFi Monitor: boot grace active (" . $Uptime . ")")
            :set MonitorRun false
        }

        # TELEGRAM
        :local ScriptObj
        :local SendTelegramMessage

        :if ($MonitorRun = true) do={

            :set ScriptObj [/system script find where name="send_to_telegram"]

            :if ([:len $ScriptObj] = 0) do={
                :log error "WiFi Monitor: telegram script missing."
                :set MonitorRun false
            } else={
                :set SendTelegramMessage [:parse [/system script get $ScriptObj source]]
            }
        }

        # GLOBAL STORAGE
        :global WifiMonitorStorage

        :if ($MonitorRun = true) do={

            :if ([:typeof $WifiMonitorStorage] != "array") do={
                :set WifiMonitorStorage [:toarray ""]
            }

            # DRIVER DETECTION
            :local UseWifi false

            :onerror DriverError in={
                /interface wifi print count-only
                :set UseWifi true
            } do={
                :set UseWifi false
            }

            # READ REGISTRATION + ACCESS LIST
            :local RegTable
            :local DeviceList

            :if ($UseWifi = true) do={
                :set RegTable [/interface wifi registration-table print as-value]
                :set DeviceList [/interface wifi access-list print as-value]
            } else={
                :set RegTable [/interface wireless registration-table print as-value]
                :set DeviceList [/interface wireless access-list print as-value]
            }

            # ONLINE CACHE
            :local OnlineMacs [:toarray ""]

            :foreach Registration in=$RegTable do={

                :local MacAddress ($Registration->"mac-address")

                :if ([:typeof $MacAddress] != "nothing") do={
                    :if ([:len $MacAddress] > 0) do={
                        :set ($OnlineMacs->$MacAddress) true
                    }
                }
            }

            # ACTIVE KEYS
            :local ActiveKeys [:toarray ""]

            # DEVICE LOOP
            :foreach Device in=$DeviceList do={

                :local ProcessDevice true

                :local DeviceMac ($Device->"mac-address")

                :if ([:typeof $DeviceMac] = "nothing") do={
                    :set ProcessDevice false
                }

                :if ($ProcessDevice = true) do={
                    :if ([:len $DeviceMac] = 0) do={
                        :set ProcessDevice false
                    }
                }

                :local RawComment

                :if ($ProcessDevice = true) do={

                    :set RawComment ($Device->"comment")

                    :if ([:typeof $RawComment] = "nothing") do={
                        :set ProcessDevice false
                    }
                }

                :if ($ProcessDevice = true) do={

                    :if ([:len $RawComment] < [:len $CommentFilter]) do={
                        :set ProcessDevice false
                    }
                }

                :if ($ProcessDevice = true) do={

                    :if ([:pick $RawComment 0 [:len $CommentFilter]] != $CommentFilter) do={
                        :set ProcessDevice false
                    }
                }

                :if ($ProcessDevice = true) do={

                    :local DeviceName [:pick $RawComment [:len $CommentFilter] [:len $RawComment]]

                    :if ($DeviceName = "") do={
                        :set DeviceName $DeviceMac
                    }

                    # BUILD SAFE STORAGE KEY
                    :local Key ""

                    :for i from=0 to=([:len $DeviceMac] - 1) do={

                        :local Character [:pick $DeviceMac $i]

                        :if ($Character = ":") do={
                            :set Character "-"
                        }

                        :set Key ($Key . $Character)
                    }

                    :local StateKey ($Key . "-state")
                    :local FailKey ($Key . "-fail")

                    :set ($ActiveKeys->$StateKey) true
                    :set ($ActiveKeys->$FailKey) true

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

                    :if ([:typeof ($OnlineMacs->$DeviceMac)] != "nothing") do={
                        :if (($OnlineMacs->$DeviceMac) = true) do={
                            :set Online true
                        }
                    }

                    # FIRST RUN
                    :if ($State = "unknown") do={

                        :if ($Online = true) do={
                            :set State "online"
                            :set Fail 0
                            :set ($WifiMonitorStorage->$StateKey) $State
                            :set ($WifiMonitorStorage->$FailKey) $Fail
                        } else={
                            :set State "offline"
                            :set Fail $FailThreshold
                            :set ($WifiMonitorStorage->$StateKey) "offline"
                            :set ($WifiMonitorStorage->$FailKey) $FailThreshold
                        }

                        :log info ("WiFi Monitor init: " . $DeviceName . " = " . $State)

                    } else={

                        # ONLINE
                        :if ($Online = true) do={

                            :set Fail 0
                            :set ($WifiMonitorStorage->$FailKey) 0

                            :if ($State != "online") do={

                                :set ($WifiMonitorStorage->$StateKey) "online"

                                :local Message ("O " . $DeviceName . " connected to Wi-Fi (" . $RouterName . ")")

                                :onerror TelegramError in={
                                    $SendTelegramMessage strMessageText=$Message
                                } do={
                                    :log error ("WiFi Monitor: Telegram failed for " . $DeviceName . ": " . $TelegramError)
                                }

                                :log info ("WiFi UP: " . $DeviceName)
                            }

                        } else={

                            # OFFLINE
                            :set Fail ($Fail + 1)
                            :set ($WifiMonitorStorage->$FailKey) $Fail

                            :log info ("WiFi fail " . $DeviceName . " = " . $Fail . "/" . $FailThreshold)

                            :if ($Fail >= $FailThreshold) do={

                                :if ($State != "offline") do={

                                    :set ($WifiMonitorStorage->$StateKey) "offline"

                                    :local Message ("X " . $DeviceName . " disconnected from Wi-Fi (" . $RouterName . ")")

                                    :onerror TelegramError in={
                                        $SendTelegramMessage strMessageText=$Message
                                    } do={
                                        :log error ("WiFi Monitor: Telegram failed for " . $DeviceName . ": " . $TelegramError)
                                    }

                                    :log warning ("WiFi DOWN: " . $DeviceName)
                                }
                            }
                        }
                    }
                }
            }

            # GARBAGE COLLECTION
            :local NewStorage [:toarray ""]

            :foreach StorageKey,StorageValue in=$WifiMonitorStorage do={

                :if ([:typeof ($ActiveKeys->$StorageKey)] != "nothing") do={
                    :set ($NewStorage->$StorageKey) $StorageValue
                } else={
                    :log info ("WiFi Monitor: removed stale key " . $StorageKey)
                }
            }

            :set WifiMonitorStorage $NewStorage
        }

    } do={
        :log error ("WiFi Monitor failed: " . $ErrorMessage)
    }

    # RELEASE LOCK
    :set WifiMonitorLockUntilNs 0
}