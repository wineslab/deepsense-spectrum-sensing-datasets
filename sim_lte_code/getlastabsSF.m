% Get the absolute subframe number which is used for the last transmission
% of a channel
function lastabssf = getlastabsSF(ulsfs,InitNSubframe,totmtcSubframes)

    numulsfsinFrame = sum(ulsfs); % Number of active sfs in a frame
    ulsfsinFrame = find(ulsfs);   % UL subframes in the frame (1-based)

    % Find the first absolute subframe and frame
    initabssf = mod(InitNSubframe,10);
    initabsf = floor(InitNSubframe/10);

    startIdxwithinFrame = initabssf+1; % 1-based index to the UL sf
    if ~ulsfs(startIdxwithinFrame)
        error(['Invalid absolute subframe number of the first uplink subframe', ...
              ' intended for PUSCH (%d) specified. This is not an uplink subframe'],InitNSubframe)
    end

    sfslastFrame = mod((find(ulsfsinFrame==startIdxwithinFrame)-1)+totmtcSubframes,numulsfsinFrame); % subframes to tx in the last frame
    if sfslastFrame
        % Find the subframe number corresponding to the last subframe to transmit
        sfsnumlastFrame = find(ulsfs,sfslastFrame)-1;
        sfsnumlastFrame = sfsnumlastFrame(end);
    else
        % No partial frames required
        sfsnumlastFrame = 0;
    end
    lastabssf = (initabsf + floor(((find(ulsfsinFrame==startIdxwithinFrame)-1)+totmtcSubframes)/numulsfsinFrame)) * 10 + sfsnumlastFrame;

end
