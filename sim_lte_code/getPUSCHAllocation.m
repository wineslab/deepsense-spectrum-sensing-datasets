% Calculate the resource blocks allocated for PUSCH in the subframe
function prbset = getPUSCHAllocation(ue,chs)

    % If 5MHz mode (up to 24 PRBs can be used), the allocation is the same
    % as InitPRBSet
    if numel(chs.InitPRBSet) > 6
        prbset = chs.InitPRBSet;
        return;
    end

    % Get the narrowbands and corresponding resources
    [prbsets,nNB] = calcNarrowbandPRBSets(ue.NULRB);
    if max(chs.InitNarrowbandIndex) > max(nNB)
        error('Invalid narrowband(s) specified. There are only %d narrowbands in the bandwidth from 0...%d', nNB+1, nNB);
    end
    % If frequency hopping is disabled, the allocation is the same for
    % every subframe
    if ~chs.Hopping
        prbset = prbsets(chs.InitPRBSet,chs.InitNarrowbandIndex+1);
        return
    end

    % Hopping narrowband calculation according to TS 36.211 Section 5.3.4
    j0 = floor((chs.InitNSubframe)/ue.NChULNB);

    % Calculate the narrowband for this subframe
    ue.NSubframe = ue.NFrame*10+ue.NSubframe; % Get the absolute subframe number
    if mod(floor(ue.NSubframe/ue.NChULNB-j0),2) == 0
        nnBi = chs.InitNarrowbandIndex;
    else
        nnBi = mod(chs.InitNarrowbandIndex+ue.HoppingOffset,numel(nNB));
    end
    % Calculate the PRBSet for this subframe, they are on the same RBs
    % within the narrowband
    [rbstartIndex,nbstartIndex] = find(prbsets == chs.InitPRBSet(1));
    [rbendIndex,nbendIndex] = find(prbsets == chs.InitPRBSet(end));
    if (isempty(rbstartIndex) || isempty(rbendIndex)) || (nbstartIndex ~= nbendIndex)
       error('Invalid PRBSet specified, must be resources within single narrowband');
    end
    prbset = prbsets(rbstartIndex:rbstartIndex+numel(chs.InitPRBSet)-1,nnBi+1);

end