
deletePathContents('/Users/unknown/code/MATLAB_compiled/1.65/package/');
deletePathContents('/Users/unknown/code/MATLAB_compiled/1.65/testing/');
deletePathContents('/Users/unknown/code/MATLAB_compiled/1.65/files_only/');
go2padaco


% run this before deploytool in order to make sure we have all subpaths
% accounted for.
mPathname = fileparts(mfilename('fullpath'));        
addpath(mPathname);
subPaths = {'widgets','figures','icons','utility','html','events'};
for s=1:numel(subPaths)
    addpath(fullfile(mPathname,subPaths{s}));
end


deploytool -package Padaco.prj
openDirectory('/Users/unknown/code/MATLAB_compiled/1.65/');