function axesProps = getPadacoAxesProps(optionalView)

    axesProps.primary.xtickmode='manual';
    axesProps.primary.xticklabelmode='manual';
    axesProps.primary.xlimmode='manual';
    axesProps.primary.xtick=[];
    axesProps.primary.xgrid='on';
    axesProps.primary.visible = 'on';
    
    %             axesProps.primary.nextplot='replacechildren';
    axesProps.primary.box= 'on';
    axesProps.primary.plotboxaspectratiomode='auto';
    axesProps.primary.fontSize = 14;
    % axesProps.primary.units = 'normalized'; %normalized allows it to resize automatically
    if verLessThan('matlab','7.14')
        axesProps.primary.drawmode = 'normal'; %fast does not allow alpha blending...
    else
        axesProps.primary.sortmethod = 'childorder'; %fast does not allow alpha blending...
    end
    
    axesProps.primary.ygrid='off';
    axesProps.primary.ytick = [];
    axesProps.primary.yticklabel = [];
    axesProps.primary.uicontextmenu = [];
    
    if(nargin)
        if(strcmpi(viewMode,'timeseries'))
            % Want these for both the primary (upper) and secondary (lower) axes
            axesProps.primary.xAxisLocation = 'top';
            axesProps.primary.ylimmode = 'manual';
            axesProps.primary.ytickmode='manual';
            axesProps.primary.yticklabelmode = 'manual';
            
            axesProps.secondary = axesProps.primary;
            
            % Distinguish primary and secondary properties here:
            axesProps.primary.xminortick='on';
            axesProps.primary.uicontextmenu = obj.contextmenuhandle.primaryAxes;
            
            axesProps.secondary.xminortick = 'off';
            axesProps.secondary.uicontextmenu = obj.contextmenuhandle.secondaryAxes;
            
        elseif(strcmpi(viewMode,'results'))
            axesProps.primary.ylimmode = 'auto';
            %                 axesProps.primary.ytickmode='auto';
            %                 axesProps.primary.yticklabelmode = 'auto';
            axesProps.primary.xAxisLocation = 'bottom';
            axesProps.primary.xminortick='off';
            
            axesProps.secondary = axesProps.primary;
            % axesProps.secondary.visible = 'off';
        end
    end
    
    axesProps.secondary.xgrid = 'off';
    axesProps.secondary.xminortick = 'off';
    axesProps.secondary.xAxisLocation = 'bottom';
end