%{
This script uses the localisation files from a series of bead images to
calculate a transform that can be used to register multi-colour images.
It was adapted from the original code from Dr. Romain F. Laine to register
two-colour images.

In order for the code to work, you have to follow a specific naming
convention. For example, for 3-col registration, the names of the
localization files in the directory you specify should be:
    a1_488.csv
    a1_561.csv
    a1_647.csv
where 'a1' is called the area_token and '_488','_561','_647' the channel_
tokens. The area_token can be anything, but you have to specify it in the
parameters below. The channel tokens also have to be specified in a cell
(it can be one channel, or a list if you want to do 3-colour registration,
or more).
One channel is chosen to be the reference channel, so in the example above,
if 647 is the reference channel, you would get 2 transforms as output:
    Trafo_tform_488.mat
    Trafo_tform_561.mat
NEW IN V3.3: If you acquired many bead images, all the images that are in
the chosen directory will be used to calculate one transform, instead of
calculating a transform for all the individual bead images from which you
could select only one to perform the registration.

A polynomial or local weighted mean transform can be calculated using the
MATLAB function fitgeotrans.

Author: Pedro Vallejo Ramirez, Laser Analytics Group
Modified by Ezra Bruggeman to allow multi-colour registration, use of
multiple bead images to calculate the transform
(better sampling of FoV),and write away a summary pdf with relavent plots.

Last updated: 23/04/2019
-Output now includes a .csv file with the reference, warped, and
unwarped coordinates for plotting in R or other software. 
-The search radius was increased from 200 to 600 to also find beads which
have a large offset between them, such as data from a dual-colour 2-camera
imaging experiment. 
Depends on functions:
  loc_info.m
  AssociateCoordinates.m
%}

clear all
close all
clc

%% Parameters

% File import parameters
DefaultPath    = 'E:\Experiments\hiv escrt\2019_04_02_Pedro_Bo_HIVESCRT_exp6\BEADS\bead_reconstructions';
software       = 'thunder';         % 'rapid' or 'thunder' for rapidSTORM or ThunderSTORM reconstructions
area_token     = 'beads1';          % e.g. 'a' if files are called 'a1_488.tif', 'a2_488.tif', ...
RefCh_token    = '_camera2_647';    % reference channel (e.g. red: '_647')
tformCh_token  = {'_camera1_488'};  % channel(s) to be transformed (e.g. {'_488','_561'})
flip_camera2   = 1;                 % need a vertical flip for the second camera to match the FOV of the first camera

% Settings for the transform
R_search       = 600; % search radius used to associate localizations (in nm)
Trafo_type     = 'polynomial'; % transform type ('polynomial' or 'lwm')
polyn_order    = 2; % order of the polynomial transform (if Trafo_type = 'polynomial', 2 is recommended)
control_points = 25; % nr of points used to calculate lwm transform (at least 6, recommend 25-30)

% Pixel sizes
pix            = 11.7;% 11.7 nm per pixel in the SR reconstructions
camera_pixel   = 117; % camera pixel size in nm 

% Filters for Quality control
sigma_max      = 200; % max acceptable sigma (in nm)
r_min          = 5*camera_pixel; % minimum distance that beads need to be separated (in nm)
FOV            = 256; % size of the camera field of view (e.g. 128x128, 256x256) 

% Flags to plot intermediate results
showQualityControl      = 1;
show_plots              = 1;

% Get directory of bead files
PathName = uigetdir(DefaultPath, 'Choose directory containing the localization files...');

% Create new output folder
output_dir_path = fullfile(PathName,sprintf('Output_registration_%s',Trafo_type));
if exist(output_dir_path, 'dir')
    opts.Interpreter = 'tex';
    opts.Default = 'Continue';
    quest = '\fontsize{12}An output folder ''Output\_registration'' already exists. If you continue, data in this folder might be overwritten.';
    answer = questdlg(quest,'Message','Cancel','Continue',opts);
else
    mkdir(output_dir_path);
end

% Check whether output is from rapidSTORM or ThunderSTORM
if strcmp(software,'rapid')
    type = '.txt';
else
    type = '.csv';
end

%% Loop over all channels
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
    tempcell = cell(1,10);
    for j = 1:length(FileList)
        tempcell{1,j} = FileList(j).name;
    end
    
    % Initialize arrays that will contain the associated coordinates of all
    % the beads
    
    X_concatenated  = [];
    Y_concatenated  = [];
    Xd_concatenated = [];
    Yd_concatenated = [];
    
    %% Loop over all the bead localisation files, extract coordinates which
    % have a closely associated coordinate in the second channel. 
    
    for j=1:N_files
        % Load files and associate coordinates
        
        % Get current area_token
        if N_files==1
            area_token_i = area_token;
        else
            area_token_i = strcat(area_token,num2str(j));
        end
        
        % Get path to files
        FileName_Ref   = fullfile(PathName,strcat(area_token_i,RefCh_token,type));
        FileName_tform = fullfile(PathName,strcat(area_token_i,channel_token,type));
        
        % Get X and Y coordinates of red an green channel (RC and GC)
        [x_ref,y_ref,counts_ref,vars_ref,precision_ref]             = loc_info(PathName, pix, area_token_i, RefCh_token, software, sigma_max, r_min, showQualityControl);
        [x_tform,y_tform,counts_tform,vars_tform,precision_tform]   = loc_info(PathName, pix, area_token_i, channel_token, software, sigma_max, r_min, showQualityControl);
        
        % In case of two-colour imaging using two cameras, flip the output
        % of the warped channel
        
        % Associate coordinates
        % initiate cells to contain coordinates
        X   =[]; 
        Y   =[]; 
        X_d =[]; 
        Y_d =[];
       
        % Feed in all localisations and obtain the ones that are
        % associated. 
        [x_ref, y_ref, x_tform, y_tform,N_local] = AssociateCoordinates(x_ref, y_ref, x_tform, y_tform, R_search);
        disp(['Number of localizations associated: ',num2str(size(x_ref,1))]);
        disp(' ');
        
        precision_ref(N_local ~= 1) = [];
        %precision_tform(N_local ~= 1) = [];
       
        X   = cat(1,X,x_ref); % reference points in x
        Y   = cat(1,Y,y_ref); % reference points in y
        X_d = cat(1,X_d,x_tform); % transformed points
        Y_d = cat(1,Y_d,y_tform); % transformed points
        
        X_concatenated  = cat(1, X_concatenated,  X); % all reference points in X
        Y_concatenated  = cat(1, Y_concatenated,  Y); % all reference points in Y
        Xd_concatenated = cat(1, Xd_concatenated, X_d); % all transformed points in X
        Yd_concatenated = cat(1, Yd_concatenated, Y_d); % all transformed points in Y
    end
    
    %% Get transform and apply it to the warped channel
    
    % Print some information to command window
    disp(' ');
    disp('Results:');
    disp(['Trafo type: ',Trafo_type]);
    
    % Re-assign reference points and points-to-be-transformed to X,Y,X_d, and Y_d
    X   = X_concatenated;
    Y   = Y_concatenated;
    X_d = Xd_concatenated;
    Y_d = Yd_concatenated;
    
    % Get transformation matrix using fitgeotrans
    if strcmp(Trafo_type,'polynomial') % polynomial transform
        tform = fitgeotrans([X Y],[X_d Y_d],Trafo_type,polyn_order);
    elseif strcmp(Trafo_type,'lwm')    % local weighted mean transform
        tform = fitgeotrans([X Y],[X_d Y_d],Trafo_type,control_points);
    else                               % affine or piecewise linear transform
        tform = fitgeotrans([X Y],[X_d Y_d],Trafo_type);
    end
     
    % Apply the obtained transformation to the warped channel (used for plotting and calculating TRE)
    [U,V] = transformPointsInverse(tform,X_d,Y_d);
    results = zeros(size(X,1),6); % start an array to store reference, warped, and unwarped coordinates.
    
    %% Plot intermediate results and calculate registration error (TRE)
    if show_plots
        
        % Display overlay of both channels before and after registration as a
        % scatter plot
        formattedTitle = sprintf('Scatter plot pre- and post-registration %s',strcat(area_token,channel_token));
        figure('Color','white','name',formattedTitle,'Units','normalized', ...
            'Outerposition',[0.1 0.1 0.8 0.6],'visible',show_plots);
        
        subplot(1,2,1)
        plot(X,Y,'+')
        hold on
        plot(X_d,Y_d,'r+')
        axis equal
        xlim([0 camera_pixel*FOV])
        ylim([0 camera_pixel*FOV])
        title 'Pre-registration'
        legend(strcat('Reference: ',RefCh_token(2:end)),strcat('Transformed: ',channel_token(2:end)));
        xlabel('nm');
        ylabel('nm');
        
        subplot(1,2,2)
        plot(X,Y,'+')
        hold on
        plot(U,V,'r+')
        axis equal
        xlim([0 camera_pixel*FOV])
        ylim([0 camera_pixel*FOV])
        title 'Post-registration'
        legend(strcat('Reference: ',RefCh_token(2:end)),strcat('Transformed: ',channel_token(2:end)));
        xlabel('nm');
        ylabel('nm');
    end
    
    %% Evaluate the TRE before and after registration (it should be smaller
    % after registration) and plot a histogram of post-registration offset
    
    PreRegOffset = sqrt((X-X_d).^2 + (Y-Y_d).^2);
    TRE_pre = mean(PreRegOffset);
    disp(['Pre-reg TRE = ',num2str(TRE_pre,'%6.1f'),' nm']);
    
    PostRegOffset = sqrt((X-U).^2 + (Y-V).^2);
    TRE = mean(PostRegOffset);
    disp(['Post-reg TRE = ',num2str(TRE,'%6.1f'),' nm']);
    
    if show_plots
        formattedTitle = sprintf('Histogram of Post-registration offset %s',strcat(area_token,channel_token));
        figure('Color','white','name',formattedTitle, 'visible',show_plots);
        %hist(PostRegOffset,0:2:50)
        %xlim([0 50])
        hist(PostRegOffset)
        ylabel('Frequency of candidates');
        xlabel('R_{offset} (nm)');
        
        formattedTitle = sprintf('Histogram of localisation error for beads in %s',strcat(area_token,channel_token));
        figure('Color','white','name',formattedTitle, 'visible',show_plots);
        %hist(PostRegOffset,0:2:50)
        %xlim([0 50])
        histogram(precision_ref,10,'FaceAlpha',0.5,'FaceColor','r','BinWidth',0.3);
        hold on
        histogram(precision_tform,10,'FaceAlpha',0.5,'FaceColor','g','BinWidth',0.3);
        xlim([0 6]);
        ylabel('Frequency of candidates');
        xlabel('Localisation error (nm)');
        legend('reference channel','2nd channel');
    end
    
    %% Show the transformation on a meshgrid and as a vectorfield just for demonstration
    
    % Create equally spaced meshgrid using estimated FOV
    
    n_points    = 20;
    Field_size  = FOV*camera_pixel; % in nm
    xgv         = linspace(0,Field_size,n_points);
    xgv(1)      = [];
    xgv(end)    = [];
    
    [X_mesh,Y_mesh]       = meshgrid(xgv,xgv);
    X_mesh                = reshape(X_mesh,[size(X_mesh,1)*size(X_mesh,2),1]);
    Y_mesh                = reshape(Y_mesh,[size(Y_mesh,1)*size(Y_mesh,2),1]);
    
    % Apply the inverse transformation of the polynomial found before to
    % the equally spaced meshgrid coordinate
    [X_dinv,Y_dinv] = transformPointsInverse(tform,X_mesh,Y_mesh);
    
    if show_plots
        
        formattedTitle = sprintf('Displaying transform %s',strcat(area_token_i,channel_token));
        figure('Color','white','name',formattedTitle,'Units','normalized', ...
            'Outerposition',[0.1 0.1 0.8 0.6],'visible',show_plots);
        subplot(1,2,1)
        plot(X_mesh,Y_mesh,'+')
        hold on
        plot(X_dinv,Y_dinv,'r+')
        axis equal
        title 'Grid'
        xlabel('nm');
        ylabel('nm');
        
        subplot(1,2,2);
        quiver(X_mesh,Y_mesh,X_mesh -X_dinv, Y_mesh-Y_dinv,0) % vector field without normalization
        axis equal
        title 'Vector field without autoscaling'
        xlabel('nm');
        ylabel('nm');
       
    end
    
    
    if show_plots
        
        formattedTitle = sprintf('Vector field for transform to correct for optical offset in %s%s',strcat(area_token_i,channel_token));
        fig = figure('Color','white','name',formattedTitle,'Units','normalized','visible',show_plots);
        quiver(X_mesh,Y_mesh,X_mesh -X_dinv, Y_mesh-Y_dinv)
        axis equal
        title 'Vector field autoscaled to 1'
        print(fig,fullfile(output_dir_path,strcat(area_token_i,channel_token,'_gradient_plot.png')),'-dpng','-r300');

        formattedTitle = sprintf('Vector field for raw optical offset in %s%s',strcat(area_token_i,channel_token));
        fig = figure('Color','white','name',formattedTitle,'Units','normalized','visible',show_plots);
        quiver(X,Y,-X +X_d ,-Y + Y_d);
        axis equal
        title 'Raw optical offset'

        % work in progress still!
        formattedTitle = sprintf('Scatter plot for the optical offset %s%s',strcat(area_token_i,channel_token));
        fig = figure('Color','white','name',formattedTitle,'Units','normalized','visible',show_plots);
        scatter(X_concatenated -U,Y_concatenated - V,'.','r');
        hold on
        xlim([-20 20]);
        ylim([-20 20]);
        xlabel('registration offset x (nm)');
        ylabel('registration offset y (nm)');
        title 'Residual optical offset'
        viscircles([0 0],10,'Color','blue'); % 10 nm circle around the residual fit. 
        hold off
        %residual_off = sqrt(precision_ref.^2 + precision_tform.^2 + TRE);
    end
    
    % Save meshgrid, and transformed meshgrid to plot in R
    results_meshgrid = cat(2,X_mesh,Y_mesh,X_dinv,Y_dinv);
    results_meshgrid_table = array2table(results_meshgrid,'VariableNames',{'X','Y','Xdinv','Ydinv'});
    writetable(results_meshgrid_table,[output_dir_path filesep strcat(area_token_i, channel_token) 'results_meshgrid.csv']);
    
    %% Save transform
    trafo_filename = strcat('Trafo_tform_',area_token_i,channel_token,'.mat');
    save([output_dir_path,filesep,trafo_filename],'tform');
    disp(['Transformation saved as: ',output_dir_path,filesep,trafo_filename]);
    
    % Output original reference, warped, and unwarped coordinates of 
    % reference and 2nd channel
    results = cat(2,X,Y,X_d,Y_d,U,V);
    results_tab = array2table(results,'VariableNames',{'X','Y','Xd','Yd','U','V'});
    writetable(results_tab,[output_dir_path filesep strcat(area_token_i, channel_token) 'results.csv']);
    
    
end
if N_files > 1
     fclose all;
end