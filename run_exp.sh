#!/bin/bash
trap 'onCtrlC' INT

function onCtrlC () {
  echo 'Ctrl+C is captured'
  for pid in $(jobs -p); do
    kill -9 $pid
  done

  kill -HUP $( ps -A -ostat,ppid | grep -e '^[Zz]' | awk '{print $2}')
  exit 1
}

args=$1    # case='case300'
threads=$2 # 2
gpus=$3    # 0,1
times=$4   # 5

gpus=(${gpus//,/ })
args=(${args//,/ })

if [ ! $args ] || [ ! $threads ] || [ ! $gpus ] || [ ! $times ]; then
    echo "Please enter the correct command."
    echo "bash run_exp.sh arg_list experiment_thread_num gpu_list experiment_num"
    exit 1
fi

if [ ! $threads ]; then
  threads=1
fi

if [ ! $gpus ]; then
  gpus=(0)
fi

if [ ! $times ]; then
  times=6
fi

echo "ARGS:"  ${args[@]}
echo "THREADS:" $threads
echo "GPU LIST:" ${gpus[@]}
echo "TIMES:" $times


# fifo
# https://www.cnblogs.com/maxgongzuo/p/6414376.html
FIFO_FILE=$(mktemp)
rm $FIFO_FILE
mkfifo $FIFO_FILE
trap "rm $FIFO_FILE" 3
trap "rm $FIFO_FILE" 15

exec 6<>$FIFO_FILE

for ((idx=0;idx<threads;idx++)); do
    echo
done >&6


# run parallel
count=0
for((i=0;i<times;i++)); do
    read -u6
    gpu=${gpus[$(($count % ${#gpus[@]}))]}
    {
      CUDA_VISIBLE_DEVICES="$gpu" python train.py "${args[@]}" --order=$(($i + 1))
      echo >&6
    } &
    count=$(($count + 1))
#     sleep $(10)
    sleep $((RANDOM % 60 + 60))
done
wait

exec 6>&-   # 关闭fd6
rm $FIFO_FILE
