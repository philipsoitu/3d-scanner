#!/usr/bin/env bash

rsync -avz phil@192.168.2.100:/home/phil/3d-scanner/kinect_output/ /home/phil/code/3d-scanner/kinect_output/
rsync -avz phil@192.168.2.100:/home/phil/3d-scanner/pointcloud.ply /home/phil/code/3d-scanner/pointcloud.ply
