% New UseTransform function to use the transform obtained via fitgeotrans
% to align a warped widefield acquisition to a reference channel
% This script assumes the transform is in the same directory as the image
% data. 
% IN PROGRESS, NOT FINISHED YET! 
% Troubleshooting
% - Want to use a polynomial transform from a set of single molecule
% localisations of sub-diffractive beads in two different channels from the
% GetTransform.m script to register two widefield images (647 reference
% channel and 488 reference channel). Currently the transforms are used on
% single molecule localisation data sets, however if I want to apply this
% to widefield data it doesn't quite work the same. 
% - I suspect the error comes from using the transform which has been found
% from the SR reconstruction of the beads. 
% 23/04/2019

% Experimental data needs to be flipped before transformation. 

clear all
close all
clc

%% Parameters
% DefaultPath   = 'E:\Experiments\hiv escrt\2019_04_02_Pedro_Bo_HIVESCRT_exp6\slide1well3'; % directory with images

DefaultPath   = 'E:\Experiments\hiv escrt\2019_04_02_Pedro_Bo_HIVESCRT_exp6\BEADS\AvgInt'; % directory with beads for test
software      = 'thunder'; % 'rapid' or 'thunder' for rapidSTORM or ThunderSTORM reconstructions
area_token    = 'beads1'; % e.g. 'a' if files are called 'a1_488.tif', 'a2_488.tif', ...
RefCh_token   = 'camera2_647'; % reference channel (e.g. red: '_647')
tformCh_token = 'camera1_488'; % channel(s) to be transformed
show_plots    = 'off'; % show plots:'off' or 'on'

%% Get images and transformation files from directories
ref_channel     = dir([DefaultPath,filesep,'*','_647.tif']);
warped_channel  = dir([DefaultPath,filesep,'*','_488.tif']);

% FOR USER-FRIENDLINESS Get directory containing thunderSTORM localization files
% DefaultPath = uigetdir(DefaultPath, 'Choose directory containing the widefield images...');

% Create new output folder
output_dir_path = fullfile(DefaultPath,'Registered_data');
if exist(output_dir_path, 'dir')
    opts.Interpreter = 'tex';
    opts.Default = 'Yes';
    quest = '\fontsize{12}An output folder ''Registered\_data'' already exists. If you continue, data in this folder might be overwritten.';
    answer = questdlg(quest,'Message','Cancel','Yes',opts);
else
    mkdir(output_dir_path);
end
    
ref            = extractfield(ref_channel,'name');
warped         = extractfield(warped_channel,'name');

 % Load in the transform
FileName = dir([DefaultPath,filesep,'*',tformCh_token,'.mat']);
FileName = FileName.name;
load(fullfile(DefaultPath, FileName))

if isempty(ref)
    disp('No files matching user-specified area_token or channel_token found in directory.')
    return
end
% Get number of files in FileList
N_files = length(ref);

% Loop over all warped image files and transform them
for j=1:N_files

    % Load in the image data
    warped_im = imread(fullfile(DefaultPath,warped{j}));
    ref_im = imread(fullfile(DefaultPath,ref{j}));
    
    % Flip the warped image vertically to account for the extra reflection
    % in the beam path when using the second camera.
    warped_im_flip  = flipud(warped_im); 
    ref_im_flip     = flipud(ref_im);
    im_registered   = imwarp(warped_im_flip,tform);
    
    figure;imshowpair(ref_im_flip,warped_im_flip);
    figure;imshowpair(ref_im_flip,im_registered);

    
    im_reg = transformPointsInverse(tform,double(warped_im));
    figure
    imshowpair(ref_im,im_registered );


end
