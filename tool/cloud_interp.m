% cloud_interp.m
% Version 1.2.1
%
% Project: Fusion
% By Xiaojing Tang
% Created On: 11/24/2014
% Last Update: 2/11/2015
%
% Input Arguments: 
%   path - path to MOD09SUB m-files.
%   res - resolusion of MODIS swath.
%   plat - paltform MOD/MYD
%   outFile - output file.
%   disThres - the cloud threshold for discarding the swath data.
%   
% Output Arguments: NA
%
% Usage: 
%   1.Generate MOD09SUB m-files with the main fusion codes.
%   2.Run this script with correct input arguments.
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
% Created on Github on 11/24/2014, check Github Commits for updates afterwards.
%----------------------------------------------------------------

function cloud_interp(path,res,plat,outFile,disThres)

  % set default value for disThres if not given
  if ~exist('disThres', 'var')
    disThres = 101;
  end

  % get list of all valid files in the input directory
  fileList = dir([path,plat,'09SUB*',num2str(res),'m*.mat']);

  % check if list is empty
  if numel(fileList)<1
    disp(['Cannot find any .mat file at ',num2str(res),'m resolution.']);
    return;
  end

  % initiate results
  perCloud = zeros(numel(fileList),1);
  dateYear = zeros(numel(fileList),1);
  dateDOY = zeros(numel(fileList),1);

  % loop through all files in the list
  for i = 1:numel(fileList)
    
    % load the .mat file
    MOD09SUB = load([path,fileList(i).name]);
  
    % total number of swath observation
    nPixel = numel(MOD09SUB.MODLine)*numel(MOD09SUB.MODSamp);
    
    % total cloudy
    nCloud = sum(MOD09SUB.QACloud(:));
    
    % insert result
    perCloud(i) = round(nCloud/nPixel*1000)/10;
    p = regexp(fileList(i).name,'\d\d\d\d\d\d\d');
    dateYear(i) = str2num(fileList(i).name(p:(p+3)));
    dateDOY(i) = str2num(fileList(i).name((p+4):(p+6)));
  
    % discard current swath if cloud percent larger than certain threshold
    dumpDir = [path '../DUMP/SUBCLD/'];
    if exist(dumpDir,'dir') == 0 
        mkdir(dumpDir);
    end
    if perCloud(i) > disThres
      system(['mv ',path,fileList(i).name,' ',dumpDir]);
    end
  
  end
  
  % save result
  r = [dateYear,dateDOY,perCloud];
  dlmwrite(outFile,r,'delimiter',',','precision',10);

  % done

end
