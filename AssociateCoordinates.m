% This function takes the coordinates of two sets of localizations and
% returns an ordered list of coordinates which have a partner in the other
% list that is closer than a radius = R_search.

% Author: Pedro Vallejo Ramirez
% Laser Analytics Group
% Updated: 02/08/2018


function [X1,Y1,X2_min,Y2_min, N_local] = AssociateCoordinates(X1,Y1,X2,Y2,R_search)

% Get the number of localizations in each channel
N_loc1 = size(X1,1);
N_loc2 = size(X2,1);

% Initialize vectors
N_local = zeros(N_loc1,1);
R_min   = zeros(N_loc1,1);
X2_min  = zeros(N_loc1,1);
Y2_min  = zeros(N_loc1,1);

% Loop over all localizations (x1,y1)
for i = 1:N_loc1

    % Calculate distance between every combination of (x1,y1) and (x2,y2)
    R = zeros(N_loc2,1);
    for j = 1:N_loc2
        R(j) = sqrt((X1(i)-X2(j))^2 + (Y1(i)-Y2(j))^2);
    end
    
    % Count number of localizations in (X2,Y2) with r < R_search to the i-th localization in (X1,Y1)
    N_local(i) = sum(R < R_search);
    
    % Get distance between the i-th localization in (X1,Y1) to the closest localization in (X2,Y2)
    R_min(i) = min(R);
    
    % Get the coordinates of the nearest localization in (X2,Y2)
    X2_min(i) = X2(R == min(R));
    Y2_min(i) = Y2(R == min(R));
end

% Filter out all localizations (x1,y1) that were not matched with another
% localization (x2,y2)
X1(N_local ~= 1) = [];
Y1(N_local ~= 1) = [];
X2_min(N_local ~= 1) = [];
Y2_min(N_local ~= 1) = [];

% % Display
% figure('Color','white','name','Histogram of R_min','Units','normalized','OuterPosition',[0.2 0.2 0.6 0.5]);
% 
% subplot(1,2,1)
% plot(X1,Y1,'+')
% hold on
% plot(X2_min,Y2_min,'r+')
% axis equal
% legend('Red channel','Green channel');
% 
% subplot(1,2,2)
% hist(R_min,0:10:500)
% xlim([0 500])
% xlabel 'R_{offset} (nm)'
% title 'Histogram of chromatic offset'
end