yarp connect /cer/realsense_repeater/rgbImage:o /depthCamera/rgbImage:r mjpeg
yarp connect /cer/realsense_repeater/depthImage:o /depthCamera/depthImage:r fast_tcp+send.portmonitor+file.depthimage_compression_zlib+recv.portmonitor+file.depthimage_compression_zlib+type.dll



