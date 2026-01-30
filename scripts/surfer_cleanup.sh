#!/bin/bash
mkdir -p /home/wrc/main_workspace/data_logs /home/wrc/main_workspace/videos /home/wrc/main_workspace/oak_models
rm -rf /home/wrc/main_workspace/data_logs/* 
rm -rf /home/wrc/main_workspace/videos/*
rm -rf /home/wrc/main_workspace/oak_models/*


echo "Workspace cleaned: data_logs, videos, oak_models directories are now empty."