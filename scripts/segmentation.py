import copy
import sys
from pathlib import Path

import cv2
import numpy as np
from loguru import logger
from scipy.spatial.transform import Rotation

from utils.concurrency.utils.signals import Signals
from grasping.utils.input import RealSense

sys.path.insert(0, Path(__file__).parent.parent.as_posix())

from grasping.utils.avg_timer import Timer
from utils.logging import setup_logger
import tensorrt as trt
# https://github.com/NVIDIA/TensorRT/issues/1945
import torch
import pycuda.autoinit

from configs.segmentation_config import Segmentator, Network, Logging

setup_logger(**Logging.Logger.Params.to_dict())


class Segmentation(Network.node):
    def __init__(self):
        super().__init__(**Network.Args.to_dict())
        self.seg_model = None
        self.follow_object = True
        self.R = Rotation.from_euler('xyz', [180, 0, 0], degrees=True).as_matrix()
        self.timer = Timer(window=10)

    def startup(self):
        self.seg_model = Segmentator.model(**Segmentator.Args.to_dict())

    def loop(self, data):
        output = copy.deepcopy(data)

        self.timer.start()
        logger.info("Read camera input", recurring=True)

        rgb = data['rgb']
        depth = data['depth']
        if rgb in Signals or depth in Signals:
            return output

        # Segment the rgb and extract the object depth
        # start = time.perf_counter()
        mask = self.seg_model(rgb)

        # print(1 / (time.perf_counter() - start))
        mask = cv2.resize(mask, dsize=(640, 480), interpolation=cv2.INTER_NEAREST)

        logger.info("RGB segmented", recurring=True)


        # print(mask)
        # print(mask.dtype)
        print((mask != 1).shape)
        print((mask != 1).dtype)
        print(depth.dtype)
        print(depth.shape)
        if mask not in Signals:
            depth[mask != 1] = 0

        logger.info("Depth segmented", recurring=True)

        # There are not enough points
        if len(depth.nonzero()[0]) < 4096:
            output['mask'] = Signals.NOT_OBSERVED
            self.write('to_visualizer', output)
            self.write('to_shape_completion', {'segmented_pc': Signals.NOT_OBSERVED,
                                               'obj_distance': Signals.NOT_OBSERVED})  # TODO MAKE IT BETTER
            logger.warning('Warning: not enough input points. Skipping reconstruction', recurring=True)
            return

        distance = depth[depth != 0].min()
        output['obj_distance'] = int(distance)

        # The box is too distant
        if distance > 700:
            output['mask'] = Signals.NOT_OBSERVED
            self.write('to_visualizer', output)
            self.write('to_shape_completion', {'segmented_pc': Signals.NOT_OBSERVED,
                                               'obj_distance': int(distance)})  # TODO MAKE IT BETTER
            return

        output['mask'] = mask
        segmented_pc = RealSense.depth_pointcloud(depth)

        self.write('to_visualizer', output)
        point = np.mean(segmented_pc, axis=0, keepdims=True)
        self.write('to_shape_completion', {'segmented_pc': segmented_pc, 'obj_distance': int(distance),
                                           'point': (point @ self.R).reshape(-1)})  # TODO MAKE IT BETTER

        # self.write('to_gaze_control', {'point': (point @ self.R).reshape(-1)})
        if self.follow_object:
            self.write('to_3d_viz', {'point': point})

        # print((point @ self.R).reshape(-1))  SONO GIUSTI


if __name__ == '__main__':
    grasping = Segmentation()
    grasping.run()
