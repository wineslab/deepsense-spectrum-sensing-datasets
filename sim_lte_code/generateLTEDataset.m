%Author: Daniel Uvaydov
%Generates uplink LTE-M dataset that toggles transmissions on different channels
%making some channels busy while others are free. Reference for this
%code can be found at:
%https://www.mathworks.com/help/lte/ug/lte-m-uplink-waveform-generation.html
%HIGHLY SUGGEST YOU READ ABOVE LINK FIRST TO UNDERSTAND CODE AS THIS CODE ESSENTIALLY
%GENERATES FRAMES VIA THE LINK ABOVE JUST MULTIPLE TIMES ON DIFFERENT BANDS
%
%Running code as is will generate a training and testing set containig varying transmissions on 16 sub-bands with
%-10dB SNR and one sample per label. Total number of multi-hot encoded labels are 2^16.


snr_db = -10; %SNR in dB
nch = 16; %number of sub-bands/channels to break band into/classify
nlabels = 2^nch; %number of possible combinations of labels for multi-hot encoded busy channels
niq = 16; %number of iq samples to take as input
all_ch = 1:nch;
all_ch = reshape(all_ch,2,nch/2)';

%holds all different training/testing labels that must be generated
labels = 0:(nlabels-1);
labels = kron(labels,ones(1,8));
labels = dec2bin(labels, nch);

%holds data corresponding to each label
data = zeros(size(labels,1), niq, 2);

%for each label generate data
for l = 1:length(labels)
    disp(l);
    label = labels(l,:);

    active_ch = find(label == '1'); %active channels are those with '1's in label

    %grid that will contain spectrogram of LTE-M band but with only one active channel
    sfgrid_single_active_ch = zeros(nch, 600,14,1);
    ue = struct();                % Initialize the structure
    ue.NULRB = 50;                % Bandwidth number of resource blocks 50 --> 10 MHz
    ue.DuplexMode = 'FDD';        % Duplex mode
    ue.TDDConfig = 1;             % UL/DL configuration if TDD duplex mode
    ue.CyclicPrefixUL = 'Normal'; % The cyclic prefix length
    ue.NTxAnts = 1;

    %generate data for each active channel
    for ch = 1:length(active_ch)

        channel = active_ch(ch);
        ue = struct();                % Initialize the structure
        ue.NULRB = 50;                % Bandwidth number of resource blocks 50 --> 10 MHz
        ue.DuplexMode = 'FDD';        % Duplex mode
        ue.TDDConfig = 1;             % UL/DL configuration if TDD duplex mode
        ue.CyclicPrefixUL = 'Normal'; % The cyclic prefix length
        ue.NTxAnts = 1;               % Number of transmit antennas
        ue.NCellID = 1;               % Cell identity
        ue.RNTI = 1;                  % RNTI value
        ue.NFrame = 0;                % Frame number
        ue.NSubframe = 0;             % Subframe number
        ue.Shortened = 1;             % Last symbol availability (allocation for SRS)


        % Set up hopping specific parameters
        ue.HoppingOffset = 1;% Narrowband offset between one narrowband and the next narrowband
                             % a PUSCH hops to, expressed as a number of uplink narrowbands
        ue.NChULNB = 1;      % Number of consecutive absolute subframes over which
                             % PUCCH or PUSCH stays at the same

        pusch  = struct();
        pusch.CEMode = 'A';         % CE mode A or CE mode B
        pusch.Hopping = false;       % Enable/Disable frequency hopping
        pusch.NRepPUSCH = 1;        % The total number of PUSCH repetitions
        pusch.Modulation = 'QPSK';  % Symbol modulation
        pusch.RV = 0;               % Redundancy version for UL-SCH processing
        pusch.NLayers = 1;          % Number of layers
        pusch.TrBlkSizes = 100;     % Transport block size

        %%
        % Specify 1-based relative indices of RBs within a narrowband for all cases
        % except 5MHz Cat-M2 CE mode A. If 5MHz Cat-M2 CE mode A, these are the
        % absolute PRBs used for transmission
        parity = ~mod(channel,2);
        pusch.InitPRBSet = (1+(3*parity):3+(3*parity));

        % Narrowband used for transmission (non-hopping, non-5MHz)
        % Set active channel
        [NarrowbandIndex,~] = find(all_ch == channel);
        pusch.InitNarrowbandIndex = NarrowbandIndex-1;

        % Specify the power scaling in dB for PUSCH, PUSCH DM-RS
        pusch.PUSCHPower = 30;
        pusch.PUSCHDMRSPower = 40;

        % Turn off hopping if allocation spans multiple narrowbands
        if numel(pusch.InitPRBSet) > 6
            pusch.Hopping = false;
        end

        %%

        % Identify all uplink subframes in a frame
        info = arrayfun(@(x)lteDuplexingInfo(setfield(ue,'NSubframe',x)),0:9);
        ulsfs = arrayfun(@(x)strcmpi(x.SubframeType,'Uplink'),info);
        % In this example, we assume that the first absolute subframe in which
        % PUSCH is transmitted is the first available uplink subframe
        pusch.InitNSubframe = find(ulsfs,1)-1;

        % Calculate the allocation
        pusch.PRBSet = getPUSCHAllocation(ue,pusch);
        ueTemp = ue;
        % Create coded transport block for all symbols
        if strcmpi(pusch.CEMode,'B') && ue.Shortened
            ueTemp.Shortened = 0;
        end
        [~,info] = ltePUSCHIndices(ueTemp,pusch);
        % Define UL-SCH message bits
        trData = rand(pusch.TrBlkSizes(1),1);
        % Create the coded UL-SCH bits
        pusch.BetaCQI = 2.0;
        pusch.BetaRI = 2.0;
        pusch.BetaACK = 2.0;
        codedTrBlock = lteULSCH(ueTemp,pusch,info.G,trData);

        %%
        % Number of subframes in a scrambling block
        Nacc = 1;
        if strcmpi(ue.DuplexMode,'FDD') && strcmpi(pusch.CEMode,'B')
            Nacc = 4;
        elseif strcmpi(ue.DuplexMode,'TDD') && strcmpi(pusch.CEMode,'B')
            Nacc = 5;
        end

        % Total BL/CE subframes to simulate (all uplink subframes are BL/CE
        % subframes) and the PUSCH is transmitted without any subframe gaps
        totmtcSubframes = pusch.NRepPUSCH;

        % Total absolute subframes to simulate
        startSubframe = ue.NFrame*10+ue.NSubframe; % Initial absolute subframe number
        lastabssf = getlastabsSF(ulsfs,pusch.InitNSubframe,totmtcSubframes);
        totSubframes = lastabssf-startSubframe+1;

        % Create a resource grid for the entire transmission. The PUSCH and
        % DM-RS symbols will be mapped in this array
        subframeSize = lteULResourceGridSize(ue);
        sfgrid = zeros([subframeSize(1) subframeSize(2)*totSubframes subframeSize(3:end)]);

        mpuschSym = []; % Initialize PUSCH symbols

        for sf = startSubframe + (0:totSubframes -1)

            % Set current absolute subframe and frame numbers
            ue.NSubframe = mod(sf,10);
            ue.NFrame = floor((sf)/10);

            % Skip processing if this is not an uplink subframe
            duplexInfo = lteDuplexingInfo(ue);
            if ~strcmpi(duplexInfo.SubframeType,'Uplink')
                continue
            end

           % Calculate the PRBSet used in the current subframe
            prbset = getPUSCHAllocation(ue,pusch);

            % Calculate the PDSCH indices for the current subframe. For BL/CE UEs
            % in CE mode B, resource elements in the last SC-FDMA symbol in a
            % subframe configured with cell specific SRS shall be counted in the
            % PUSCH mapping but not used for transmission of the PUSCH
            pusch.PRBSet = prbset;
            mpuschIndices = ltePUSCHIndices(ue,pusch);

            % Create an empty subframe grid
            subframe = lteULResourceGrid(ue);

            % Encode PUSCH symbols from the codeword
            % In the case of repetition, the same symbols are repeated in each of
            % a block of NRepPUSCH subframes. Frequency hopping is applied as required
            if ~mod(sf,Nacc) || isempty(mpuschSym)
                ueTemp = ue;
                if strcmpi(pusch.CEMode,'B') && ue.Shortened
                    ueTemp.Shortened = 0;  % Create symbols for full subframe
                end
                mpuschSym = ltePUSCH(ueTemp,pusch,codedTrBlock)*db2mag(pusch.PUSCHPower);
            end
            % Map SRS punctured PUSCH symbols to the subframe grid
            subframe(mpuschIndices) = mpuschSym(1:numel(mpuschIndices));


            % Create and map the DMRS symbols.
            ue.Hopping = 'Off';    % DRS hopping
            ue.SeqGroup = 0;       % PUSCH sequence group
            ue.CyclicShift = 0;    % Used for n1DMRS
            % For LTE-M UEs, a cyclic shift field of '000' shall be assumed when
            % determining n2DMRS from Table 5.5.2.1.1-1 of TS 36.211
            pusch.DynCyclicShift = 0; % Cyclic shift of '000' for n2DMRS
            pusch.OrthCover = 'Off';  % No orthogonal cover sequence
            mpuschDrs = ltePUSCHDRS(ue,pusch)*db2mag(pusch.PUSCHDMRSPower);
            mpuschDrsIndices = ltePUSCHDRSIndices(ue,pusch);
            subframe(mpuschDrsIndices) = mpuschDrs;

            % Now assign the current subframe into the overall grid
            sfgrid(:,(1:subframeSize(2))+sf*subframeSize(2),:) = subframe;
            sfgrid_single_active_ch(ch,:,:) = sfgrid;

        end
    end

    %sum accross all grids with single active channels to generate a (nch x iq) grid with multiple active channels
    sfgrid = sum(sfgrid_single_active_ch,1);
    sfgrid = squeeze(sfgrid);

    %take grid representing a spectrogram and generate time-series iq waveform
    waveform = lteSCFDMAModulate(ue,sfgrid);

    %add noise and fading to waveform
    waveform_n = awgn(waveform, snr_db,'measured');
    rayleighchan = comm.RayleighChannel('PathDelays',[0 1.5e-4 3e-4], 'AveragePathGains',[1 1 1]);
    waveform_out = rayleighchan(waveform_n);

    %seperate real and imaginary and take first niq samples
    data(l,:,:) = [real(waveform_out(1:niq)) imag(waveform_out(1:niq))];
end

%convert labels to multi-hot encoded array
labels = bin2dec(labels);
labels = de2bi(labels,nch);
labels = uint8(labels);

% Cross validation (train: 90%, test: 10%)
cv = cvpartition(size(data,1),'HoldOut',0.1);
idx = cv.test;
% Separate to training and test data
dataTrain = data(~idx,:,:);
dataTest  = data(idx,:,:);

labelsTrain = labels(~idx,:);
labelsTest  = labels(idx,:);

%save dataset
train_fp = strcat('lte_', num2str(snr_db), '_', num2str(niq), '_train.h5');

h5create(train_fp,'/X', size(dataTrain));
h5write(train_fp,'/X', dataTrain);
h5create(train_fp,'/y', size(labelsTrain));
h5write(train_fp,'/y', labelsTrain);

test_fp = strcat('lte_', num2str(snr_db), '_', num2str(niq), '_test.h5');

h5create(test_fp,'/X', size(dataTest)); 
h5write(test_fp,'/X', dataTest);
h5create(test_fp,'/y', size(labelsTest));
h5write(test_fp,'/y', labelsTest);


