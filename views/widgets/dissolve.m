%> @brief "Dissolves" a graphic handle by changing it's foreground color to
%its background color, or its background color to that of its parent
%background color.  The method used is dependent on the handle's type.
%> @param The graphic handle to dissovle
%> @param The amount of time (in seconds) to take dissolving.
function dissolve(hObject,numSeconds,hideParentOnExit)
    if(nargin<3)
        hideParentOnExit=false;
    end
    fps = 25;  %1/24 causes a warning message by matlab which is limited to 1 millisecond precision
    if(ishandle(hObject))
        type = get(hObject,'type');
        if(strcmpi(type,'uicontrol'))
            style = get(hObject,'style');
            switch(lower(style))
                case 'text'
                    property = 'foregroundcolor';
                    startValue = get(hObject,property);
                    stopValue = get(hObject,'backgroundcolor');
                    canDo = true;
                otherwise
                    canDo = false;
            end
        else
            canDo = false;
        end
        
        if(canDo)
           numSteps = numSeconds*fps; 
           stepSize = zeros(size(startValue));
           for e=1:numel(stepSize)
               stepSize(e) = (stopValue(e)-startValue(e))/numSteps;
           end
           start(timer('name','dissolver','executionmode','fixedspacing','period',1/fps,'timerfcn',{@dissolveFcn, hObject,property,stepSize,stopValue,numSteps-1,hideParentOnExit}));
        end        
    else

    end
    
end

% Timer callback for the dissolve method
function dissolveFcn(timerH,~,handle,property,stepSize,stopValue,stepsLeft,hideParentOnExit)
    try
        if(ishandle(handle))
            stepsLeft = stepsLeft-1;
            if(stepsLeft<=0)
                keepGoing = false;
            else
                curValue = get(handle,property);
                if(curValue==stopValue)
                    keepGoing = false;
                else
                    keepGoing = true;
                end
            end
            if(keepGoing)
                set(handle,property,curValue+stepSize);
            else
                %                 set(handle,property,stopValue);
                set(handle,'visible','off');
                stop(timerH);  
                delete(timerH);
                if(hideParentOnExit)
                    set(get(handle,'parent'),'visible','off');
                end
            end
        else
            stop(timerH);
            delete(timerH);
        end
    catch me
        if(ishandle(handle))
            %             set(handle,property,stopValue);
            set(handle,'visible','off');
                
            if(hideParentOnExit)
                set(get(handle,'parent'),'visible','off');
            end
        end
        stop(timerH);
        delete(timerH);
    end
    
end