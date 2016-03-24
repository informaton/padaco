function showPathContextmenuCallback(hObject,~)
    if(ishandle(hObject))
        figH = getFigureHandle(hObject);
        selectedHandle = get(figH,'currentObject');
        dirName = get(selectedHandle,'string');
    else
        dirName = [];
    end
    openDirectory(dirName);
end

function openDirectory(directory)
    if(isempty(directory) || ~exist(directory,'dir'))
        directory = pwd;
    end
    if(ispc)
        dos(sprintf('explorer.exe %s',directory));
    elseif(ismac)
        system(sprintf('open -R "%s"',directory));
    end
end