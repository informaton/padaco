
buildNum = '1.75';

try
    deletePathContents(sprintf('/Users/unknown/code/MATLAB_compiled/%s/package/',buildNum));
    deletePathContents(sprintf('/Users/unknown/code/MATLAB_compiled/%s/testing/',buildNum));
    deletePathContents(sprintf('/Users/unknown/code/MATLAB_compiled/%s/files_only/',buildNum));
catch me
   showME(me); 
end

go2padaco


% run this before deploytool in order to make sure we have all subpaths
% accounted for.
mPathname = pathsetup();       




version.num = buildNum;
save(fullfile(mPathname,'resources','version.chk'),'-struct','version');

deploytool -build Padaco.prj
% projectName = ['Padaco_',buildNum,'.prj'];
% deploytool('-build',projectName);
openDirectory(sprintf('/Users/unknown/code/MATLAB_compiled/%s/',buildNum));


% Once deploytool finishes then we should move on to
srcIconSet = 'resources/icons/logo/icon.icns';
destIconSet = sprintf('/Users/unknown/code/MATLAB_compiled/%s/package/PadacoInstaller_web.app/Contents/Resources/installer.icns',buildNum);
InstallerName = sprintf('/Users/unknown/code/MATLAB_compiled/%s/package/PadacoInstaller_web.app',buildNum);
[SUCCESS,MESSAGE,MESSAGEID] = copyfile(srcIconSet, destIconSet);

% update the cache so it uses the new installer icon set
[status, result] = system(['touch ',InstallerName]);  % status == 0 on success.


