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
(better sampling of FoV),
and write away a summary pdf with relevant plots.

Last updated: 21/08/2018

Depends on functions:
  loc_info.m
  AssociateCoordinates.m
%}
    
clear all
close all
clc

%% Parameters
DefaultPath    = '/Users/pedrovallejo/OneDrive - University Of Cambridge/lag/microscopy work/color registration/test data 20190309/beads/bead_reconstructions/';

software       = 'thunder'; % 'rapid' or 'thunder' for rapidSTORM or ThunderSTORM reconstructions
Trafo_type     = 'polynomial'; % transform type ('polynomial' or 'lwm')
area_token     = 'beads'; % e.g. 'a' if files are called 'a1_488.tif', 'a2_488.tif', ...
RefCh_token    = '_647'; % reference channel (e.g. red: '_647')
tformCh_token  = {'_488','_561'}; % channel(s) to be transformed (e.g. {'_488','_561'})

pix            = 10; % 10 nm per pix
R_search       = 200; % search radius used to associate localizations (in nm)
polyn_order    = 2;   % order of the polynomial transform (if Trafo_type = 'polynomial', 2 is recommended)
control_points = 25;  % nr of points used to calculate lwm transform (at least 6, recommend 25-30)

sigma_max      = 200; % max acceptable sigma (in nm)
camera_pixel   = 117; % nm 
r_min          = 5*camera_pixel; % minimum distance that beads need to be seperated (in nm)
FOV            = 256; % size of the camera field of view (e.g. 128x128, 256x256) 
show_plots     = 'on'; % show plots:'off' or 'on'

%%

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
    tempcell = cell(1,10);
    for j = 1:length(FileList)
        tempcell{1,j} = FileList(j).name;
    end
    
    %     if N_files > 1
    %         % Create a file that will contain the parameters for the different transforms
    %         new_filename = strcat('beads_transform_Ref',RefCh_token,'_to',channel_token,'_summary','.csv');
    %         fid = fopen(fullfile(output_dir_path,new_filename),'wt');
    %         if strcmp(Trafo_type,'polynomial')
    %             fprintf(fid,'Beads,Degree,A1,A2,A3,A4,A5,A6,B1,B2,B3,B4,B5,B6,Dimensionality\n');
    %         else
    %             fprintf(fid,'Beads,T11,T12,T13,T21,T22,T23,T31,T32,T33,Dimensionality\n');
    %         end
    %     end
    
    % Initialize arrays that will contain the associated coordinates of all
    % the beads
    X_concatenated = [];
    Y_concatenated = [];
    Xd_concatenated = [];
    Yd_concatenated = [];
 
    %% Load files and associate coordinates
    for j=1:N_files
        
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
        [x_ref,y_ref,counts_ref,vars_ref,precision_ref]           = loc_info(PathName, pix, area_token_i, RefCh_token,   software, sigma_max, r_min);
        [x_tform,y_tform,counts_tform,vars_tform,precision_tform] = loc_info(PathName, pix, area_token_i, channel_token, software, sigma_max, r_min);
        
        % Associate coordinates
        [x_ref, y_ref, x_tform, y_tform,N_local] = AssociateCoordinates(x_ref, y_ref, x_tform, y_tform, R_search);
        disp(['Number of localizations associated: ',num2str(size(x_ref,1))]);
        disp(' ');
        
        % remove from the precision of localisations column in the
        % reference channel 
        precision_ref(N_local ~= 1) = [];
        %precision_tform(N_local ~= 1) = [];
        
        X_concatenated  = cat(1, X_concatenated,  x_ref);
        Y_concatenated  = cat(1, Y_concatenated,  y_ref);
        Xd_concatenated = cat(1, Xd_concatenated, x_tform);
        Yd_concatenated = cat(1, Yd_concatenated, y_tform);
    end
    
    %% Get transform
    
    % Print some information to command window
    disp(' ');
    disp('Results:');
    disp(['Trafo type: ',Trafo_type]);
    
    X = X_concatenated;
    Y = Y_concatenated;
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
    
    %     % Write away the transform parameters to a csv file
    %     if N_files > 1
    %         if strcmp(Trafo_type,'polynomial')
    %             fprintf(fid,'%s,%d,%.15f,%.15f,%.15f,%.15f,%.15f,%.15f,%.15f,%.15f,%.15f,%.15f,%.15f,%.15f,%d\n', ...
    %                 area_token_i,tform.Degree,tform.A,tform.B,tform.Dimensionality);
    %         elseif strcmp(Trafo_type,'affine')
    %             fprintf(fid,'%s,%.15f,%.15f,%.15f,%.15f,%.15f,%.15f,%.15f,%.15f,%.15f,%d\n', ...
    %                 area_token_i,tform.T(1,:),tform.T(2,:),tform.T(3,:),tform.Dimensionality);
    %         end
    %     end
    
    % Apply the obtained transformation (used for plotting and calculating TRE)
    [U,V] = transformPointsInverse(tform,X_d,Y_d);
    
    %% Plot results and calculate registration error (TRE)
    if strcmp(show_plots,'on')
        % Display overlay of both channels before and after registration as a
        % scatter plot
        formattedTitle = sprintf('Scatter plot pre- and post-registration %s',strcat(area_token_i,channel_token));
        figure('Color','white','name',formattedTitle,'Units','normalized', ...
            'Outerposition',[0.1 0.1 0.8 0.6],'visible',show_plots);
        
        subplot(1,2,1)
        plot(X,Y,'+')
        hold on
        plot(X_d,Y_d,'r+')
        axis equal
        title 'Pre-registration'
        legend(strcat('Reference: ',RefCh_token(2:end)),strcat('Transformed: ',channel_token(2:end)));
        xlabel('nm');
        ylabel('nm');
        
        subplot(1,2,2)
        plot(X,Y,'+')
        hold on
        plot(U,V,'r+')
        axis equal
        title 'Post-registration'
        legend(strcat('Reference: ',RefCh_token(2:end)),strcat('Transformed: ',channel_token(2:end)));
        xlabel('nm');
        ylabel('nm');
    end
    
    % Evaluate the TRE before and after registration (it should be smaller
    % after registration) and plot a histogram of post-registration offset
    PreRegOffset = sqrt((X-X_d).^2 + (Y-Y_d).^2);
    TRE_pre = mean(PreRegOffset);
    disp(['Pre-reg TRE = ',num2str(TRE_pre,'%6.1f'),' nm']);
    
    PostRegOffset = sqrt((X-U).^2 + (Y-V).^2);
    TRE = mean(PostRegOffset);
    disp(['Post-reg TRE = ',num2str(TRE,'%6.1f'),' nm']);
    
    if strcmp(show_plots,'on')
        formattedTitle = sprintf('Histogram of Post-registration offset for %s',strcat(area_token_i,channel_token));
        figure('Color','white','name',formattedTitle, 'visible',show_plots);
        %hist(PostRegOffset,0:2:50)
        %xlim([0 50])
        histogram(PostRegOffset,'BinWidth',3,'FaceAlpha',0.8,'FaceColor',[0.4 0.6 0.7])
        xlabel 'R_{offset} (nm)'
        
        formattedTitle = sprintf('Histogram of localisation error for beads in %s',strcat(area_token_i,channel_token));
        figure('Color','white','name',formattedTitle, 'visible',show_plots);
        %hist(PostRegOffset,0:2:50)
        %xlim([0 50])
        histogram(precision_ref,'BinWidth',0.5,'FaceAlpha',0.5,'FaceColor','r');
        hold on
        histogram(precision_tform,'BinWidth',0.5,'FaceAlpha',0.5,'FaceColor','g');
        xlabel('Localisation error (nm)')
        ylabel('Counts')
        legend('reference channel','2nd channel');
    end
    
    % Show the transformation on a meshgrid and as a vectorfield
    n_points = 20;
    Field_size = FOV*camera_pixel; % in nm
    %Field_size = 40000; % nm
    xgv = linspace(0,Field_size,n_points);
    xgv(1) = [];
    xgv(end) = [];
    [X,Y] = meshgrid(xgv,xgv);
    X = reshape(X,[size(X,1)*size(X,2),1]);
    Y = reshape(Y,[size(Y,1)*size(Y,2),1]);
    
    [X_dinv,Y_dinv] = transformPointsInverse(tform,X,Y);
    
    if strcmp(show_plots,'on')
        formattedTitle = sprintf('Displaying transform %s',strcat(area_token_i,channel_token));
        figure('Color','white','name',formattedTitle,'Units','normalized', ...
            'Outerposition',[0.1 0.1 0.8 0.6],'visible',show_plots);
        
        subplot(1,2,1)
        plot(X,Y,'+')
        hold on
        plot(X_dinv,Y_dinv,'r+')
        axis equal
        title 'Grid'
        xlabel('nm');
        ylabel('nm');
        
        subplot(1,2,2);
        quiver(X,Y,X -X_dinv, Y-Y_dinv,0) % vector field without normalization
        axis equal
        title 'Vector field without autoscaling'
        xlabel('nm');
        ylabel('nm');
       
    end
    
    formattedTitle = sprintf('Vector field for transform to correct for optical offset in %s%s',strcat(area_token_i,channel_token));
    fig = figure('Color','white','name',formattedTitle,'Units','normalized','visible',show_plots);
    quiver(X,Y,X -X_dinv, Y-Y_dinv)
    axis equal
    title 'Vector field autoscaled to 1'
    print(fig,fullfile(output_dir_path,strcat(area_token_i,channel_token,'_gradient_plot.png')),'-dpng','-r300');
    
    formattedTitle = sprintf('Vector field for raw optical offset in %s%s',strcat(area_token_i,channel_token));
    fig = figure('Color','white','name',formattedTitle,'Units','normalized','visible',show_plots);
    quiver(X_concatenated,Y_concatenated,  -X_concatenated +Xd_concatenated ,-Y_concatenated + Yd_concatenated);
    axis equal
    title 'Raw optical offset'
    
    % work in progress for this
    formattedTitle = sprintf('Scatter plot for the optical offset %s%s',strcat(area_token_i,channel_token));
    fig = figure('Color','white','name',formattedTitle,'Units','normalized','visible',show_plots);
    scatter(X_concatenated -Xd_concatenated,Y_concatenated - Yd_concatenated,'.','r'); %x_ref-transformed, y_ref - transformed
    
    scatter
    xlim([-150 150]);
    ylim([-150 150]);
    xlabel('registration offset x (nm)');
    ylabel('registration offset y (nm)');
    title 'Raw optical offset'
    %residual_off = sqrt(precision_ref.^2 + precision_tform.^2 + TRE);
    
    %% Save transform
    trafo_filename = strcat('Trafo_tform_',area_token_i,channel_token,'.mat');
    save([output_dir_path,filesep,trafo_filename],'tform');
    disp(['Transformation saved as: ',output_dir_path,filesep,trafo_filename]);
end
if N_files > 1
    fclose all;
end