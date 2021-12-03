'''
Author: Daniel Uvaydov
The following script is used in the 2021 INFOCOM paper:

D. Uvaydov, S. D’Oro, F. Restuccia and T. Melodia,
"DeepSense: Fast Wideband Spectrum Sensing Through Real-Time In-the-Loop Deep Learning,"
IEEE INFOCOM 2021 - IEEE Conference on Computer Communications, 2021.

bin2hdf5.py:
This script converts the raw .bin files collected from GNU Radio to .h5 files to be preprocessed later
'''


import numpy as np
import os as os
import h5py
from scipy.signal import spectrogram
import matplotlib.pyplot as plt

# If you desire to plot the spectrogram of the samples set below to True
plot_spect = False

# Getting list of raw .bin files
bin_folder_fp = ".../sdr_wifi/"               # filepath of folder contain .bin files
bin_folder = os.listdir(bin_folder_fp)      # list of files in folder


# Filepath of folder that will contain the converted h5 files
h5_folder_fp = ".../sdr_wifi_h5/"
if not os.path.isdir(h5_folder_fp):
    os.mkdir(h5_folder_fp)

# Parameters for training 1D CNN
buf = 128                           # Size of input to CNN in number of I/Q samples
stride = 12                         # To create overlap between samples (if no overlap desired set stride = buf)"
nsamples_per_file = 10000           # Number of buf sized training/testing samples to be gathered from each .bin file

# Number of complex values to read from .bin file to generate desired amount of training/testing samples
# If you want to read all the complex values set niq2read = -1
niq2read = (nsamples_per_file-1) * stride + buf

# Number of complex values to skip over before reading
offset = 0




# Iterate through each .bin file and add contents to .h5 file
for file in bin_folder:
    if not os.path.isdir(bin_folder_fp + file):
        with open(bin_folder_fp + file) as binfile:

            # Extract desired number of samples
            samps = np.fromfile(binfile, dtype=np.complex64, count=niq2read, offset=offset)

            # Plot samples
            if plot_spect:

                #Generate spectrogram at sampling rate of 20MHz
                f, t, Sxx = spectrogram(samps, 20000000,return_onesided=False)

                # Compensate for FFT Shift caused by GNU Radio
                Sxx = np.fft.fftshift(Sxx, axes=0)

                # Plot spectrogram
                # play with vmax to better see certain transmissions
                plt.pcolormesh(t, np.fft.fftshift(f), Sxx, shading='auto', vmax=np.max(Sxx)/100)
                plt.ylabel('Frequency [Hz]')
                plt.xlabel('Time [sec]')
                plt.title(file)
                plt.show()

            # Turn 1D complex array of raw samples and reshape into a 2D array containing I and Q as floats
            samps = np.transpose(np.stack((np.real(samps), np.imag(samps))))

            # Break long 2D array containing all I/Q values into multiple training/testing samples with overlap
            # depending on size of input to the CNN and overlap between samples
            samps = np.array([samps[k:k + buf] for k in range(0, len(samps) - 1 - buf, stride)])


            #Create .h5 file with same name as .bin file and fill with reshaped samples
            name = os.path.splitext(file)[0]
            f = h5py.File(h5_folder_fp + name + '.h5', 'w')
            dset = f.create_dataset(name, (samps.shape[0], samps.shape[1], samps.shape[2]), dtype='f')
            dset[()] = samps
            f.close()

