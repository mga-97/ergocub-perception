#!/usr/bin/bash

# Change name also in stop.sh
TMUX_NAME=perception-tmux
DOCKER_CONTAINER_NAME=ergocub_perception_container

echo "Start this script inside the ergoCub visual perception root folder"
usage() { echo "Usage: $0 [-S (use SIM_CER)] [-i ip_address] [-n nameserver] [-y (to start yarp server] [-s (to start source)] [-b (just bash)]" 1>&2; exit 1; }

while getopts i:ysbhn:S flag
do
    case "${flag}" in
        i) SERVER_IP=${OPTARG};;
        n) YARP_NAMESERVER=${OPTARG};;
        y) START_YARP_SERVER='1';;
        S) SIM='1';;
        s) START_SOURCE='1';;
        b) JUST_BASH='1';;
        h) usage;;
        *) usage;;
    esac
done

# Start the container with the right options
docker run --gpus=all -v "$(pwd)":/home/ergocub/perception -itd --rm \
--gpus=all \
--env DISPLAY=$DISPLAY \
--env PYTHONPATH=/home/ergocub/perception \
--volume="/tmp/.X11-unix:/tmp/.X11-unix:rw" \
-v ~/.config/yarp/yarp.conf:/home/ergocub/.config/yarp/yarp.conf \
--ipc=host \
--network=host --name $DOCKER_CONTAINER_NAME ar0s/ergocub-perception-image bash

# Create tmux session
tmux new-session -d -s $TMUX_NAME
tmux set-option -t $TMUX_NAME status-left-length 140
tmux set -t $TMUX_NAME -g pane-border-status top
tmux set -t $TMUX_NAME -g mouse on

# Just bash?
if [ -n "$JUST_BASH" ] # Variable is non-null
then
  tmux send-keys -t $TMUX_NAME "docker exec -it $DOCKER_CONTAINER_NAME bash" Enter
  tmux a -t $TMUX_NAME
  exit 0
fi

# Set Yarp Server Configurations
tmux rename-window -t $TMUX_NAME yarpConfiguration
tmux send-keys -t $TMUX_NAME "docker exec -it $DOCKER_CONTAINER_NAME bash" Enter

if [ -n "$YARP_NAMESERVER" ] # Variable is non-null
then
  tmux send-keys -t $TMUX_NAME "yarp namespace $YARP_NAMESERVER" Enter
fi

if [ -n "$SERVER_IP" ] # Variable is non-null
then
  tmux send-keys -t $TMUX_NAME "yarp conf $SERVER_IP 10000" Enter
fi

if [ -n "$START_YARP_SERVER" ] # Variable is non-null
then
  tmux send-keys -t $TMUX_NAME "yarpserver --write" Enter
fi
tmux send-keys -t $TMUX_NAME "yarp repeat /depthCamera/rgbImage:r" Enter

tmux split-window -h -t $TMUX_NAME
tmux send-keys -t $TMUX_NAME "docker exec -it $DOCKER_CONTAINER_NAME bash" Enter
if [ -n "$START_YARP_SERVER" ] # Variable is non-null
then
  tmux send-keys -t $TMUX_NAME "yarp detect" Enter
fi
tmux send-keys -t $TMUX_NAME "yarp repeat /depthCamera/depthImage:r" Enter


#######################################################################
tmux new-window -t $TMUX_NAME
tmux rename-window -t $TMUX_NAME components

# Manager
tmux select-pane -T "Manager"
tmux send-keys -t $TMUX_NAME "docker exec -it $DOCKER_CONTAINER_NAME bash" Enter
tmux send-keys -t $TMUX_NAME "cd perception" Enter
tmux send-keys -t $TMUX_NAME "python scripts/manager.py" Enter

tmux split-window -h -t $TMUX_NAME

# Human Detection
tmux select-pane -T "Human Detection"
tmux send-keys -t $TMUX_NAME "docker exec -it $DOCKER_CONTAINER_NAME bash" Enter
tmux send-keys -t $TMUX_NAME "cd perception" Enter
tmux send-keys -t $TMUX_NAME "python scripts/human_detection.py" Enter

tmux split-window -h -t $TMUX_NAME

# Human Pose Estimation
tmux select-pane -T "Human Pose Estimation"
tmux send-keys -t $TMUX_NAME "docker exec -it $DOCKER_CONTAINER_NAME bash" Enter
tmux send-keys -t $TMUX_NAME "cd perception" Enter
tmux send-keys -t $TMUX_NAME "python scripts/human_pose_estimation.py" Enter

tmux split-window -h -t $TMUX_NAME

# Action Recognition Pipeline
tmux select-pane -T "Action Recognition"
tmux send-keys -t $TMUX_NAME "docker exec -it $DOCKER_CONTAINER_NAME bash" Enter
tmux send-keys -t $TMUX_NAME "cd perception" Enter
tmux send-keys -t $TMUX_NAME "python scripts/action_recognition.py" Enter

tmux split-window -h -t $TMUX_NAME

# Sink
tmux select-pane -T "Sink"
tmux send-keys -t $TMUX_NAME "docker exec -it $DOCKER_CONTAINER_NAME bash" Enter
tmux send-keys -t $TMUX_NAME "cd perception" Enter
tmux send-keys -t $TMUX_NAME "python scripts/sink2.py" Enter

tmux split-window -h -t $TMUX_NAME

# Human Console
tmux select-pane -T "Human Console"
tmux send-keys -t $TMUX_NAME "docker exec -it $DOCKER_CONTAINER_NAME bash" Enter
tmux send-keys -t $TMUX_NAME "cd perception" Enter
tmux send-keys -t $TMUX_NAME "python scripts/human_console2.py" Enter

tmux select-layout -t $TMUX_NAME tiled

sleep 10 ### MUST WAIT FOR THE CAMERA REPEATER PORTS
if [ -n "$SIM" ] # Variable is non-null
then
  echo "Connecting SIM_CER camera"
  ./connect_camera_SIM_CER.sh
else 
  echo "Connecting cer camera"
  ./connect_camera_cer.sh
fi

# Attach
# tmux a -t $TMUX_NAME
