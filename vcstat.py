#!/usr/bin/env python3

import subprocess


def measure_clock():
    print("=== measure_clock ===")
    for src in ["core", "h264", "isp", "v3d", "arm"]:
        freq = subprocess.check_output(["vcgencmd", "measure_clock", src])
        print(src+"\t", freq.decode("utf-8").strip())
    print()


def measure_volts():
    print("=== measure_volts ===")
    for src in ["core", "sdram_c", "sdram_i", "sdram_p"]:
        freq = subprocess.check_output(["vcgencmd", "measure_volts", src])
        print(src+"\t", freq.decode("utf-8").strip())
    print()


def measure_temp():
    print("=== measure_temp ===")
    freq = subprocess.check_output(["vcgencmd", "measure_temp"])
    print("core\t", freq.decode("utf-8").strip())
    print()


def get_throttled():
    print("=== get_throttled ===")
    value = subprocess.check_output(["vcgencmd", "get_throttled"])
    env = {}
    exec(value, {}, env)
    throttled = env["throttled"]
    print("throttled =", hex(throttled))

    def explain_throttled(throttled):
        throttled_flags = {
            0x1:	"Under-voltage detected",
            0x2:	"Arm frequency capped",
            0x4:	"Currently throttled",
            0x8:	"Soft temperature limit active",
            0x10000:	"Under-voltage has occurred",
            0x20000:	"Arm frequency capping has occurred",
            0x40000:	"Throttling has occurred",
            0x80000:	"Soft temperature limit has occurred",
        }
        for flag, msg in throttled_flags.items():
            if throttled & flag:
                print(hex(flag)+"\t", msg)
    explain_throttled(throttled)
    print()


if __name__ == "__main__":
    measure_clock()
    measure_volts()
    measure_temp()
    get_throttled()

