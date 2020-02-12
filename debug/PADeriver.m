%> @file PADeriver.cpp
%> @brief PADeriver serves as model and controller for count derivation
%> working using Padaco based classes.
% ======================================================================
classdef PADeriver < handle
    
    properties(Constant)
        FIGURE_NAME = 'Counts derivation tool';
        SOI_LABELS = {'X','Y','Z','Magnitude'};
        SOI_FIELDS = {'x','y','z','vecMag'};
        SRC_FORMAT_LABELS = {'Raw (g)','Raw (ubits)'};
        SRC_FORMAT_FIELDS = {'raw','ubit'};
        
        DERIVE_LABELS = {
            'Max'
            'Sum'
            };
        DERIVE_TAGS = {
            'max'
            'sum'
            };
        
        FILTER_NAMES = {
            'none' % Use data as is
            'fir1' % FIR filter design using the window method.
            'fir2' % FIR arbitrary shape filter design using the frequency sampling method.
            %'kaiserord' % FIR order estimator
            % 'fircls1' % Low & high pass FIR filter design by constrained least-squares.
            'firls' % Linear-phase FIR filter design using least-squares error minimization.  FIR filter which has the best approximation to the desired frequency response described by F and A in the least squares sense.
            %'fircls' % Linear-phase FIR filter design by constrained least-squares.
            %'cfirpm' % Complex and nonlinear phase equiripple FIR filter design.
            'firpm' % Parks-McClellan optimal equiripple FIR filter design.
            'butter' % Butterworth digital and analog filter design.
            'cheby1' % Chebyshev Type I digital and analog filter design.
            'cheby2' % Chebyshev Type II digital and analog filter design.
            'ellip' % Elliptic or Cauer digital and analog filter design.
            % 'besself' % Bessel analog filter design.  Note that Bessel filters are lowpass only.
            }
        
        WINDOW_OPTIONS = {
            'Bartlett',@bartlett       ,'Bartlett window.';
            'Bartlett-Hanning',@barthannwin    ,'Modified Bartlett-Hanning window.';
            'Blackman',@blackman       ,'Blackman window.';
            'Blackman-Harris',@blackmanharris ,'Minimum 4-term Blackman-Harris window.';
            'Bohman',@bohmanwin      ,'Bohman window.';
            'Chebyshev',@chebwin        ,'Chebyshev window.';
            'Flat Top',@flattopwin     ,'Flat Top window.';
            'Gaussian',@gausswin       ,'Gaussian window.';
            'Hamming',@hamming        ,'Hamming window.';
            'Hann',@hann           ,'Hann window.';
            'Kaiser',@kaiser         ,'Kaiser window.';
            'Nuttall',@nuttallwin     ,'Nuttall defined minimum 4-term Blackman-Harris window.';
            'Parzen',@parzenwin      ,'Parzen (de la Valle-Poussin) window.';
            'Rectangular',@rectwin        ,'Rectangular window.';
            'Taylor',@taylorwin      ,'Taylor window.';
            'Tukey',@tukeywin       ,'Tukey window.';
            'Triangular',@triang         ,'Triangular window.';
            }
    end
    
    properties(Access=private)
        figureH;
        handles;
        %> Struct with fields
        %> - raw Instance of PASensorData
        %> - count Instance of PASensorData
        dataObject;
        
        %> Struct with fields
        %> - raw
        %> - count
        %> - derived
        %> - filter
        %> - filtfilt
        data;
        
        %> Struct with fields
        %> - raw
        %> - count
        range;
        %> Struct with fields
        %> - raw Sample rate of raw acceleration
        %> - counts Number of epochs per second
        samplerate;
        
        %> Struct of line handles
        lines;
        
        %> Struct with fields describing digital filter that is applied to
        %> raw data.
        filterOptions;
        
        %> Struct with fields describing the count derivation options
        countOptions;
        
        
        %> Signal of interest, can be:
        %> - x
        %> - y
        %> - z
        %> - vecMag
        soi;  %signal of interest
        
        %> Format of signal of interest, can be:
        %> - raw_g Raw acceleration in units of gravity
        %> - raw_10 raw counts as provided by a 10 bit ADC
        %> - raw_12 raw counts as provided by a 12 bit ADC
        src_format;
        
        %> first non-zero count index
        firstNZI
        
        %> Equivalent location of first non-zero count index in the raw
        %> signal
        firstNZI_raw;
    end
    
    methods
        
        function this = PADeriver()
            this.src_format = 'raw';
            this.soi = 'x';
            this.filterOptions.start = 0.25;
            this.filterOptions.stop = 2.5;
            this.filterOptions.order = 10;
            this.filterOptions.name = 'fir1';
            this.filterOptions.type = 'filtfilt';
            this.filterOptions.dB = 3;  % peak-to-peak decibals
            this.filterOptions.windowFcn = this.WINDOW_OPTIONS{1,2};
            
            this.countOptions.deriveMethod = 'max';
            this.initGUI();
        end
        
        function updatePlots(this)
            this.showBusy('Updating plot');
            try
                this.disableControls();
                
                this.syncToUI();
                this.filterData();
                this.countFilterData();
                this.plotCounts();
            catch me
                showME(me);
            end
            
            this.enableControls();
            this.showReady();
            
        end
        
        function dataInRange =  getDataInRange(this,label)            
            switch(lower(label))
                case 'raw'
                    shiftBy = this.getShiftBy('raw');
                    dataInRange = this.dataObject.raw.accel.(this.src_format).(this.soi)(this.range.raw - shiftBy);
                    if(strcmpi(this.src_format,'ubit'))
                        %                         dataInRange = bitand(dataInRange,sum(2.^(10:12)));
%                                                  dataInRange = bitand(dataInRange,sum(2.^(0:9)));
%                         dataInRange = floor(dataInRange/4); % brings maximum value from 4095 to 1023
                        %                         dataInRange = bitshift(dataInRange,2,'uint16');
                        %                         dataInRange = dataInRange - floor(dataInRange/4); % only shows the higher order values
                        %                         dataInRange = dataInRange - 2^11-2^10; % only shows the lower bits
                    end
                    
                case 'counts'
                    dataInRange = this.dataObject.count.accel.count.(this.soi)(this.range.count);
                otherwise
                    shiftBy = this.getShiftBy('raw');
                    dataInRange = this.dataObject.raw.accel.(this.src_format).(this.soi)(this.range.raw - shiftBy);
            end
        end
        
        function shiftSamples = getShiftBy(this,label)
             switch(lower(label))
                case 'raw'
                    shiftSamples = getMenuUserData(this.handles.menu_shiftRaw);
                case 'filtered'
                    shiftSamples = getMenuUserData(this.handles.menu_shiftFiltered);
             end            
        end
        
        function filterPassRange = getFilterRange(this)
            fStartPass = str2double(get(this.handles.edit_filterStartHz,'string'));
            fStopPass = str2double(get(this.handles.edit_filterStopHz,'string'));
            filterPassRange = [fStartPass, fStopPass];
        end
        
        function absFlag =isFilterInputAbs(this)
            absFlag = get(this.handles.check_filterAbsInput,'value');
        end
        
        function absFlag =isFilterOutputAbs(this)
            absFlag = get(this.handles.check_filterAbsOutput,'value');
        end
        
        
        
        function shiftFlag = isFilterDelayShifted(this)
            shiftBy = this.getShiftBy('filtered');
            shiftFlag = shiftBy~=0;  % get(this.handles.check_filterShiftDelay,'value') || shiftBy~=0;
        end
        

    end
        
    methods(Access=private)
        
        %% Controls - load UI configuration into object parameters.
        function syncToUI(this)
            this.soi = getMenuUserData(this.handles.menu_soi);
            this.filterOptions.name = getMenuUserData(this.handles.menu_filterName);
            this.filterOptions.order = getMenuUserData(this.handles.menu_filterOrder);
            this.filterOptions.startHz = str2double(get(this.handles.edit_filterStartHz,'string'));
            this.filterOptions.stopHz = str2double(get(this.handles.edit_filterStopHz,'string'));
            this.countOptions.deriveMethod = getMenuUserData(this.handles.menu_countDeriveMethod);
        end
        function plotCounts(this)
            line_tags = {'counts','rawCounts','rawFiltered','raw','error'};
            
            for l=1:numel(line_tags)
                lineTag = line_tags{l};
                axesTag = ['axes_',lineTag];
                ydata = this.data.(lineTag);
                xdata = 1:numel(ydata);
                stairs(this.handles.(axesTag),xdata,ydata);
                ylabel(this.handles.(axesTag),line_tags{l});
                %                 set(this.lines.(lineTag),'xdata',xdata,'ydata',ydata);
                %                 stem(this.handles.(axesTag),xdata,ydata);
            end 
        end
        
        function disableControls(this)
            disableHandles(this.handles.panel_filterOptions);
            disableHandles(this.handles.panel_signalFlow);
            
            %             set(this.handles.menu_soi,'enable','off');
            set(this.handles.push_update,'enable','off');
        end
        
        function enableControls(this)
            enableHandles(this.handles.panel_filterOptions);
            enableHandles(this.handles.panel_signalFlow);
            
            set(this.handles.menu_soi,'enable','on');
            set(this.handles.push_update,'enable','on');
        end
        
        
        %% Initializers
        function initGUI(this)
            this.figureH = deriveIt();
            this.handles = guidata(this.figureH);
            
            this.disableControls();
            
            % File panel
            set(this.handles.push_loadFile,'callback',@this.loadFileCallbackFcn);
            
            % Filter panel
            orderOptions = (0:99)';
            set(this.handles.menu_filterName,'string',this.FILTER_NAMES,'userdata',this.FILTER_NAMES,'value',find(strcmpi(this.FILTER_NAMES,this.filterOptions.name),1),'callback',@this.updatePlotsCallbackFcn);
            set(this.handles.menu_filterOrder,'string',num2str(orderOptions),'userdata',orderOptions,'value',find(orderOptions==this.filterOptions.order,1),'callback',@this.updatePlotsCallbackFcn);
            set(this.handles.menu_filterWindow,'string',this.WINDOW_OPTIONS(:,1),'value',1,'userdata',this.WINDOW_OPTIONS(:,3),'tooltipstring',this.WINDOW_OPTIONS{1,3},'callback',@this.menuWindowChangeCallbackFcn);
            set(this.handles.edit_filterStartHz,'string',num2str(this.filterOptions.start),'callback',@this.edit_positiveNumericCallbackFcn);
            set(this.handles.edit_filterStopHz,'string',num2str(this.filterOptions.stop),'callback',@this.edit_positiveNumericCallbackFcn);
            
            %% Signal flow panel
            % Raw panel

            set(this.handles.menu_input_format,'string',this.SRC_FORMAT_LABELS,...
                'userdata',this.SRC_FORMAT_FIELDS,...
                'value',find(strcmpi(this.src_format,this.SRC_FORMAT_FIELDS),1),...
                'callback',@this.updateSRC_FORMATCallbackFcn);
            
            set(this.handles.menu_soi,'string',this.SOI_LABELS,'value',find(strcmpi(this.soi,this.SOI_FIELDS),1),'userdata',this.SOI_FIELDS,'callback',@this.updateSOICallbackFcn);
            filtfiltFlag = strcmpi('filtfilt',this.filterOptions.type);
            set(this.handles.radio_filtfilt,'value',filtfiltFlag);
            set(this.handles.buttongroup_filterType,'SelectionChangedFcn',@this.updatePlotsCallbackFcn);
            %             set(this.handles.radio_filter,'value',~filtfiltFlag);
            
            % Filtered panel
            set(this.handles.check_filterAbsInput,'callback',@this.check_filterAbsInputCallback);
            set(this.handles.check_filterAbsOutput,'callback',@this.updatePlotsCallbackFcn);
            
            shiftVector = (-100:5:100)';
            shiftStr = num2str(shiftVector);
            shiftValue = find(shiftVector==0,1);
            set([this.handles.menu_shiftRaw;
                this.handles.menu_shiftFiltered],'string',shiftStr,'userdata',shiftVector,'value',shiftValue)
            set(this.handles.menu_shiftRaw,'callback',@this.menu_shiftRawByCallback);
            set(this.handles.menu_shiftFiltered,'callback',@this.menu_shiftFilteredByCallback);
             
            set(this.handles.push_update,'callback',@this.updatePlotsCallbackFcn);
            
            % count derivation panel
            set(this.handles.menu_countDeriveMethod,'string',this.DERIVE_LABELS,'userdata',this.DERIVE_TAGS,'value',find(strcmpi(this.DERIVE_TAGS,this.countOptions.deriveMethod),1),'callback',@this.updatePlotsCallbackFcn);

            
            
            
            this.initPlots();
        end
        
        
        
        function initPlots(this)
            this.labelPlots();

            %             line_tags = {'counts','rawCounts','rawFiltered','raw','error'};
            %             for l=1:numel(line_tags)
            %                 lineTag = line_tags{l};
            %                 axesTag = ['axes_',lineTag];
            %                 this.lines.(lineTag) = line([],[],'parent',this.handles.(axesTag));
            %                 ylabel(this.handles.(axesTag),lineTag);
            %             end
        end
        
        
        function labelPlots(this)
            tags = {'counts','rawCounts','rawFiltered','raw','error'};
            axesTags = strcat('axes_',tags);
            for t=1:numel(tags)
                ylabel(this.handles.(axesTags{t}),tags{t});
            end
        end
        
        %% Modeling - accessors/mutators
        function loadFile(this, count_filename)
            [filePath, ~, ~] = fileparts(count_filename);
            bin_testFile = 'activity.bin';  %firmware version 2.5.0
            
            raw_filename = fullfile(filePath,bin_testFile);
            
            this.showBusy('Loading binary data ...');
            %             set(this.figureH,'name','Loading binary data ...');
            %             drawnow();
            this.dataObject.raw = PADeriverData(raw_filename);
            
            this.showBusy('Loading count data ...');
            %             set(this.figureH,'name','Loading count data ...');
            %             drawnow();
            this.dataObject.count = PADeriverData(count_filename);
            
            %raw - sampled at 40 Hz
            %count - 1 Hz -> though upsampled from file to 40Hz during data object
            %loading.
            
            % update controls
            %                     this.updateControls();
            %                     function updateControls(this)
            
            
            set(this.figureH,'name','Processing data ...');
            drawnow();
            
            this.samplerate.raw = this.dataObject.raw.getSampleRate();
            this.samplerate.counts = this.dataObject.count.getSampleRate();
            set(this.handles.edit_samplerateCounts,'string',num2str(this.samplerate.counts));
            set(this.handles.edit_samplerateRaw,'string',num2str(this.samplerate.raw));
            
            % example conversion
            % Count - Samples   - Derivation
            %   1      1:40       0*40+1:1*40
            %   2     41:80       1*40+1:2*40
            %   n                 (n-1)*40+1:n*40
            
            this.firstNZI = find(this.dataObject.count.accel.count.(this.soi),1); % firstNonZeroCountIndex
            this.firstNZI_raw = (this.firstNZI-1)*this.samplerate.raw+1;
            
            this.updateDataStruct();
            
        end
        
        function updateDataStruct(this)
            %let's start with a value of zero if we can.
            numPreviousSeconds = 15;
            secondsToCheck = 30;
            
            if(this.firstNZI_raw>(this.samplerate.raw*numPreviousSeconds)) % If FNCV = 11, then FNCV_At_Fs = 401;
                raw_start = this.firstNZI_raw-this.samplerate.raw*numPreviousSeconds;  % If FNCV_At_Fs = 401-400 = 1;
                count_start = this.firstNZI-numPreviousSeconds;  % then FNCV = 11 - 10 = 1 q.e.d
            else
                raw_start = 1;
                count_start = 1;
            end
            
            this.range.raw = raw_start:(raw_start-1)+secondsToCheck*this.samplerate.raw;
            this.range.count = (0:secondsToCheck*this.samplerate.counts-1)+count_start;
            
            this.data.raw = this.getDataInRange('raw');
            this.data.counts = this.getDataInRange('counts');
        end
        

        
        function filterData(this)
            
            if(this.isFilterInputAbs)
                inputData = abs(this.data.raw);
            else
                inputData = this.data.raw;
            end
            
            fMax = this.samplerate.raw/2;
            
            fPass = this.getFilterRange();
            wPass = fPass/fMax;  %normalized frequency
            
            [this.data.filter, this.data.filtfilt] = this.acti_filter(inputData,this.filterOptions.name,this.filterOptions.order, this.filterOptions.windowFcn,wPass, this.filterOptions.dB);
            
            if(this.isFilterDelayShifted())
                filterShift = this.getShiftBy('filtered');
                this.data.filter = circshift(this.data.filter,filterShift);
                this.data.filtfilt = circshift(this.data.filter,filterShift);
                %                 [this.data.filter, this.data.filtfilt] = this.adjustFilterOrderDelay(this.filterOptions.order, this.data.filter, this.data.filtfilt);
            end
            
            if(this.isFilterOutputAbs)
                this.data.filter = abs(this.data.filter);
                this.data.filtfilt = abs(this.data.filtfilt);
            end
            
        end
        
        function countFilterData(this)
            if(this.isFiltfilt())
                this.data.rawFiltered = this.data.filtfilt;
            else
                this.data.rawFiltered = this.data.filter;
            end
            
            samplesToCheck = 1:numel(this.data.raw);
            x=reshape(this.data.rawFiltered(samplesToCheck),this.samplerate.raw,[]);
            
            deriveMethod = this.countOptions.deriveMethod;
            switch(deriveMethod)
                case 'sum'
                    this.data.rawCounts = sum(x); % sum down the columns
                case 'max'
                    this.data.rawCounts = max(x);
            end
            this.data.rawCounts = max(0,[0,(diff(this.data.rawCounts))]);
                    
            
            this.data.error = this.data.counts(:) - this.data.rawCounts(:);
        end
        
        function filtfiltFlag =  isFiltfilt(this)
            filtfiltFlag = get(this.handles.radio_filtfilt,'value');
        end
        
        %% Callbacks
        
            
        
        function updateSRC_FORMATCallbackFcn(this, hObject, eventdata)
            this.src_format = getMenuUserData(hObject);
            this.data.raw = this.getDataInRange('raw');
            this.data.counts = this.getDataInRange('counts');
            this.updatePlots();
        end
            
        
        function updateSOICallbackFcn(this, hObject, eventdata)
            this.soi = getMenuUserData(hObject);
            this.data.raw = this.getDataInRange('raw');
            this.data.counts = this.getDataInRange('counts');
            this.updatePlots();
        end
        
        function menuWindowChangeCallbackFcn(this, hObject, eventdata)
            set(hObject,'tooltipstring',getMenuUserData(hObject));
            this.filterOptions.windowFcn = this.WINDOW_OPTIONS{get(hObject,'value'),2};
            this.updatePlots();
        end
        
        
        function loadFileCallbackFcn(this,hObject, eventdata)
            
            
            testingPath = '/Users/unknown/Data/GOALS/Temp';
            % sqlite_testFile = '704397t00c1_1sec.sql';  % SQLite format 3  : sqlite3 -> .open 704397t00c1_1sec.sql; .tables; select * from settings; .quit;  (ref: https://www.sqlite.org/cli.html)
            csv_testFile = '704397t00c1.csv';
            %             raw_filename = fullfile(testingPath,bin_testFile);
            count_filename = fullfile(testingPath,csv_testFile);
                        
            count_filename = uigetfullfile({'*.csv','Counts data (*.csv)'},'Select counts file',...
                count_filename);
            
            if(~isempty(count_filename))
                
                try
                    this.showBusy();
                    set(hObject,'enable','off');
                    
                    this.loadFile(count_filename);
                    
                    this.updatePlots();
                    
                catch me
                    showME(me);
                    
                end
                set(hObject,'enable','on');
                drawnow();
                
                
            end
            
            this.showReady();
        end
        
        function updatePlotsCallbackFcn(this,hObject,eventdata)
            this.updatePlots();
        end
        
        function menu_shiftRawByCallback(this,hObject,eventData)        
            this.data.raw = this.getDataInRange('raw');
            this.updatePlots();
        end

        function menu_shiftFilteredByCallback(this, varargin)
            this.updatePlots();
        end
        
        
        function check_filterAbsInputCallback(this,hObject,eventdata)
            this.data.raw = this.getDataInRange('raw');
            if(this.isFilterInputAbs())
                this.data.raw = abs(this.data.raw);
            end
            this.updatePlots();
        end
        
        function edit_positiveNumericCallbackFcn(this,hObject,eventdata)
            newValue = str2double(get(hObject,'string'));
            if(isempty(newValue) || isnan(newValue) || newValue<0)
                tag = get(hObject,'tag');
                if(strcmpi(tag,'edit_filterStopHz'))
                    set(hObject,'string',this.filterOptions.stopHz);
                elseif(strcmpi(tag,'edit_filterStartHz'))
                    set(hObject,'string',this.filterOptions.startHz);                    
                else
                    warndlg(sprintf('Unknown tag: %s',tag));
                end
                fprintf(1,'Bad value entered!\n');
                
            else
                this.updatePlots();
                %fprintf(1,'Good value entered\n');
            end
            
        end
        
        
        %% Misc support
                % --------------------------------------------------------------------
        %> @brief Shows busy status (mouse becomes a watch).
        %> @param obj Instance of PAView  
        %> @param status_label Optional string which, if included, is displayed
        %> in the figure's status text field (currently at the top right of
        %> the view).
        %> @param axesTag Optional tag, that if set will set the axes tag's
        %> state to 'busy'.  See setAxesState method.
        % --------------------------------------------------------------------
        function showBusy(this,status_label)
            set(this.figureH,'pointer','watch');
            
            if(nargin>1)
                set(this.figureH,'name',status_label);
            end
            drawnow();
        end  
        
        % --------------------------------------------------------------------
        %> @brief Shows ready status (mouse becomes the default pointer).
        %> @param axesTag Optional tag, that if set will set the axes tag's
        %> state to 'ready'.  See setAxesState method.
        %> @param obj Instance of PAView        
        % --------------------------------------------------------------------
        function showReady(this)
            set(this.figureH,'pointer','arrow');
            set(this.figureH,'name',this.FIGURE_NAME);
            drawnow();
        end
        
    end
    
    methods(Static)
        function varargout = adjustFilterOrderDelay(n_order, varargin)
            varargout = cell(size(varargin));
            delay = floor(n_order/2);
            %account for the delay...
            
            for v=1:numel(varargin)
                curSig = varargin{v};
                varargout{v} = [curSig(delay+1:end); zeros(delay,1)];
            end
        end
        
        function [filt_sigOut, filtfilt_sigOut] = acti_filter(sigIn, filterName, n_order, windowFcn, wPass, peak2peakDB)
            
            if(nargin<5 || isempty(peak2peakDB))
                peak2peakDB = 3;  % reduces by 1/2
                %peak2peakDB = .1;
            end
            
            if(nargin<4 || isempty(n_order))
                n_order = 2;
            end
            
            h_a = 1;
            bandPassMag = [0 1 1 0];
            switch(filterName)
                case 'none'
                    h_a = 1;
                    h_b = 1;
                case 'fir1'
                    wind = windowFcn(n_order+1);

                    h_b = fir1(n_order, wPass, wind,'scale');
                    h_a = 1;
                    %                     B = fir1(N,Wn,kaiser(N+1,4))
                    %                         uses a Kaiser window with beta=4. B = fir1(N,Wn,'high',chebwin(N+1,R))
                    %                         uses a Chebyshev window with R decibels of relative sidelobe
                    %                         attenuation.                    
                case 'fir2' % FIR arbitrary shape filter design using the frequency sampling method.            
                    wind = windowFcn(n_order+1);

                    wPass = [0 wPass 1];
                    h_b = fir2(n_order, wPass,bandPassMag,wind);
                    h_a = 1;

                % case 'fircls1' % Low & high pass FIR filter design by constrained least-squares.
                case 'firls' % Linear-phase FIR filter design using least-squares error minimization.  FIR filter which has the best approximation to the desired frequency response described by F and A in the least squares sense.
                    wPass = [0 wPass 1];
                    h_b = firls(n_order, wPass, bandPassMag);
                    
                    %                     h_b = firls(n_order, wPass, bandPassMag,'hilbert');
                    %
                    %                     h_b = firls(n_order, wPass, bandPassMag,'differentiator');
                    
                % case 'fircls' % Linear-phase FIR filter design by constrained least-squares.
                % case 'cfirpm' % Complex and nonlinear phase equiripple FIR filter design.
                
                % Optimal equiripple
                case 'firpm' % Parks-McClellan optimal equiripple FIR filter design.
                     wPass = [0 wPass 1];
                    h_b = firls(n_order, wPass, bandPassMag);
                    
                    % IIR design
                case 'butter' % Butterworth digital and analog filter design.
                    [h_b,h_a] = butter(n_order, wPass);
                case 'cheby1'  % Chebyshev Type I digital and analog filter design.
                    [h_b,h_a] = cheby1(n_order, peak2peakDB, wPass, 'bandpass');
                case 'cheby2' % Chebyshev Type II digital and analog filter design.
                    [h_b,h_a] = cheby2(n_order, peak2peakDB, wPass, 'bandpass');
                case 'ellip' % Elliptic or Cauer digital and analog filter design.    
                    RippleStop = 50;  %Minimum stop band attenuation
                     % peak2peakDB = peak-to-peak ripple.
                    [h_b, h_a] = ellip(n_order, peak2peakDB, RippleStop, wPass);
                otherwise
                    [h_b,h_a] = cheby1(n_order, peak2peakDB, wPass, 'bandpass');
            end
            
            % Filter data
            filt_sigOut = filter(h_b,h_a, sigIn);            
            filtfilt_sigOut = filtfilt(h_b,h_a, sigIn);
            
        end
        
        
    end
    
end