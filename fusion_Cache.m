% fusion_Cache.m
% Version 1.0.1
% Step 7
% Cache Fusion Time Series
%
% Project: New Fusion
% By xjtang
% Created On: 6/15/2015
% Last Update: 7/1/2015
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
%   This script caches the Landsat style fusion time series into mat files.
%
% Updates of Version 1.0.1 - 7/5/2015
%   1.Fixed a bug caused by two digit landsat scene.
%   2.Fixed a bug of num to str conversion.
%   3.Fixed a nband bug.
%
% Released on Github on 6/15/2015, check Github Commits for updates afterwards.
%----------------------------------------------------------------

function fusion_Cache(main)

    % get ETM image size
    samp = length(main.etm.sample);
    line = length(main.etm.line);
    nband = main.etm.band;
    
    % calculate the lines that will be processed by this job
    njob = main.set.job(2);
    thisjob = main.set.job(1);
    if njob >= thisjob && thisjob >= 1 
        % subset lines
        jobLine = thisjob:njob:line;
    else
        jobLine = 1:line;
    end
    
    % start timer
    tic;
    
    % find existing fusion time series images
    fusImage = dir([main.output.dif 'M*D' num2str(main.set.scene(1),'%03d') num2str(main.set.scene(2),'%03d') '*']);
    
    % get dates of images
    TS.Date = ones(numel(fusImage),2);
    for i = 1:numel(fusImage)
        TS.Date(i,1) = str2double(fusImage(i).name(10:16));
        TS.Date(i,2) = str2double(fusImage(i).name(18:21));
    end
    TS.Date = int32(TS.Date);
    
    % line by line processing
    for i = jobLine
        
        % check if this line is already processed
        File.Check = dir([main.output.cache 'ts.r' num2str(i) '.cache.mat']);
        if numel(File.Check) >= 1
            disp([num2str(i) ' line already exist, skip this line.']);
            continue;
        end
        
        % initialize
        TS.Data = ones(samp,numel(fusImage),nband-1+2)*(-9999);
        
        % loop through images
        for j = i:numel(fusImage)
            
            % find image stack
            imgStack = dir([main.output.dif fusImage(j).name '/' fusImage(j).name '_stack']);
            
            % check if image exist
            File.Check = dir(imgStack);
            if numel(File.Check) >= 1
                disp([fusImage(j).name ' image does not exist, skip this date.']);
                continue;
            end
            
            % load specific line from image
            IMG = multibandread(imgStack,[line,samp,nband],'int16',0,main.etm.interleave,'ieee-le',{'Row',i});
            
            % assign data 
            TS.Data(:,j,:) = squeeze(IMG);
            
        end
        
        % save current line
        save([main.output.cache 'ts.r' num2str(i) '.cache.mat'],'-struct','TS')
        disp(['Done with line',num2str(i),' in ',num2str(toc,'%.f'),' seconds']);    
        
    end

    % done
    
end
