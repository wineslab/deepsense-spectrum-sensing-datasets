'''
Author: Daniel Uvaydov
The following script is used in the 2021 INFOCOM paper:

D. Uvaydov, S. D’Oro, F. Restuccia and T. Melodia,
"DeepSense: Fast Wideband Spectrum Sensing Through Real-Time In-the-Loop Deep Learning,"
IEEE INFOCOM 2021 - IEEE Conference on Computer Communications, 2021.

preprocessing.py:
This script takes combines all the .h5 files containing different signals generates their labels and generates a training
and testing dataset
'''

import numpy as np
import h5py
from sklearn.model_selection import train_test_split
import os as os
import random

# Size of input to 1D CNN or number of complex samples being fed to 1D CNN (should be same as bin2hdf5.py)
buf = 128

# Percentage of dataset that will be used for testing
test_size = 0.1

# Seed used for shuffling dataset
seed = 42

# Filepath containing directory with converted .h5 files
h5_folder_fp = ".../sdr_wifi_h5/"
folder = os.listdir(h5_folder_fp)
folder.sort()

# Generate dummy arrays to be contain entire dataset and dataset labels (can also use list and convert to np.array later)
dataset_labels = np.zeros((1, 4))
dataset = np.zeros((1, buf, 2))

for file in folder: 
    if not os.path.isdir(h5_folder_fp + file):

        # Open .h5 folder and extract data
        f = h5py.File(h5_folder_fp + file, 'r')
        name = os.path.splitext(file)[0]
        data = f[name][()]

        # Append samples from current file to dataset
        dataset = np.concatenate((dataset, data))

        # Generates the multi-hot encoded labels from the file name
        label = list(name.split('_')[0])    # Take part of filename that contains labels
        label = list(map(int, label))       # Convert string to multi-hot list
        label = [label] * data.shape[0]     # Generate label for each training sample in file
        label = np.array(label, dtype='i')  # Convert list of labels to np.array
        dataset_labels = np.concatenate((dataset_labels, label))    # Append to labels for entire dataset

f.close()

# Delete first entry of arrays as they contain zeros
dataset = np.delete(dataset, 0, 0)
dataset_labels = np.delete(dataset_labels, 0, 0)

# Shuffle dataset and split into training and testing samples
X_train, X_test, y_train, y_test = train_test_split(
    dataset, dataset_labels, test_size=test_size, random_state=seed)

# Save test set
f_test = h5py.File('./sdr_wifi_test.hdf5', 'w')
xtest = f_test.create_dataset('X', (X_test.shape[0], X_test.shape[1], X_test.shape[2]), dtype='f')
ytest = f_test.create_dataset('y', (y_test.shape[0], y_test.shape[1]), dtype='i')
xtest[()] = X_test
ytest[()] = y_test


# Save train set
f_train = h5py.File('./sdr_wifi_train.hdf5', 'w')
xtrain = f_train.create_dataset('X', (X_train.shape[0], X_train.shape[1], X_train.shape[2]), dtype='f')
ytrain = f_train.create_dataset('y', (y_train.shape[0], y_train.shape[1]), dtype='i')
xtrain[()] = X_train
ytrain[()] = y_train

# Close Files
f_test.close()
f_train.close()

