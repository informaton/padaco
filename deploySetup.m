% run this before deploytool in order to make sure we have all subpaths
% accounted for.
mPathname = fileparts(mfilename('fullpath'));        
addpath(mPathname);
subPaths = {'widgets','figures','icons','utility','html','events'};
for s=1:numel(subPaths)
    addpath(fullfile(mPathname,subPaths{s}));
end

applicationCompiler
