%a wrapper for matlab's uigetdir - this one returns the directory pathname
%or empty if the user cancels or it does not exist.
%directoryname = uigetfulldir(initialDirectoryname,displayMessage)
function directoryname = uigetfulldir(initialDirectoryname,displayMessage)

    directoryname = uigetdir(initialDirectoryname,displayMessage);
    
    if(isnumeric(directoryname))
        directoryname = [];
    end
    if(~exist(directoryname,'dir'))
        directoryname = [];
    end
end
