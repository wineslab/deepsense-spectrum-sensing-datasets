'''
Author: Daniel Uvaydov
The following script is used to accompany datasets from the 2021 INFOCOM paper:

D. Uvaydov, S. D’Oro, F. Restuccia and T. Melodia,
"DeepSense: Fast Wideband Spectrum Sensing Through Real-Time In-the-Loop Deep Learning,"
IEEE INFOCOM 2021 - IEEE Conference on Computer Communications, 2021.

train_test_CNN.py:
This sample script takes the training and testing .h5 dataset generated using previous scripts
(in this case for the SDR case) then trains and tests a simple CNN

Usage:
To train: python train_test_CNN.py train
To test: python train_test_CNN.py test
'''

import numpy as np
import h5py
import tensorflow as tf
from tensorflow.keras import Sequential
from tensorflow.keras.layers import Dense, Conv1D, MaxPooling1D, LeakyReLU, Flatten, Input
from tensorflow.keras.models import Model
import argparse

# Parse Arguments
parser = argparse.ArgumentParser(description='Training or testing CNN')
parser.add_argument('mode', type=str, default="train", help="choose training/testing mode")
args = parser.parse_args()

#Open dataset .h5 file either for training or testing
dset_fp = './sdr_wifi_' + args.mode + '.h5'
dset = h5py.File(dset_fp, 'r')
X = dset['X'][()]
y = dset['y'][()]



if args.mode == 'train':

    #Model parameters
    n_classes = 4       #number of classes for SDR case
    dim = X.shape[1]    #Number of I/Q samples being taken as input
    n_channels = 2      #One channel for I and the other for Q

    #Build model
    inputs = Input(shape=(dim, n_channels))
    x = Conv1D(16, 3, input_shape=(dim, n_channels), name='conv1')(inputs)
    x = LeakyReLU(alpha=0.1)(x)
    x = Conv1D(16, 3, name='conv2')(x)
    x = LeakyReLU(alpha=0.1)(x)
    x = MaxPooling1D(pool_size=2, strides=2, name='pool1')(x)
    x = Conv1D(32, 5, name='conv3')(x)
    x = LeakyReLU(alpha=0.1)(x)
    x = Conv1D(32, 5, name='conv4')(x)
    x = LeakyReLU(alpha=0.1)(x)
    x = MaxPooling1D(pool_size=2, strides=2, name='pool2')(x)
    x = Flatten()(x)
    x = Dense(64, name='dense1')(x)
    x = LeakyReLU(alpha=0.1)(x)
    outputs = Dense(n_classes, activation='sigmoid', name='out')(x)
    model = Model(inputs=inputs, outputs=outputs)
    model.summary()

    #Compile Model
    adam = tf.keras.optimizers.Adam(lr=0.001)
    model.compile(loss='binary_crossentropy',
                  optimizer=adam,
                  metrics=['accuracy'])

    #Train
    model.fit(x=X, y=y, validation_split=0.1, batch_size=256, epochs=150, verbose=1, shuffle=True)


elif args.mode == 'test':

    #Load a pretrained model
    model = tf.keras.models.load_model(".../filepath_to_trained_model.h5")

    #Compile model
    adam = tf.keras.optimizers.Adam(lr=0.001)
    model.compile(loss='binary_crossentropy',
                  optimizer=adam,
                  metrics=['accuracy'])

    #Test model
    score = model.evaluate(x=X, y=y, verbose=1)
    print('Loss: ' + str(score[0]))
    print('Acc: ' + str(score[1]))