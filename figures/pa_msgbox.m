%> @brief msgbox wrapper when you have an icon you want to use as well.
%> @param msgStr
%> @param titleStr
%> @param iconFilename
%> @param makeModal
%> @retval handle to the msgbox. 
%> @note h will be deleted if makeModal is set to true since the handle, h,
%> is passed to uiwait and not releaed  until the uiwait is stopped because
%> the msgbox has completed, been clicked on or closed, and deleted from
%> memory.
function h=pa_msgbox(msgStr,titleStr,iconFilename,makeModal)
    if(nargin<4)
        makeModal = false;
    end
    
    if(nargin>2 && exist(iconFilename,'file'))
        [iconData, iconCMap] = imread(iconFilename);        
    else
        iconData = [];
    end
    
    if(~isempty(iconData))
        CreateStruct.WindowStyle='replace';
        CreateStruct.Interpreter='tex';
        msgStr = strrep(msgStr,'_',' ');
        msgStr = strrep(msgStr,'B=','\beta = ');
        h=msgbox(sprintf('%s',msgStr),titleStr,'custom',iconData,iconCMap,CreateStruct);
    else
        h=msgbox(msgStr,titleStr);
    end
    
    if(makeModal)
        uiwait(h);
    end
end
