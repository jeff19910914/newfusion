% fusion_Cloud.m
% Version 2.1.2
% Step 3
%
% Project: New Fusion
% By xjtang
% Created On: 11/24/2014
% Last Update:12/6/2015
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
% Version 1.0 - 11/25/2014
%   This script generates plot and table for cloud statistics of the MOD09SUB data.
%   
% Updates of Version 1.1 - 11/26/2014
%   1.Seperate year and doy.
%
% Updates of Version 1.2 - 12/12/2014
%   1.Added support for aqua.
%   2.Added a new function of discarding cloudy swath based on cloud percent threshold.
%
% Updates of Version 1.2.1 - 2/11/2015
%   1.Bug fixed.
%
% Updates of Version 1.3 - 4/6/2015
%   1.Combined 250m and 500m fusion.
%
% Updates of Version 1.3.1 - 7/1/2015
%   1.Adde Landsat scene information.
%
% Update of Version 2.0 - 8/25/2015
%   1.Promoted into a main function.
%
% Updates of Version 2.1 - 9/14/2015
%   1.Exports a list of dates for generating synthetic images.
%   2.Automatically clears the dump folder.
%   3.Fixed a bug.
%
% Updates of Version 2.1.1 - 11/20/2015
%   1.Fixed a bug that cause the image list to have a 0.
%	2.Fixed a removing file bug.
%
% Updates of Version 2.1.2 - 12/6/2015
%   1.Added support for combining terra and aqua.
%   2.Get output filenames from main input.
%
% Created on Github on 11/24/2014, check Github Commits for updates afterwards.
%----------------------------------------------------------------

function fusion_Cloud(main)

	% get list of all valid files in the input directory
    if strcmp(main.set.plat,'ALL')
        fileList = dir([main.output.modsub,'M*D','09SUB*','ALL*.mat']);
    else
        fileList = dir([main.output.modsub,main.set.plat,'09SUB*','ALL*.mat']);
    end

    % check if list is empty
    if numel(fileList)<1
        disp('Cannot find any .mat file.');
        return;
    end

    % initiate results
    perCloud = zeros(numel(fileList),1);
    dateYear = zeros(numel(fileList),1);
    dateDOY = zeros(numel(fileList),1);
    dateFull = zeros(numel(fileList),1);
    plat = zeros(numel(fileList),1);

    % clear dump dir
    dumpDir = [main.output.dump 'SUBCLD/'];
    if exist(dumpDir,'dir') == 0 
        mkdir(dumpDir);
    end
    if numel(dir(dumpDir)) > 0
        system(['rm ',dumpDir,'*']);
    end

    % loop through all files in the list
    for i = 1:numel(fileList)
        
        % record platform
        fileName = char(fileList(i).name);
        thisPlat = fileName(regexp(fileName,'M.?D'):(regexp(fileName,'M.?D')+2));
        if strcmp(thisPlat,'MOD')
            plat(i) = 1;
        elseif strcmp(thisPlat,'MYD')
            plat(i) = 2;
        else
            plat(i) = 0;
        end
        
        % load the .mat file
        MOD09SUB = load([main.output.modsub,fileList(i).name]);

        % total number of swath observation
        nPixel = numel(MOD09SUB.MODLine250)*numel(MOD09SUB.MODSamp250);

        % total cloudy
        nCloud = sum(MOD09SUB.QACloud250(:));

        % insert result
        perCloud(i) = round(nCloud/nPixel*1000)/10;
        p = regexp(fileList(i).name,'\d\d\d\d\d\d\d');
        dateYear(i) = str2double(fileList(i).name(p:(p+3)));
        dateDOY(i) = str2double(fileList(i).name((p+4):(p+6)));

        % discard current swath if cloud percent larger than certain threshold
        if perCloud(i) > main.set.cloud
            system(['mv ',main.output.modsub,fileList(i).name,' ',dumpDir]);
        else
            % add to synthetic image list
            dateFull(i) = str2double(fileList(i).name(p:(p+6)));
        end

    end
  
    % save result
    if exist(main.log.cloud,'file')
        disp('Cloud file already exist, overwrite.');
        system(['rm ',main.log.cloud]);
    end
    r = [dateYear,dateDOY,perCloud,plat];
    dlmwrite(main.log.cloud,r,'delimiter',',','precision',10);
    
    % make a image list for generating synthetic images
    if exist(main.log.syn,'file') 
        disp('Image list already exist, overwrite.');
        system(['rm ',main.log.syn]);
    end
    r = unique(dateFull);
    dlmwrite(main.log.syn,r(r>0),'delimiter',',','precision',10);

    % done

end
