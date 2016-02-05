% fusion_BRDF.m
% Version 6.2.2
% Step 1
% BRDF Correction
%
% Project: New Fusion
% By: xjtang
% Created On: Unknown
% Last Update: 10/27/2015
%
% Input Arguments: 
%   main (Structure) - main inputs of the fusion process generated by fusion_inputs.m.
% 
% Output Arguments: NA
%
% Instruction: 
%   1.Customize a config file for your project.
%   2.Run fusion_Inputs() first and get the returned structure of inputs
%   3.Run this function with the stucture of inputs as the input argument.
%
% Version 6.0 - Unknown (by Q. Xin)
%   This script extracts MOD43A1 (BRDF parameters) data and reproject them to match Landat image.
%
% Updates of Version 6.1 - 10/1/2014
%   1.Updated comments.
%   2.Changed coding style.
%   3.Modified for work flow of fusion version 6.1.
%   4.Changed from script to function
%   5.Modified the code to incorporate the use of fusion_inputs structure.
%   6.User gdal_translate instead of MRT to resample.
%   7.The code now creates the BRDF coefficinet output file by itself.
%
% Updates of Version 6.2 - 11/24/2014
%   1.Added support for MODIS Aqua.
%
% Updates of Version 6.2.1 - 7/5/2015
%   1.Fixed a major bug that may cause error when having multiple jobs.
%   2.Fixed a bug that may cause unecessary calculation.
%
% Updates of Version 6.2.2 - 10/27/2015
%   1.Implement model constants.
%   2.Fixed a bug.
%
% Released on Github on 10/15/2014, check Github Commits for updates afterwards.
%----------------------------------------------------------------
%
function fusion_BRDF(main)

    % read files parameters
    % [ETMGeo,~,FileName]=ParameterSBR;

    % start the timer
    tic;
    
    % get platform information
    plat = main.set.plat;
    
    % loop through all files
    for I_Day = 1:numel(main.date.swath)
        
        % construct file names based of the julian day of the image
        Day = main.date.swath(I_Day);
        DayStr = num2str(Day);
        % DayStr = [num2str(year(Day)),num2str(Day-datenum(year(Day),1,1)+1,'%03d')];
        BRDFDay = Day-mod(Day-main.date.brdf(1),8);
        BRDFDayStr = num2str(BRDFDay);
        % BRDFDayStr = [num2str(year(BRDFDay)),num2str(BRDFDay-datenum(year(BRDFDay),1,1)+1,'%03d')];

        % find input files
        File.MOD09GA = dir([main.input.grid,plat,'09GA.A',DayStr,'*']);
        File.MCD43A1 = dir([main.input.brdf,'MCD43A1.A',BRDFDayStr,'*']);
        File.MODBRDF = [main.output.modBRDF,plat,'BRDF.A',DayStr,'.hdf'];
        File.ETMBRDF = [main.output.etmBRDF,'ETM',plat,'BRDF_A',DayStr];
        
        % create output file
        ori = [main.input.grid File.MOD09GA.name];
        des = File.MODBRDF;
        if exist(des,'file')>0 
            disp([des ' already exist, skip step one']);
        else
            % copy file
            system(['cp ',ori,' ',des]);

            % make sure all files exist
            if numel(File.MOD09GA)<1
                disp(['Cannot find MOD09GA for Julian Day: ', DayStr]);
                continue;
            elseif numel(File.MCD43A1)<1
                disp(['Cannot find MCD43A1 for Julian Day: ', DayStr]);
                continue;
            elseif numel(File.MODBRDF)<1
                disp(['Cannot find MODBRDF for Julian Day: ', DayStr]);
                continue;
            end

            % read parameters of red and nir band for brdf correction
            ParamRED = double(hdfread([main.input.brdf,File.MCD43A1.name],'BRDF_Albedo_Parameters_Band1'));
            ParamNIR = double(hdfread([main.input.brdf,File.MCD43A1.name],'BRDF_Albedo_Parameters_Band2'));
            ParamBLU = double(hdfread([main.input.brdf,File.MCD43A1.name],'BRDF_Albedo_Parameters_Band3'));
            ParamGRE = double(hdfread([main.input.brdf,File.MCD43A1.name],'BRDF_Albedo_Parameters_Band4'));
            ParamSWIR = double(hdfread([main.input.brdf,File.MCD43A1.name],'BRDF_Albedo_Parameters_Band6'));
            ParamSWIR2 = double(hdfread([main.input.brdf,File.MCD43A1.name],'BRDF_Albedo_Parameters_Band7'));

            % read sensor geometry information
            VZA1km = double(hdfread([main.input.grid,File.MOD09GA.name],'SensorZenith_1'));
            VAA1km = double(hdfread([main.input.grid,File.MOD09GA.name],'SensorAzimuth_1'));
            SZA1km = double(hdfread([main.input.grid,File.MOD09GA.name],'SolarZenith_1'));
            SAA1km = double(hdfread([main.input.grid,File.MOD09GA.name],'SolarAzimuth_1'));

            % clean up the parameters
            ParamBLU(ParamBLU>main.cons.mcdna) = nan;
            ParamBLU = ParamBLU/main.cons.mcdsf;
            ParamGRE(ParamGRE>main.cons.mcdna) = nan;
            ParamGRE = ParamGRE/main.cons.mcdsf;
            ParamRED(ParamRED>main.cons.mcdna) = nan;
            ParamRED = ParamRED/main.cons.mcdsf;
            ParamNIR(ParamNIR>main.cons.mcdna) = nan;
            ParamNIR = ParamNIR/main.cons.mcdsf;
            ParamSWIR(ParamSWIR>main.cons.mcdna) = nan;
            ParamSWIR = ParamSWIR/main.cons.mcdsf;
            ParamSWIR2(ParamSWIR2>main.cons.mcdna) = nan;
            ParamSWIR2 = ParamSWIR2/main.cons.mcdsf;

            % clean up sensor geometry
            VZA1km(VZA1km<-main.cons.mcdna) = nan; 
            VAA1km(VAA1km<-main.cons.mcdna) = nan; 
            SZA1km(SZA1km<-main.cons.mcdna) = nan; 
            SAA1km(SAA1km<-main.cons.mcdna) = nan; 

            % split 1000m pixels into 500m pixels
            VZA500 = kron(VZA1km,ones(2))/main.cons.angsf;
            VAA500 = kron(VAA1km,ones(2))/main.cons.angsf;
            SZA500 = kron(SZA1km,ones(2))/main.cons.angsf;
            SAA500 = kron(SAA1km,ones(2))/main.cons.angsf;

            % relative azimuth angle
            RAA500 = mod(abs(SAA500-VAA500),180);

            % brdf coefficient calculation
            ReflBLU = brdffoward(ParamBLU(:,:,1),ParamBLU(:,:,2),ParamBLU(:,:,3),SZA500,VZA500,RAA500);
            NadirReflBLU = brdffoward(ParamBLU(:,:,1),ParamBLU(:,:,2),ParamBLU(:,:,3),SZA500,zeros(2400),zeros(2400));
            CoeffBLU = ReflBLU./NadirReflBLU*main.cons.mcdsf;

            ReflGRE = brdffoward(ParamGRE(:,:,1),ParamGRE(:,:,2),ParamGRE(:,:,3),SZA500,VZA500,RAA500);
            NadirReflGRE = brdffoward(ParamGRE(:,:,1),ParamGRE(:,:,2),ParamGRE(:,:,3),SZA500,zeros(2400),zeros(2400));
            CoeffGRE = ReflGRE./NadirReflGRE*main.cons.mcdsf;

            ReflRED = brdffoward(ParamRED(:,:,1),ParamRED(:,:,2),ParamRED(:,:,3),SZA500,VZA500,RAA500);
            NadirReflRED = brdffoward(ParamRED(:,:,1),ParamRED(:,:,2),ParamRED(:,:,3),SZA500,zeros(2400),zeros(2400));
            CoeffRED = ReflRED./NadirReflRED*main.cons.mcdsf;

            ReflNIR = brdffoward(ParamNIR(:,:,1),ParamNIR(:,:,2),ParamNIR(:,:,3),SZA500,VZA500,RAA500);
            NadirReflNIR = brdffoward(ParamNIR(:,:,1),ParamNIR(:,:,2),ParamNIR(:,:,3),SZA500,zeros(2400),zeros(2400));
            CoeffNIR = ReflNIR./NadirReflNIR*main.cons.mcdsf;

            ReflSWIR = brdffoward(ParamSWIR(:,:,1),ParamSWIR(:,:,2),ParamSWIR(:,:,3),SZA500,VZA500,RAA500);
            NadirReflSWIR = brdffoward(ParamSWIR(:,:,1),ParamSWIR(:,:,2),ParamSWIR(:,:,3),SZA500,zeros(2400),zeros(2400));
            CoeffSWIR = ReflSWIR./NadirReflSWIR*main.cons.mcdsf;

            ReflSWIR2 = brdffoward(ParamSWIR2(:,:,1),ParamSWIR2(:,:,2),ParamSWIR2(:,:,3),SZA500,VZA500,RAA500);
            NadirReflSWIR2 = brdffoward(ParamSWIR2(:,:,1),ParamSWIR2(:,:,2),ParamSWIR2(:,:,3),SZA500,zeros(2400),zeros(2400));
            CoeffSWIR2 = ReflSWIR2./NadirReflSWIR2*main.cons.mcdsf;

            % save BRDF Coefficient to MOD09BRDF
            writeHDF(File.MODBRDF,12,int16(CoeffBLU));
            writeHDF(File.MODBRDF,13,int16(CoeffGRE));
            writeHDF(File.MODBRDF,10,int16(CoeffRED));
            writeHDF(File.MODBRDF,11,int16(CoeffNIR));
            writeHDF(File.MODBRDF,15,int16(CoeffSWIR));
            writeHDF(File.MODBRDF,16,int16(CoeffSWIR2));
        
        end
        
        if exist(File.ETMBRDF,'file')>0
            disp([des ' already exist, skip step one']);
            continue;
        end
        
        % resample to Landsat size using gdal
        bash = [fileparts(mfilename('fullpath')),'/core/BRDFReproj.sh'];
        system(['chmod u+x ',bash]);
        system([bash,' ',File.MODBRDF,' ',num2str(main.etm.utm),' ',num2str(main.etm.ulEast),' ',...
            num2str(main.etm.lrNorth),' ',num2str(main.etm.lrEast),' ',num2str(main.etm.ulNorth),' ',...
            num2str(main.etm.res(1)),' ',num2str(main.etm.res(2)),' ',File.ETMBRDF,' ',num2str(main.set.job(1))]);

        % display message and end timer
        disp(['Done with ',DayStr,' in ',num2str(toc,'%.f'),' seconds']);
        
        % Create MRT Param to reprpject MOD09BRDF to landsat scale Band: RED, NIR
        % FilePrm = fopen([FileName.MODBRDFParam,'MODBRDF.A',DayStr,'.prm'],'wt');
        % if FilePrm<0
        %     error('Cannot open MRT Param files to write');
        % end
        % fprintf(FilePrm,['INPUT_FILENAME =',FileName.MODBRDF,File.MODBRDF.name,'\n',...
        %     'OUTPUT_FILENAME =',FileName.ETMBRDF,'ETMBRDF',File.MODBRDF.name(8:end),'\n',...
        %     'SPECTRAL_SUBSET = ( 0 0 0 0 0 0 0 0 0 0 1 1 0 0 0 0 0 0 0 0 0 )','\n',...
        %     'SPATIAL_SUBSET_TYPE = OUTPUT_PROJ_COORDS','\n'...
        %     'SPATIAL_SUBSET_UL_CORNER = (',num2str(ETMGeo.ULEasting,'%.1f'),' ',num2str(ETMGeo.ULNorthing,'%.1f'),')\n',...
        %     'SPATIAL_SUBSET_LR_CORNER = (',num2str(ETMGeo.LREasting,'%.1f'),' ',num2str(ETMGeo.LRNorthing,'%.1f'),')\n',...
        %     'RESAMPLING_TYPE = NEAREST_NEIGHBOR','\n','OUTPUT_PROJECTION_TYPE = UTM','\n'...
        %     'OUTPUT_PROJECTION_PARAMETERS = ( ','\n','0.0 0.0 0.0','\n','0.0 0.0 0.0','\n',...
        %     '0.0 0.0 0.0','\n','0.0 0.0 0.0','\n','0.0 0.0 0.0 )','\n','DATUM = WGS84','\n',...
        %     'UTM_ZONE = ',num2str(ETMGeo.Zone,'%.0f'),'\n','OUTPUT_PIXEL_SIZE = 30','\n']);
        % [~]=fclose(FilePrm);
        % system(['resample -p ',FileName.MODBRDFParam,'MODBRDF.A',DayStr,'.prm']);
        
    end
    
    % done

end