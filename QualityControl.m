%{
Double quality control of bead localizations (used before calculating
transform for registration).

This function takes in a table with 9 columns ('frame','x','y','sigma',
'intensity','offset','bkgstd','chi2','uncertainty') which was read in using
the function ReadLocFile_thunder.m and filters localizations based on size
(a maximum allowed sigma value sigma_max) and removes localizations that
are too close together (closer than some value r_min, e.g. 5 x pixelsize).

Author: Ezra Bruggeman, Laser Analytics Group
Last updated: 21 Aug 2018
%}

function [correctedLocFile distAll] = QualityControl(localizations, r_min, sigma_max)

%% Control 1: Filter out beads that are too big
localizations = localizations(localizations.sigma < sigma_max,:);

%% Control 2: Filter out localizations that are too close together

% Convert table to matrix
localizations = table2array(localizations);

% Get coordinates
coordinates = localizations(:,2:3);

% Plot localizations
figure;
scatter(coordinates(:,1), coordinates(:,2));
hold on;





% Calculate the distance between every set of points
% Stas 09.04.19

% check frame by frame
n=2; Coord_Frame = localizations(n,:); Current_Frame = localizations(1,2);
correctedLocFile=[];
while n<size(localizations,1)
   %check # of frames, if the same, keep add positions to Coord_Frame
   if localizations(n,2)==Current_Frame 
       Coord_Frame = [Coord_Frame; localizations(n,:)]; 
       n=n+1;
   else
       Current_Frame = localizations(n,2);
       
      %if next frame detected filter out within one frame
      distAll = pdist2(Coord_Frame,Coord_Frame);
      
      % Find the points that are closer together than r_min
      tooClose = distAll < r_min;
      num_TooClose = (sum(tooClose) - 1);

      % Get filtered matrix 
      correctedLocFileOneFrame = Coord_Frame;
      noNearNeighbour = num_TooClose ~= 0;
      correctedLocFileOneFrame(noNearNeighbour, :) = [];
      if isempty(correctedLocFileOneFrame)==0
      correctedLocFile = [correctedLocFile; correctedLocFileOneFrame];
      end
      Coord_Frame=[];
   end
      
end

% distAll = pdist2(coordinates,coordinates);
% 
% 
% 
% % Find the points that are closer together than r_min
% tooClose = distAll < r_min;
% num_TooClose = (sum(tooClose) - 1);
% 
% % Get filtered matrix 
% correctedLocFile = localizations;
% noNearNeighbour = num_TooClose ~= 0;
% correctedLocFile(noNearNeighbour, :) = [];


% Get matrix containing only rows that were filtered out (for visualization purposes)
deletedLocalizations = localizations;
NearNeighbour = num_TooClose == 0;
deletedLocalizations(NearNeighbour,:) = [];

% Convert back to table
correctedLocFile = array2table(correctedLocFile, 'VariableNames', {'frame','x','y','sigma','intensity','offset','bkgstd','uncertainty'});

% Plot
scatter(deletedLocalizations(:,2), deletedLocalizations(:,3), 'marker', '*');
legend({'all points', ['points with neighbours distance < ' num2str(r_min) ' nm']}, 'location', 'northoutside');
set(gca,'DataAspectRatio',[1 1 1]);
hold off;

end
