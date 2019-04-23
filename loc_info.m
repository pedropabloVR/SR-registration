%{
This function returns the x,y coordinates and the intensity of a single
molecule localisation file.

Author: Pedro Vallejo Ramirez, Laser Analytics Group
Modified by Ezra Bruggeman to include a double quality control step (filtering
based on sigma (default sigma < 200) and exclusion of localizations that are
too close together to ensure correct association).

Last updated: 21 Aug 2018

Depends on function:
  ReadLocFile.m
  ReadLocFileThunder.m
  QualityControl.m
%}

function [X,Y,counts,vars,precision] = loc_info(Path, pix_size, area_token, ...
    channel_token, software, sigma_max, r_min,show)

% Check whether output is from rapidSTORM or ThunderSTORM
if strcmp(software,'rapid')
    type = '.txt';
else
    type = '.csv';
end

% Get list of files matching area_token, channel_token and type
FileList_ch = dir([Path,filesep,area_token,channel_token,type]);
% Get number of files in FileList_ch
N_files = length(FileList_ch);

% Initialize cells that will contain ...
FileNames_ch = cell(N_files,1); % Filename
X            = cell(1,N_files); % X-coordinates
Y            = cell(1,N_files); % Y-coordinates
counts       = cell(1,N_files); % Intensity in counts
loc          = cell(1,N_files); % Localization ID
precision    = cell(1,N_files); % Localisation precision

% If the files are rapidSTORM reconstruction data
if strcmp(software,'rapid')
    for i = 1:N_files
        
        % Get filename and details
        FileNames_ch{i} = [Path, filesep, FileList_ch(i).name];
        LocFile = Read_LocFile([FileNames_ch{i}], 1);
        vars = 0;
        
        % Print some information to the command window
        disp(['Opening: ',(FileList_ch(i).name)]);
        disp(['Number of localizations: ', num2str(size(LocFile,1))]);
        
        % Filter out beads that are too big, and localizations that are too close together
        LocFile = QualityControl(LocFile, r_min, sigma_max,show);
        
        % Get coordinates, intensity and localizations IDs
        X{1,i}          = LocFile(:,1)/pix_size;
        Y{1,i}          = LocFile(:,2)/pix_size;
        counts{1,i}     = LocFile(:,4);
        loc{1,i}        = (size(LocFile,1));
        precision{1,i}  = LocFile(:,9);
    end
    
    % If the files are ThunderSTORM reconstruction data
elseif strcmp(software,'thunder')
    for i = 1:N_files
        
        % Get filename and details
        FileNames_ch{i} = [Path, filesep, FileList_ch(i).name];
        LocFile = ReadLocFile_thunder([FileNames_ch{i}], 1);
        vars = LocFile;
        
        % Print some information to the command window
        disp(['Opening: ',(FileList_ch(i).name)]);
        disp(['Number of localizations: ', num2str(size(LocFile,1))]);
        
        % Filter out beads that are too big, and localizations that are too close together
        LocFile = QualityControl(LocFile, r_min, sigma_max,show);
        
        % Get coordinates, intensity and localizations IDs
        X{1,i}      = LocFile.x;
        Y{1,i}      = LocFile.y;
        counts{1,i} = LocFile.intensity;
        loc{1,i}    = (size(LocFile,1));
        precision{1,i} = LocFile.uncertainty;
    end
    
else
    error('The parameter ''software'' in batch_getTransform.m was set to ''%s'', which is not valid. Please set it to ''rapid'' or ''thunder'' in batch_getTransform.m!',software)
end

% Convert results to matrix format
X      = cell2mat(X);
Y      = cell2mat(Y);
counts = cell2mat(counts);
loc = cell2mat(loc);
precision = cell2mat(precision);
