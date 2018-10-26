%> @brief msgbox wrapper when you have an icon you want to use as well.
%> @param msgStr [required]
%> @param titleStr ['']
%> @param iconFilename ['./icon_64.png']
%> @param makeModal [true]
%> @retval handle to the msgbox. 
%> @note h will be deleted if makeModal is set to true since the handle, h,
%> is passed to uiwait and not releaed  until the uiwait is stopped because
%> the msgbox has completed, been clicked on or closed, and deleted from
%> memory.
function h=pa_msgbox(msgStr,titleStr,iconFilename,makeModal)
    if(nargin<4)
        makeModal = true;
    end
    if(nargin<2 || isempty(titleStr))
        titleStr = '';
    end
    if(nargin<3 || ~exist(iconfFilename,'file'))
        iconFilename = 'icon_64.png';
    end

    
    if(exist(iconFilename,'file'))
        [iconData, iconCMap] = imread(iconFilename);        
    else
        iconData = [];
    end
    
    CreateStruct.WindowStyle='replace';
    CreateStruct.Interpreter='tex';
        
    if(~isempty(iconData))
        msgStr = strrep(msgStr,'_',' ');
        msgStr = strrep(msgStr,'B=','\beta = ');
        h=msgbox(sprintf('%s',msgStr),titleStr,'custom',iconData,iconCMap,CreateStruct);
    else
        h=msgbox(msgStr,titleStr,CreateStruct);
    end
    hText = findobj(h,'type','text');
    
    set(hText,'fontsize',12,'fontname','Arial');
    textExt = get(hText,'extent');
    hPos = get(h,'position');
    dW = sum(textExt([1,3]))-hPos(3);
    if(dW>0)
        hPos(3) = hPos(3)+dW+10;
        set(h,'position',hPos);
    end
%    msgStr2=textwrap(hText,{msgStr});
 %   set(h,'visible','on');
    
    if(makeModal)
        uiwait(h);
    end
end
