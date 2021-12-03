% Calculate the widebands, narrowbands and PRBSets for the LTE carrier bandwidth
function [prbsets,nNB,nWB] = calcNarrowbandPRBSets(NULRB)
    % Narrowbands & Widebands (See 36.211 Section 5.2.4)
    NULNB = floor(NULRB/6);
    nNB = 0:(NULNB-1); % Narrowbands
    if NULNB >= 4
        NULWB = floor(NULNB/4);
    else
        NULWB = 1;
    end
    nWB = 0:(NULWB-1); % Widebands

    % PRBs in a narrowband
    ii = 0:5;
    ii0 = floor(NULRB/2) - 6*(NULNB/2);
    prbsets = zeros(6,numel(nNB));
    for nb = 1:numel(nNB)
        if mod(NULRB,2) && nNB(nb)>= (NULNB/2)
            prbsets(:,nb) = 6*(nNB(nb))+ii0+ii + 1;
        else
            prbsets(:,nb) = 6*(nNB(nb))+ii0+ii;
        end
    end
end