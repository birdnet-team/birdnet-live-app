# Round 2: TPU continuous load + 2 more repeats of the 1-window/s duty cycle (numbers in README are the ranges over all rounds).
cd /data/local/tmp/bn
sample() { # avg power in mW over $1 seconds
  n=0; s=0; end=$(( $(date +%s) + $1 ))
  while [ $(date +%s) -lt $end ]; do
    i=$(cat /sys/class/power_supply/battery/current_now); v=$(cat /sys/class/power_supply/battery/voltage_now)
    s=$(( s + (0 - i) / 1000 * (v / 1000) / 1000 )); n=$(( n + 1 )); sleep 0.2
  done
  echo $(( s / n ))
}
run() { # tag mode flags...
  tag=$1; mode=$2; shift 2
  if [ "$mode" = duty ]; then extra="--num_runs=48 --run_delay=1 --min_secs=0"; else extra="--num_runs=100000 --max_secs=45 --min_secs=45"; fi
  ./bm --graph=trunk_fp32.tflite "$@" --warmup_runs=2 $extra > log_$tag.txt 2>&1 &
  sleep 10; p=$(sample 30); wait
  echo "$tag $mode: ${p} mW | $(grep -E 'Inference timings' log_$tag.txt | sed -E 's/.*Inference \(avg\): ([0-9.]+)/avg \1 us/') | $(grep -E 'count=' log_$tag.txt | tail -1 | sed -E 's/.*count=([0-9]+).*/runs \1/')"
  sleep 15
}
sleep 10; echo "idle: $(sample 30) mW"
run tpu cont --use_nnapi=true --nnapi_accelerator_name=google-edgetpu --nnapi_allow_fp16=true
run tpu_lowpower cont --use_nnapi=true --nnapi_accelerator_name=google-edgetpu --nnapi_allow_fp16=true --nnapi_execution_preference=low_power
for rep in 2 3; do
  run cpu4_fp16 duty --use_xnnpack=true --num_threads=4 --xnnpack_force_fp16=true
  run gpu_fp16 duty --use_gpu=true
  run tpu duty --use_nnapi=true --nnapi_accelerator_name=google-edgetpu --nnapi_allow_fp16=true
  run tpu_lowpower duty --use_nnapi=true --nnapi_accelerator_name=google-edgetpu --nnapi_allow_fp16=true --nnapi_execution_preference=low_power
done
echo "idle: $(sample 20) mW"
