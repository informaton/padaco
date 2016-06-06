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