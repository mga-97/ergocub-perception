yarp connect /depthCamera/rgbImage:o /cer/realsense_repeater/rgbImage:o mjpeg
yarp connect /depthCamera/depthImage:o /depthCamera/depthImage:r fast_tcp+send.portmonitor+file.depthimage_compression_zlib+recv.portmonitor+file.depthimage_compression_zlib+type.dll



