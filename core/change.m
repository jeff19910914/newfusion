% change.m
% Version 2.0
% Core
%
% Project: New fusion
% By xjtang
% Created On: 3/31/2015
% Last Update: 7/15/2015
%
% Input Arguments:
%   TS (Matrix) - fusion time series of a pixel.
% 
% Output Arguments: 
%   CHG (Vector) - time series of change.
%
% Instruction: 
%   1.Call by other scripts with correct input and output arguments.
%
% Version 1.0 - 6/15/2015
%   The script fits a time series model to fusion result of a pixel.
%
% Updates of Version 1.1 - 6/17/2015
%   1.Added classification scheme into comments.
%   2.Optimazed the model for real data.
%   3.Added weighting system.
%
% Updates of Version 1.1.1 - 7/6/2015
%   1.Bugs fixed.
%   2.Tested.
%   3.Fixed a dimension bug.
%
% Updates of Version 2.0 - 7/12/2015
%   1.Completely redesigned the algorithm.
%   2.Fixed a major bug.
%
% Updates of Version 2.1 - 7/15/2015
%   1.Adjusted non-forest detection.
%   2.Added post change detection filtering.
%   3.Bug fixed.
%
% Released on Github on 3/31/2015, check Github Commits for updates afterwards.
%----------------------------------------------------------------

% Classification Scheme
%  -1 - Ineligible Observation
%   0 - Default Value
%   1 - Stable Forest
%   2 - Outlier (Cloud, Shadow ...)
%   3 - Break
%   4 - Changed
%   5 - Edge of change
%   6 - Stable Non-forest
%   7 - Edge of Non-forest

function CHG = change(TS,sets)
    
    % costomized settings
    % sets.minNoB = 10;
    % sets.initNoB = 5;
    % sets.nSD = 1.5;
    % sets.nCosc = 5;
    % sets.nSusp = 3;
    % sets.outlr = 1;
    % sets.nonfstmean = 10;
    % sets.nonfstdev = 0.3;
    % sets.nonfstedge = 5;
    % sets.weight = [1,1,1];
    % sets.band = [3,4,5];

    % analyse input TS 
    [nband,nob] = size(TS);
    
    % initilize result
    CHG = zeros(1,nob);
    ETS = 1:nob;
    sets.weight = sets.weight/sum(sets.weight);

    % complie eligible observations
    for i = nob:-1:1
        if max(TS(:,i)==-9999)
            CHG(i) = -1;
            ETS(i) = [];
        end
    end
    
    % check total number of eligible observation
    [~,neb] = size(ETS);
    if neb < sets.minNoB
        CHG = -1;
        return 
    end
        
    % initilization
    mainVec = TS(:,ETS(1:sets.initNoB));
    if sets.outlr > 0
        for i = 1:sets.outlr
            % remove outliers in the initial observations
            subMean = (sets.weight*mainVec);
            [~,TSmaxI] = max(subMean);
            [~,TSminI] = min(subMean);
            mainVec(:,[TSmaxI,TSminI]) = [];
        end
    end
    initMean = mean(mainVec,2);
    initStd = std(mainVec,0,2);
    CHGFlag = 0;
    
    % detect break
    for i = 1:length(ETS)
        
        % calculate metrics
        x = TS(:,ETS(i));
        xRes = abs(x-initMean);
        xNorm = xRes./initStd;
        xDev = sets.weight*xNorm;
        
        % check if possible change occured
        if xDev >= sets.nSD 
            % check if change already detected
            if CHGFlag == 1
                % set result to changed
                CHG(ETS(i)) = 4;
            else
                % see if this is a break
                if i < length(ETS)+1-sets.nCosc
                    nSusp = 1;
                    for k = (i+1):(i+sets.nCosc-1)
                        xk = TS(:,ETS(k));
                        xkRes = abs(xk-initMean);
                        xkNorm = xkRes./initStd;
                        xkDev = sets.weight*xkNorm;
                        if xkDev >= sets.nSD
                            nSusp = nSusp + 1;
                        end
                    end
                    if nSusp >= sets.nSusp
                        CHG(ETS(i)) = 3;
                        CHGFlag = 1;
                    else
                        CHG(ETS(i)) = 2;
                    end
                else
                    % this is an outlier
                    CHG(ETS(i)) = 2;
                end
            end
        else
            % check if change already detected
            if CHGFlag == 1
                % set result to edge of change
                CHG(ETS(i)) = 5;
            else
                % set result to stable
                CHG(ETS(i)) = 1;
                % update main vector
                if i > sets.initNoB
                    mainVec = [mainVec,TS(:,ETS(i))];  %#ok<*AGROW>
                    initMean = mean(mainVec,2);
                    initStd = std(mainVec,0,2);
                end
            end
        end

    end
    
    % post change detection refining
    % split data into pre-break and post-break
    if max(CHG==3) == 1
        % break exist
        preBreakClean = TS(:,CHG==1);
        preBreak = TS(:,(CHG>0)&(CHG<3));
        postBreak = TS(:,CHG>=3);
        CHGFlag = 1;
    else
        % no break
        preBreakClean = TS(:,CHG==1);
        CHGFlag = 0;
    end
    
    % see if pre-brake is non-forest
    pMean = sets.weight*abs(mean(preBreakClean,2));
    pSTD = sets.weight*abs(std(preBreakClean,0,2));
    if pMean >= sets.nonfstmean || pSTD >= sets.nonfstdev 
        % deal with stable non-forest pixel
        for i = 1:length(ETS)
            x = TS(:,ETS(i));
            if sets.weight*abs(x) >= sets.nonfstmean
                CHG(ETS(i)) = 6;
            else
                CHG(ETS(i)) = 7;
            end
        end
    else
        % pre-break is forest, check if post-break exist
        if CHGFlag == 1
            % compare pre-break and post-break
            if manova1([preBreak';postBreak'],[ones(size(preBreak,2),1);(ones(size(postBreak,2),1)*2)]) == 0
                % this is a false break
                CHG(CHG==3) = 2;
                CHG(CHG==4) = 2;
                CHG(CHG==5) = 1;
            end
        end
    end
    
    % done
    
end
