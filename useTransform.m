%{
This script registers localisation files from multi-colour single molecule
localisation experiments. The script reads the localisation files and uses
a polynomial transform (obtained using calibration sub-diffractive beads)
to register its coordinates to the images of a reference channel.
(To get the transform, use the script 'getTransform_multiCol.m').

In order for the code to work, you have to follow a specific naming
convention, and put the transform in the same folder as your images that
need to be transformed. The naming convention for the localization files
for 3-col registration would be:
      a1_488.csv,  a2_488.csv,  a3_488.csv,
      a1_561.csv,  a2_561.csv,  a3_561.csv,   etc.
      a1_647.csv,  a2_647.csv,  a3_647.csv,
where 'a' is called the area_token and '_488','_561', '_647' the channel_
tokens. The area_token can be anything, but you have to specify it in the
parameters below. The channel tokens also have to be specified in a cell.

The names of the transforms should then be something like this:
      Trafo_tform_488.mat
      Trafo_tform_561.mat
if 647 is your reference channel. The 'Trafo_tform' in the transform
filename can be any string. Only the '_488.mat' and '_561.mat' are
important for the script to know which transform to use on which data.

If you, for example, set the area_token to 'a1', the script will only
transform the localization files 'a1'. If you set it to 'a', it will
transform all localization files that start with 'a' (it will add numbers
to this area_token to get a1, a2, a3, ... aN and register all of them).

Author: Pedro Vallejo Ramirez
Laser Analytics Group
Updated: 02/08/2018

This script depends on function:
  ReadLocFile_thunder.m
%}

clear all
close all
clc

%% Parameters
DefaultPath   = 'E:\Experiments\synaptosomes\2018_08_15_Pedro_ezra_synaptosomes_4thRound_PHYS\input\output_reconstructions'; % some directory
software      = 'thunder'; % 'rapid' or 'thunder' for rapidSTORM or ThunderSTORM reconstructions
area_token    = 'a'; % e.g. 'a' if files are called 'a1_488.tif', 'a2_488.tif', ...
RefCh_token   = '_647'; % reference channel (e.g. red: '_647')
tformCh_token = {'_488'}; % channel(s) to be transformed
show_plots    = 'off'; % show plots:'off' or 'on'

%%

% Get directory containing thunderSTORM localization files
PathName = uigetdir(DefaultPath, 'Choose directory containing the localization files...');

% Create new output folder
output_dir_path = fullfile(PathName,'Registered_data');
if exist(output_dir_path, 'dir')
    opts.Interpreter = 'tex';
    opts.Default = 'Yes';
    quest = '\fontsize{12}An output folder ''Registered\_data'' already exists. If you continue, data in this folder might be overwritten.';
    answer = questdlg(quest,'Message','Cancel','Yes',opts);
else
    mkdir(output_dir_path);
end

% Check whether output is from rapidSTORM or ThunderSTORM
if strcmp(software,'rapid')
    type = '.txt';
else
    type = '.csv';
end

% Loop over all channels
for i=1:length(tformCh_token)

    % Get current channel_token
    channel_token = tformCh_token(i);
    channel_token = channel_token{1};
    
    % Get list of files in the directory matching area_token and channel_token
    FileList = dir([PathName,filesep,area_token,'*',channel_token,type]);
    if isempty(FileList)
        disp('No files matching user-specified area_token or channel_token found in directory.')
        return
    end
    % Get number of files in FileList_GC
    N_files = length(FileList);
    
    % Loop over all GC files and transform them
    for j=1:N_files
        
        % Get current area_token
        if N_files==1
            area_token_i = area_token;
        else
            area_token_i = strcat(area_token,num2str(j));
        end

        % Name of the current file
        current_file = strcat(area_token_i,channel_token,'.csv');
        disp(fullfile(PathName, current_file));

        % Read localisation data and obtain x- and y-coordinates
        if strcmp(software,'thunder')
            LocInfo = ReadLocFile_thunder(fullfile(PathName, current_file));
            X_d = LocInfo{:,2};
            Y_d = LocInfo{:,3};
        elseif strcmp(software,'rapid')
            LocInfo = Read_LocFile(fullfile(PathName, current_file),0);
            X_d = LocInfo{:,1};
            Y_d = LocInfo{:,2};
        end 
        
        % Get the transform
        FileName = dir([PathName,filesep,'*',channel_token,'.mat']);
        FileName = FileName.name;
        load(fullfile(PathName, FileName));

        % Apply the obtained transform
        %[U,V] = tforminv(tform,X_d,Y_d);
        [U,V] = transformPointsInverse(tform,X_d,Y_d);

        % Display
        figure('Color','white','name','Scatter plot (raw)','visible',show_plots);
        plot(X_d,Y_d,'+')
        hold on
        plot(U,V,'r+')
        axis equal

        % Replace x and y coordinates by the transformed ones
        LocInfo.x = U;
        LocInfo.y = V;

        % Save the registered localization file
        newname = strcat(strsplit(current_file,'.'),'_reg.csv');
        newname = newname{1};
        LocInfo = table2array(LocInfo);
        fid = fopen(fullfile(output_dir_path,newname),'wt');
        header = 'frame,x [nm],y [nm],sigma [nm],intensity [photon],offset [photon],bkgstd [photon],uncertainty [nm]\n';
        fprintf(fid,header);
        if fid > 0
            fprintf(fid,'%f,%f,%f,%f,%f,%f,%f,%f\n',LocInfo');
            fclose(fid);
        end
    end
end