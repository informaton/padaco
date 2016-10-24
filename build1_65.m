
buildNum = '1.65';

deletePathContents(sprintf('/Users/unknown/code/MATLAB_compiled/%s/package/',buildNum));
deletePathContents(sprintf('/Users/unknown/code/MATLAB_compiled/%s/testing/',buildNum));
deletePathContents(sprintf('/Users/unknown/code/MATLAB_compiled/%s/files_only/',buildNum));
go2padaco


% run this before deploytool in order to make sure we have all subpaths
% accounted for.
mPathname = pathsetup();       




version.num = buildNum;
save(fullfile(mPathname,'resources','version.chk'),'-struct','version');

deploytool -build Padaco.prj
openDirectory(sprintf('/Users/unknown/code/MATLAB_compiled/%s/',buildNum));