% This function reads a localisation outputfile from thunderSTORM in as a table.

% Author: Pedro Vallejo Ramirez
% Laser Analytics Group
% Updated: 02/08/2018

function variables = ReadLocFile_thunder(filename, startRow, endRow)

% Set parameters startRow and endRow if not specified
delimiter = ',';
if nargin<=2
    startRow = 2;
    endRow = inf;
end

% Read data columns
fileID = fopen(filename,'r');
formatSpec = '%f%f%f%f%f%f%f%f%[^\n\r]';
dataArray = textscan(fileID, formatSpec, endRow(1)-startRow(1)+1, 'Delimiter', delimiter, 'EmptyValue', NaN, 'HeaderLines', startRow(1)-1, 'ReturnOnError', false, 'EndOfLine', '\r\n');
for block=2:length(startRow)
    frewind(fileID);
    dataArrayBlock = textscan(fileID, formatSpec, endRow(block)-startRow(block)+1, 'Delimiter', delimiter, 'EmptyValue', NaN, 'HeaderLines', startRow(block)-1, 'ReturnOnError', false, 'EndOfLine', '\r\n');
    for col=1:length(dataArray)
        dataArray{col} = [dataArray{col};dataArrayBlock{col}];
    end
end
fclose(fileID);

% Create output variables
variables = table(dataArray{1:end-1}, 'VariableNames', {'frame','x','y','sigma','intensity','offset','bkgstd','uncertainty'});
