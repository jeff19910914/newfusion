% fusion_Change.m
% Version 1.5
% Step 8
% Detect Change
%
% Project: New Fusion
% By xjtang
% Created On: 7/1/2015
% Last Update: 11/3/2015
%
% Input Arguments: 
%   main (Structure) - main inputs of the fusion process generated by fusion_inputs.m.
%
% Output Arguments: NA
%
% Instruction: 
%   1.Customize a config file for your project.
%   2.Run fusion_Inputs() first and get the returned structure of inputs
%   3.Run previous steps first to make sure required data are already generated.
%   4.Run this function with the stucture of inputs as the input argument.
%
% Version 1.0 - 7/1/2015
%   This script detect change in fusion time series.
%
% Updates of Version 1.0.1 - 7/6/2015
%   1.Fxied a num2str conversion bug.
%   2.Fixed a variable bug.
%   3.Fixed a band id bug.
%
% Updates of Version 1.1 - 7/7/2015
%   1.Made adjustment for major change in core algorithm.
%   2.Fixed a output bug.
%
% Updates of Version 1.2 - 7/10/2015
%   1.Adjusted cloud mask so 250 and 500 data will get separate mask.
%
% Updates of Version 1.3 - 8/18/2015
%   1.Disable the extra cloud masking.
%
% Updates of Version 1.4 - 9/25/2015
%   1.Records model coefficients in the output.
%
% Updates of Version 1.4.1 - 10/18/2015
%   1.Disabled a sentence that may cause error.
%   2.Adjusted for a major update in the core function.
%   3.Pass fusion TS segment class codes to core function.
%   4.Implement model constants.
%
% Updates of Version 1.5 - 11/3/2015
%   1.Added study time period control system.
%   2.Passes time series dates to change detection.
%   3.Passes model constants to change detection.
%
% Released on Github on 7/1/2015, check Github Commits for updates afterwards.
%----------------------------------------------------------------

function fusion_Change(main)

    % calculate the lines that will be processed by this job
    njob = main.set.job(2);
    thisjob = main.set.job(1);
    if njob >= thisjob && thisjob >= 1 
        % subset lines
        jobLine = thisjob:njob:length(main.etm.line);
    else
        jobLine = 1:length(main.etm.line);
    end

    % start timer
    tic;

    % line by line processing
    for i = jobLine
        
        % check if result already exist
        File.Check = dir([main.output.chgmat 'ts.r' num2str(i) '.chg.mat']);
        if numel(File.Check) >= 1
            disp([num2str(i) ' line already exist, skip this line.']);
            continue;  
        end
        
        % check if cache exist
        File.Check = dir([main.output.cache 'ts.r' num2str(i) '.cache.mat']);
        if numel(File.Check) == 0
            disp([num2str(i) ' line cache does not exist, skip this line.']);
            continue;
        end
        
        % load TS cache
        TS = load([main.output.cache 'ts.r' num2str(i) '.cache.mat']);
        samp = size(TS.Data,1);
        
        % study time period control
        TS.Data = TS.Data(:,TS.Date(:,1)>=main.set.sdate,:); 
        TS.Date = TS.Date(TS.Date(:,1)>=main.set.sdate,:); 
        TS.Data = TS.Data(:,TS.Date(:,1)<=main.set.edate,:); 
        TS.Date = TS.Date(TS.Date(:,1)<=main.set.edate,:); 
        NRT = sum(TS.Date(:,1)<main.set.cdate);
        
        % initialize
        nday = size(TS.Data,2);
        CHG.Date = TS.Date;
        CHG.Data = ones(samp,nday)*(main.cons.outna);
        CHG.Coef = ones(12,samp,length(main.model.band)+1)*(main.cons.outna);
        
        % pixel by pixel processing
        for j = 1:samp
            
            % compose data
            PTS = (squeeze(TS.Data(j,:,main.model.band)))';
            % detect change
            [CHG.Data(j,:),CHG.Coef(:,j,:)] = change(PTS,TS.Date(:,1)',main.model,main.cons,main.TSclass,NRT);
            
        end
        
        % save current file
        save([main.output.chgmat 'ts.r' num2str(i) '.chg.mat'],'-struct','CHG')
        disp(['Done with line',num2str(i),' in ',num2str(toc,'%.f'),' seconds']); 
        
    end
    
    % done
    
end

