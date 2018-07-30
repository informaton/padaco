% ======================================================================
%> @file PADataLineSettings.cpp
%> @brief Class for updating display properties of data found in a PAData
%> object.
% ======================================================================
%> @brief The PADataLineSettings class handles the interface between the
%> line handles connected with PAData signals.
% ======================================================================
classdef PADataLineSettings < handle
    properties(Constant)
        figureFcn = @singleStudyDisplaySettings;
    end
    properties(SetAccess=protected)
        figureH;
        viewSelection;
    end
    properties(Access=protected)
        dataObj;
        labels;
        handles;
    end
    methods
        function this = PADataLineSettings(dataObjIn, viewSelection, lineHandles)
            this.figureH = this.figureFcn('visible','off');
            set(this.figureH,'visible','on');
            this.handles = guidata(this.figureH);
            if(nargin<2 || ~isa(dataObjIn,'PAData') || ~any(strcmpi(viewSelection,fieldnames(dataObjIn.label))))
                
            else
                viewSelections = fieldnames(dataObjIn.label); % have to watch out for cases where view selection comes in as 'timeseries' and field name is actually 'timeSeries'
                this.viewSelection = viewSelections{strcmpi(viewSelections,viewSelection)};
                this.dataObj = dataObjIn;
                this.buildRows(lineHandles);
            end
            set(this.figureH,'visible','on');
        end 
        
        function numLines = getNumLines(this, structIn)
            if(nargin<2)
                numLines = this.getNumLines(this.dataObj.label.(this.viewSelection));
            else
                if(isstruct(structIn))
                    numLines = 0;
                    fNames = fieldnames(structIn);
                    for f=1:numel(fNames)
                        numLines = numLines + this.getNumLines(structIn.(fNames{f}));
                    end                    
                else                    
                    numLines = 1;
                end
            end
        end
    end
    
    methods(Access=private)
        function buildRows(this, lineHandles)
            % Delta referes to yDelta
            numLines = numel(lineHandles);

            linePanelPos = get(this.handles.panel_lineProperties,'position');
            buttonPanelPos = get(this.handles.panel_buttons,'position');
            
            figurePos = get(this.figureH,'position');
            labelPos = get(this.handles.text_visible,'position');
            % labelRow_marginTop = linePanelPos(4) - labelPos(2);
            row1Pos = get(this.handles.check_show_1,'position');
            rowYDelta = labelPos(2) - row1Pos(2);
            panelDelta = linePanelPos(2) + (numLines-1)*rowYDelta;
            
            
            figurePos(2) = figurePos(2)-panelDelta;  % shift down
            figurePos(4) = figurePos(4)+panelDelta;  % then grow up
%             buttonPanelPos(2) = buttonPanelPos(2) - panelDelta; % shift down - is this necessary?
            linePanelPos(4) = linePanelPos(4) + panelDelta;
            set(this.figureH,'position',figurePos);
%             set(this.handles.panel_buttons,'position',buttonPanelPos);
            set(this.handles.panel_lineProperties,'position',linePanelPos);
            labelPos(2) = labelPos(2)+panelDelta;
            row1Pos(2) = row1Pos(2)+panelDelta;
            set(this.handles.text_visible,'position',labelPos);
            set(this.handles.check_show_1,'position',row1Pos);
            
            
        end
    end
end