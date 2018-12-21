% [pathnames, fullpathnames]  = getPathnames(srcPathname)
% 
% directory wrapper to get names of any subdirectories contained in pathname (i.e. a directory)
% [pathnames]   Cell of children directories sans srcPathname prefix.
% [fullpathnames Cell of srcPathname's children directories with
% srcPathname included.
%
% [pathnames, fullpathnames]  = getPathnames(srcPathname, ext)
% Returns subpaths of srcPathname which have one or more files with the
% extension ext.  
%
% See also getFilenamesi
% 
% Written by Hyatt Moore, IV (< June, 2013)
% @modified 12/14/2018 @hyatt Added extension check
function [pathnames, fullpathnames] = getPathnames(srcPathname, ext)

    dirPull = dir(fullfile(srcPathname));
    directory_flag = cells2mat(dirPull.isdir);
    names = cells2cell(dirPull.name);
    pathnames = names(directory_flag);
    unused_dir = strncmp(pathnames,'.',1)|strncmp(pathnames,'..',2);
    if(~isempty(unused_dir))
        pathnames(unused_dir) = [];
    end
    

    fullpathnames = cell(size(pathnames));
    for f=1:numel(fullpathnames)
        fullpathnames{f} = fullfile(srcPathname, pathnames{f});
    end

    
    if(nargin>1 && ~isempty(ext))
        pathHasExt = cellfun(@(x)~isempty(getFilenamesi(x,ext)),fullpathnames);
        fullpathnames = fullpathnames(pathHasExt);
        pathnames = pathnames(pathHasExt);        
    end
end 

