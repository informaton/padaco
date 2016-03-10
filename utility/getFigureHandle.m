function figureHandle = getFigureHandle(guiHandle)
    if(ishandle(guiHandle))
        while ~isempty(guiHandle) && ~strcmpi('figure', get(guiHandle,'type'))
            guiHandle = get(guiHandle,'parent');
        end
        figureHandle = guiHandle;
    else
        figureHandle = [];
    end
end