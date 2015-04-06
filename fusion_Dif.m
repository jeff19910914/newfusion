% fusion_Dif.m
% Version 1.3
% Step 5
% Change Detection
%
% Project: Fusion
% By Xiaojing Tang
% Created On: 12/16/2014
% Last Update: 4/6/2015
%
% Input Arguments: 
%   main (Structure) - main inputs of the fusion process generated by
%     fusion_inputs.m.
%
% Output Arguments: NA
%
% Usage: 
%   1.Customize the main input file (fusion_inputs.m) with proper settings
%       for specific project.
%   2.Run fusion_Inputs() first and get the returned structure of inputs
%   3.Run previous steps first to make sure required data are already
%       generated.
%   4.Run this function with the stucture of inputs as the input argument.
%
% Version 1.0 - 1/19/2015
%   This script creates difference and change image for the fusion process.
%
% Updates of Version 1.1 - 1/21/2015
%   1.Added support for brdf correction.
%
% Updates of Version 1.1.1 - 2/12/2015
%   1.Added a toggle for bias correction.
%   2.Bug fixed.
%
% Updates of Version 1.2 - 3/31/2015
%   1.Removed the old change detection module
%
% Updates of Version 1.3 - 4/6/2015
%   1.Combined 250 and 500 fusion.
%   2.Bug fixed.
%
% Released on Github on 12/16/2014, check Github Commits for updates afterwards.
%----------------------------------------------------------------

function fusion_Dif(main)

    % start timer
    tic;
    
    % check platform
    plat = main.set.plat;
    
    % loop through all etm images
    for I_Day=1:numel(main.date.swath)
        
        % get date information of all images
        Day = main.date.swath(I_Day);
        DayStr = num2str(Day);

        % check if result already exist
        File.Check = dir([main.output.modsubd plat '*' 'ALL' '*' DayStr '*']);
        if numel(File.Check) >= 1
            disp([DayStr ' already exist, skip this date.']);
            continue;
        end

        % find MOD09SUB files
        File.MOD09SUB = dir([main.output.modsubf,plat,'09SUB*.','ALL','*',DayStr,'*']);

        if numel(File.MOD09SUB)<1
            disp(['Cannot find MOD09SUB for Julian Day: ', DayStr]);
            continue;
        end

        % loop through MOD09SUB file of current date
        for I_TIME = 1:numel(File.MOD09SUB)
            TimeStr = regexp(File.MOD09SUB(I_TIME).name,'\.','split');
            TimeStr = char(TimeStr(4));

            % load MOD09SUBBRDF
            BRDFlag = main.set.brdf;
            if BRDFlag == 1
                File.MOD09SUBB = dir([main.output.modsubbrdf,plat,'09SUBFB.','ALL.',DayStr,'.',TimeStr,'.mat']);
                if numel(File.MOD09SUB) < 1
                    disp(['Cannot find MOD09SUBFB for Julian Day: ', DayStr]);
                    disp(['Only non-BRDF corrected results are produced for Julian Day: ', DayStr]);
                    BRDFlag = 0;
                end
            end
            
            % load MOD09SUB or MOD09SUBBRDF
            if BRDFlag == 1 
                MOD09SUB = load([main.output.modsubbrdf,File.MOD09SUBB.name]);
            else
                MOD09SUB = load([main.output.modsubf,File.MOD09SUB(I_TIME).name]);
            end

            % make difference and change maps
            [MOD09SUB.DIF09RED250,~] = swathDIF(MOD09SUB.MOD09RED250,...
                MOD09SUB.FUS09RED250,MOD09SUB.QACloud250,1,400,1,main.set.bias);
            [MOD09SUB.DIF09NIR250,~] = swathDIF(MOD09SUB.MOD09NIR250,...
                MOD09SUB.FUS09NIR250,MOD09SUB.QACloud250,1,600,1,main.set.bias);
            [MOD09SUB.DIF09RED500,~] = swathDIF(MOD09SUB.MOD09RED500,...
                MOD09SUB.FUS09RED500,MOD09SUB.QACloud500,1,400,1,main.set.bias);
            [MOD09SUB.DIF09NIR500,~] = swathDIF(MOD09SUB.MOD09NIR500,...
                MOD09SUB.FUS09NIR500,MOD09SUB.QACloud500,1,600,1,main.set.bias);
            [MOD09SUB.DIF09BLU500,~] = swathDIF(MOD09SUB.MOD09BLU500,...
                MOD09SUB.FUS09BLU500,MOD09SUB.QACloud500,1,200,1,main.set.bias);
            [MOD09SUB.DIF09GRE500,~] = swathDIF(MOD09SUB.MOD09GRE500,...
                MOD09SUB.FUS09GRE500,MOD09SUB.QACloud500,1,200,1,main.set.bias);
            [MOD09SUB.DIF09SWIR500,~] = swathDIF(MOD09SUB.MOD09SWIR500,...
                MOD09SUB.FUS09SWIR500,MOD09SUB.QACloud500,1,500,1,main.set.bias);
            [MOD09SUB.DIF09SWIR2500,~] = swathDIF(MOD09SUB.MOD09SWIR2500,...
                MOD09SUB.FUS09SWIR2500,MOD09SUB.QACloud500,1,400,1,main.set.bias);
            % calculate ndvi and ndvi change and dif images
            MOD09SUB.MOD09NDVI250 = (MOD09SUB.MOD09NIR250-MOD09SUB.MOD09RED250)...
                ./(MOD09SUB.MOD09NIR250+MOD09SUB.MOD09RED250);
            MOD09SUB.FUS09NDVI250 = (MOD09SUB.FUS09NIR250-MOD09SUB.FUS09RED250)...
                ./(MOD09SUB.FUS09NIR250+MOD09SUB.FUS09RED250);
            [MOD09SUB.DIF09NDVI250,~] = swathDIF(MOD09SUB.MOD09NDVI250,...
                MOD09SUB.FUS09NDVI250,MOD09SUB.QACloud250,1,0.2,1,main.set.bias);

            % save
            save([main.output.modsubd,plat,'09SUBD.','ALL.',DayStr,'.',TimeStr,'.mat'],'-struct','MOD09SUB');
            disp(['Done with ',DayStr,' in ',num2str(toc,'%.f'),' seconds']);
        end
    end

    % done
    
end
