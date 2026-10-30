#!/bin/bash
# usage: bench.sh "<am extras>"   e.g. bench.sh "--es models v0_fp16.onnx --es threads 4,5 --es batches 1,4"
F=/sdcard/Android/data/org.birdnet.ortbench/files/results.txt
adb shell am force-stop org.birdnet.ortbench
adb shell "rm -f $F"
adb shell am start -W -n org.birdnet.ortbench/.MainActivity $1 >/dev/null
for i in $(seq 1 600); do
  sleep 2
  if adb shell "grep -q '^DONE' $F 2>/dev/null"; then break; fi
done
adb shell "cat $F"
