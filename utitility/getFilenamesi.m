function [filenames,fullfilenames] = getFilenamesi(pathname,ext)
% function [filenames,fullfilenames] = getFilenamesi(pathname,ext)
%  Case insensitive version of getFilenames.  This was created because some
%  OS are case sensitive so that dir('*.txt') would not catch the file
%  help.TXT.  
%  pathname is a string of the folder to search
%  [filenames] = getFilenames(pwd,'m');
%      filenames contains the filenames with 'm' extension in the current
%      directory
%> @note Leading '.' in ext will be removed.
%> @note For example if ext = '.m', the method will correct it to 'm' for
%> you.  Thus, the following commands are equivalent:
%> - [filenames] = getFilenames(pwd,'m');
%> - [filenames] = getFilenames(pwd,'.m');

% copyright Hyatt Moore IV

if(nargin<2)
    ext = '';
end
dirPull = dir(pathname);
directory_flag = cells2mat(dirPull.isdir);
names = cells2cell(dirPull.name);
filenames = names(~directory_flag);

if(~isempty(ext) && ext(1)=='.')
    ext(1)=[];
end

% Mac OS does some extra things to keep track of files in each directory which interfere here.  
if(ismac)
    fileMatchesCell = regexpi(filenames,strcat('^[^\._].*',ext,'$'));
else
    fileMatchesCell = regexpi(filenames,strcat('.*',ext,'$'));    
end
fileMatchesVec = false(size(fileMatchesCell));

%I really don't like MATLAB's regexp cell output format... ah well
for f=1:numel(fileMatchesCell)
    fileMatchesVec(f) = ~isempty(fileMatchesCell{f});
end

filenames(~fileMatchesVec) = [];
if(nargout>1)
    fullfilenames = cell(size(filenames));
    for k=1:numel(filenames)
        fullfilenames{k} = fullfile(pathname,filenames{k});
    end
end
end

