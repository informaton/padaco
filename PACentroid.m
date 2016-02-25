% ======================================================================
%> @file PACentroid.cpp
%> @brief Class for clustering results data produced via padaco's batch
%> processing.
% ======================================================================
classdef PACentroid < handle
    %> @brief The sort order can be difficult to understand.  First, the
    %> adaptive k-means algorithm is applied and centroids are found.  The
    %> centroids are labeled arbitrarily according to the index or position
    %> in which they are discovered.  There 'popularity' is determined by the
    %> number of member shapes a centroid has compared to other centroids.  
    %> Centroids are ordered according to popularity from least to greatest
    %> number of member shapes (most popular).  This is the sort order,
    %> where 1 is the least popular and N (for N centroids found) is the
    %> most popular.  A centroid of index or COI is any centroid that is of
    %> interest to the user.  Users are typically presented with centroids
    %> in order of their popularity as this provides more meaning than the
    %> initial index given to the centroid during the adaptive k-means
    %> processing.  To go from popularity 'p' (where p = 1 for least popular to p = N for most popular)
    %> to the centroid's index use @c coiSortOrderToIndex(p).  
    %> To determine the popularity of centroid at initial index c, use
    %> coiIndex2SortOrder(c), where a value of 1 is least pouplar and a
    %> value of N is most popular.
    properties(Access=private)
        %> Struct with cluster calculation settings.  Fields include
        %> - @c minClusters
        %> - @c maxClusters
        %> - @c thresholdScale        
        settings;
        
        %> NxM array of N profiles of length M (M is the centroid
        %> dimensionality)
        loadShapes;
        
        loadShapeIDs;
        uniqueLoadShapeIDs;
        
        %> Nx1 vector of centroid index for loadShape profile associated with its row.
        loadshapeIndex2centroidIndexMap;
        
        %> CxM array of C centroids of size M.
        centroidShapes;
        
        %> Sorted distribution of centroid shapes by frequency of children load shape members.
        %> (Cx1 vector - where is C is the number centroids)
        histogram;
        
        %> Nx1 vector that maps the constructor's input load shapes matrix
        %> to the sorted  @c loadShapes matrix.
        sortIndices;
        
        %> Cx1 vector that maps load shapes' original cluster indices to
        %> the equivalent cluster index after clusters have been sorted
        %> by their load shape count.  Equivalen to coiIndex2SortOrder
        centroidSortMap;
        
        %> Alias for centroidSortMap
        coiIndex2SortOrder;
        
        %> map for going from sort order to coi index.
        coiSortOrder2Index;
        
        
        %> The sort order index for the centroid of interest (coi) 
        %> identified for analysis.  It is 
        %> initialized to the most frequent centroid upon successful
        %> class construction or subsequent, successful call of
        %> calculateCentroids.  (i.e. A value of 1 refers to the centroid with fewest members,
        %> while a value of C refers to the centroid with the most members (as seen in histogram)
        coiSortOrder;  
        
        %> logical sort order index for the centroids of interest (cois)
        %> identified for analysis and possible comparison.  It is 
        %> initialized to the coiSortOrder's index being true, and the
        %> remaining indices being false.
        coiToggleOrder;

        %> A line handle for updating clustering performace.  Default is
        %> -1, which means that clustering performance is not displayed.
        %> This value is initialized in the constructor based on input
        %> arguments.
        performanceLineHandle;
        
        %> Similar to performance line, but is an axes handle.
        performanceAxesHandle;
        
        %> Text handle to send status updates to via set(textHandle,'string',statusString) type calls.
        statusTextHandle;
        
        %> Measure of performance.  Currently, this is the Calinski index.
        performanceMeasure;
        
        %> struct with X, Y data, and last statusStr calculated during
        %> adaptive k means.
        performanceProgression;
    end
            
    methods        
        % ======================================================================
        %> @param loadShapes NxM matrix to  be clustered (Each row represents an M dimensional value).
        %> @param settings  Optional struct with following fields [and
        %> default values]
        %> - @c minClusters [40]  Used to set initial K
        %> - @c maxClusters [0.5*N]
        %> - @c clusterThreshold [1.5]                  
        %> @param Optional axes or line handle for displaying clustering progress.
        %> - If argument is a handle to a MATLAB @b axes, then a line handle
        %> will be added to the axes and adjusted with clustering progress.
        %> - If argument is a handle to a MATLAB @b line, then the handle
        %> will be manipulated directly in its current context (i.e. whatever
        %> axes it currently falls under).
        %> - If argument is not included, empty, or is not a line or
        %> axes handle then progress will only be displayed to the console
        %> (default)
        %> @note Including a handle increases processing time as additional calculations
        %> are made to measuring clustering separation and performance.
        %> @param Optional text handle to send status updates to via set(textHandle,'string',statusString) type calls.
        %> Status updates are sent to the command window by default.
        %> @param Optional Nx1 cell string with load shape source
        %> identifiers (e.g. which participant they came from).
        %> @retval Instance of PACentroid on success.  Empty matrix on
        %> failure.
        % ======================================================================        
        function this = PACentroid(loadShapes,settings,axesOrLineH,textHandle,loadShapeIDs)    
            
            this.init();
            if(nargin<5)
                loadShapeIDs = [];
                if(nargin<4)
                    textHandle = [];
                    if(nargin<3)
                        axesOrLineH = [];
                        if(nargin<2)
                            settings = [];
                        end
                    end
                end
            end

            if(isempty(settings))
                N = size(loadShapes,1);
                settings.minClusters = 10;
                settings.maxClusters = ceil(N/2);
                settings.clusterThreshold = 0.2;
            end
            if(~isempty(textHandle) && ishandle(textHandle) && strcmpi(get(textHandle,'type'),'uicontrol') && strcmpi(get(textHandle,'style'),'text'))
                this.statusTextHandle = textHandle;
                
            else
                this.statusTextHandle = -1;
            end
            
            if(~isempty(axesOrLineH) && ishandle(axesOrLineH))
                handleType = get(axesOrLineH,'type');
                if(strcmpi(handleType,'axes'))
                    this.performanceAxesHandle = axesOrLineH;
                    this.performanceLineHandle = line('parent',axesOrLineH,'xdata',nan,'ydata',nan,'linestyle',':','marker','o','markerfacecolor','b','markeredgecolor','k','markersize',10);
                elseif(strcmpi(handleType,'line'))
                    this.performanceLineHandle = axesOrLineH;
                    set(this.performanceLineHandle,'xdata',nan,'ydata',nan,'linestyle',':','marker','o','markerfacecolor','b','markeredgecolor','k','markersize',10);
                    this.performanceAxesHandle = get(axesOrLineH,'parent');
                else
                    this.performanceAxesHandle = -1;
                    this.performanceLineHandle = -1;
                end
            else
                this.performanceLineHandle = -1;
            end
            
            this.performanceMeasure = [];
            this.settings.thresholdScale = settings.clusterThreshold;
            %/ Do not let K start off higher than 
            this.settings.minClusters = min(floor(size(loadShapes,1)/2),settings.minClusters);
            
            if(isfield(settings,'maxCluster'))                
                maxClusters = settings.maxClusters;
            else
                maxClusters = ceil(size(loadShapes,1)/2);
            end
            
            this.settings.maxClusters = maxClusters;
            this.loadShapes = loadShapes;
            this.loadShapeIDs = loadShapeIDs;
            
            this.uniqueLoadShapeIDs = unique(loadShapeIDs);
            this.calculateCentroids();  
        end
        
        % ======================================================================
        %> @brief Determines if clustering failed or succeeded (i.e. do centroidShapes
        %> exist)
        %> @param Instance of PACentroid        
        %> @retval failedState - boolean
        %> - @c true - The clustering failed
        %> - @c false - The clustering succeeded.
        % ======================================================================
        function failedState = failedToConverge(this)
            failedState = isempty(this.centroidShapes);
        end        
        
        function distribution = getHistogram(this)
            distribution = this.histogram;
        end
        % ======================================================================
        %> @brief Returns the number of centroids/clusters obtained.
        %> @param Instance of PACentroid        
        %> @retval Number of centroids/clusters found.
        % ======================================================================
        function n = numCentroids(this)
            n = size(this.centroidShapes,1);
        end
        
        % ======================================================================
        %> @brief Alias for numCentroids.
        %> @param Instance of PACentroid        
        %> @retval Number of centroids/clusters found.
        % ======================================================================
        function n = getNumCentroids(this)
            n = this.numCentroids();
        end
        
        % ======================================================================
        %> @brief Returns the number of load shapes clustered.
        %> @param Instance of PACentroid        
        %> @retval Number of load shapes clustered.
        % ======================================================================
        function n = numLoadShapes(this)
            n = size(this.loadShapes,1);
        end        
        
        % ======================================================================
        %> @brief Alias for numLoadShapes.
        %> @param Instance of PACentroid        
        %> @retval Number of load shapes clustered.
        % ======================================================================
        function n = getNumLoadShapes(this)
            n = this.numLoadShapes();
        end
        
        % ======================================================================
        %> @brief Initializes (sets to empty) member variables.  
        %> @param Instance of PACentroid        
        %> @note Initialzed member variables include
        %> - loadShape2CentroidShapeMap
        %> - centroidShapes
        %> - histogram
        %> - loadShapes
        %> - sortIndices
        %> - coiSortOrder        
        % ======================================================================                
        function init(this)
            this.loadshapeIndex2centroidIndexMap = [];
            this.centroidShapes = [];
            this.histogram = [];
            this.loadShapes = [];
            this.sortIndices = [];
            this.coiSortOrder = [];
            this.coiToggleOrder = [];
        end
                
        function didChange = toggleOnNextCOI(this)
            didChange = this.toggleOnCOISortOrder(this.coiSortOrder+1);            
        end
        
        function didChange = toggleOnPreviousCOI(this)
            didChange = this.toggleOnCOISortOrder(this.coiSortOrder-1);
        end
        
        %> @brief This sets the given index into coiToggleOrder to true
        %> and also sets the coiSortOrder value to the given index.  This
        %> performs similarly to setCOISortOrder, but here the
        %> coiToggleOrder is not reset (i.e. all toggles turned off).
        %> @param this Instance of PACentroid
        %> @param sortOrder
        %> @retval didChange A boolean response
        %> - @b True if the coiToggleOrder(sortOrder) was set to true
        %> and coiSortOrder was set equal to sortOrder
        %> - @b False otherwise
        function didChange = toggleOnCOISortOrder(this, sortOrder)
            sortOrder = round(sortOrder);
            if(sortOrder<=this.numCentroids() && sortOrder>0)
                this.coiSortOrder = sortOrder;
                this.coiToggleOrder(sortOrder) = true;
                didChange = true;
            else
                didChange = false;
            end
        end
        
        function didChange = increaseCOISortOrder(this)
            didChange = this.setCOISortOrder(this.coiSortOrder+1);
        end
        
        function didChange = decreaseCOISortOrder(this)
            didChange = this.setCOISortOrder(this.coiSortOrder-1);
        end
        
        function didChange = setCOISortOrder(this, sortOrder)
            sortOrder = round(sortOrder);
            if(sortOrder<=this.numCentroids() && sortOrder>0)
                this.coiSortOrder = sortOrder;
                this.coiToggleOrder(:) = false;
                this.coiToggleOrder(sortOrder) = true;
                didChange = true;
            else
                didChange = false;
            end
        end  
        
        function toggleCOISortOrder(this, toggleSortIndex)
            if(toggleSortIndex>0 && toggleSortIndex<=this.numCentroids())
                this.coiToggleOrder(toggleSortIndex) = ~this.coiToggleOrder(toggleSortIndex);
                if(this.coiToggleOrder(toggleSortIndex))
                    this.coiSortOrder = toggleSortIndex;
                end
            end
        end
        
        function performance = getClusteringPerformance(this)
            performance = this.performanceMeasure;
        end
                
        
        %==================================================================
        %> @brief Returns the index of centroid matching the current sort
        %> order value (i.e. of member variable @c coiSortOrder) or of the
        %> input sortOrder provided.
        %> @param this Instance of PACentroid.
        %> @param sortOrder (Optional) sort order for the centroid of interest to
        %> retrive the index of.  If not provided, the value of member variable @c coiSortOrder is used.
        %> @retval coiIndex The centroid index or tag. 
        %> @note The coiIndex is the original index given to it during clustering.  
        %> The sortOrder is the centroids rank in comparison to all
        %> centroids found during clustering, with 1 being the least popular
        %> and N (the number of centroids found) being the most popular.
        %==================================================================
        function coiIndex = getCOIIndex(this,sortOrder)
            if(nargin<2 || isempty(sortOrder) || sortOrder<0 || sortOrder>this.numCentroids())
                sortOrder = this.coiSortOrder;
            end
            % convert to match the index the centroid load shape corresponds to.
            coiIndex = this.coiSortOrder2Index(sortOrder);           
             
        end
        
        function sortOrder = getCOISortOrder(this,coiIndex)
            if(nargin<2 || isempty(coiIndex) || coiIndex<0 || coiIndex>this.numCentroids())
                sortOrder = this.coiSortOrder;
            else
                sortOrder = this.coiIndex2SortOrder(coiIndex);
            end
        end
        
        function toggleOrder = getCOIToggleOrder(this)
            toggleOrder = this.coiToggleOrder;
        end
        
        % ======================================================================
        %> @brief Returns a descriptive struct for the centroid of interest (coi) 
        %> which is determined by the member variable coiSortOrder.
        %> @param Instance of PACentroid
        %> @param sortOrder Optional index to use to obtain a centroid of
        %> interest according to the given sort order ; default is to use the
        %> value of this.coiSortOrder.
        %> @retval Structure for centroid of interest.  Fields include
        %> - @c sortOrder The sort order of coi.  If all centroids are placed in
        %> a line numbering from 1 to the number of centroids in increasing order of
        %> the number of load shapes the centroid has clustered to it, then the sort order
        %> is the value of the number on the line for the coi.  The sort order of
        %> a coi having the fewest number of load shape members is 1, while the sort
        %> sort order of a coi having the largest proportion of load shape members has 
        %> the value C (centroid count).
        %> - @c index - id of the coi.  This is its original, unsorted
        %> index value which is the range of [1, C]
        %> - @c shape - 1xM vector.  The coi.
        %> - @c memberIndices = Lx1 logical vector indices of member shapes
        %> obtained from the loadShapes member variable, for the coi.  L is
        %> the number of load shapes (see numLoadShapes()).
        %> @note memberShapes = loadShapes(memberIndices,:)
        %> - @c memberShapes - NxM array of load shapes clustered to the coi.
        %> - @c numMembers - N, the number of load shapes clustered to the coi.
        % ======================================================================        
        function coi = getCentroidOfInterest(this, sortOrder)
            if(nargin<2 || isempty(sortOrder) || sortOrder<0 || sortOrder>this.numCentroids())
                sortOrder = this.coiSortOrder;
            end
            
            % order is sorted from 1: most popular to numCentroids: least popular
            coi.sortOrder = sortOrder;
            
            % convert to match the index the centroid load shape corresponds to.
            coi.index = this.coiSortOrder2Index(coi.sortOrder);     
            
            % centroid shape for the centroid index.
            coi.shape = this.centroidShapes(coi.index,:);
            
            % member shapes which have that same index.  The
            % loadshapeIndex2centroidIndexMap row index corresponds to the member index,
            % while the value at that row corresponds to the centroid
            % index.  We want the rows with the centroid index:            
            coi.memberIndices = coi.index==this.loadshapeIndex2centroidIndexMap;
            
            % Now we can pull the member variables that were
            % clustered to the centroid index of interest.
            coi.memberShapes = this.loadShapes(coi.memberIndices,:);
            coi.memberIDs = this.loadShapeIDs(coi.memberIndices,:);
            coi.numMembers = size(coi.memberShapes,1);
        end


        
        %> @brief Returns the loadshape IDs.  These are the identifiers number of centroids that are currently of
        %> interest, based on the number of positive indices flagged in
        %> coiToggleOrder.
        %> @param this Instance of PACentroid.
        %> @retval loadShapeIDs Parent identifier for each load shape.
        %> Duplicate values in loadShapeIDs represent the same source (e.g. a
        %> specific person).
        function loadShapeIDs = getLoadShapeIDs(this)
            loadShapeIDs = this.loadShapeIDs;
        end
                
        function uniqueLoadShapeIDs = getUniqueLoadShapeIDs(this)
            uniqueLoadShapeIDs = this.uniqueLoadShapeIDs;
        end
        
        function uniqueCount = getUniqueLoadShapeIDsCount(this)
            uniqueCount = numel(this.uniqueLoadShapeIDs);
        end
        
        %> @brief Returns the number of centroids that are currently of
        %> interest, based on the number of positive indices flagged in
        %> coiToggleOrder.
        %> @param this Instance of PACentroid.
        %> @retval numCOIs Number of centroids currently of interest: value
        %> is in the range [1, this.numCentroids].
        function numCOIs = getCentroidsOfInterestCount(this)
            numCOIs = sum(this.coiToggleOrder);
        end
        
        %> @brief Returns the number of centroids that are currently of
        %> interest, based on the number of positive indices flagged in
        %> coiToggleOrder.
        %> @param this Instance of PACentroid.
        %> @retval cois Cell of centroid of interest structs.  See
        %> getCentroidOfInterest for description of centroid of interest
        %> struct.
        function cois = getCentroidsOfInterest(this)
            numCOIs = this.getCentroidsOfInterestCount();
            if(numCOIs<=1)
                cois = {this.getCentroidOfInterest()};
            else
                cois = cell(numCOIs,1);
                coiSortOrders = find(this.coiToggleOrder);
                for c=1:numel(coiSortOrders)
                    cois{c} = this.getCentroidOfInterest(coiSortOrders(c));
                end
            end
        end
        
        % ======================================================================
        %> @brief Clusters input load shapes by centroid using adaptive
        %> k-means, determines the distribution of centroids by load shape
        %> frequency, and stores the sorted centroids, load shapes, and
        %> distribution, and sorted indices vector as member variables.
        %> See reset() method for a list of instance variables set (or reset on
        %> failure) from this method.
        %> @param Instance of PACentroid
        %> @param inputLoadShapes
        %> @param Structure of centroid configuration parameters.  These
        %> are passed to adaptiveKmeans method.        
        % ======================================================================
        function calculateCentroids(this, inputLoadShapes, inputSettings)

            if(nargin<3)
                inputSettings = this.settings;
                if(nargin<2)
                    inputLoadShapes = this.loadShapes;
                end
            end
            useDefaultRandomizerSeed = true;
            
            if(ishandle(this.statusTextHandle))
               set(this.statusTextHandle ,'string',{sprintf('Performaing adaptive K-means algorithm of %u loadshapes with a threshold of %0.3f',this.numLoadShapes(),this.settings.thresholdScale)});                
            end            
            [this.loadshapeIndex2centroidIndexMap, this.centroidShapes, this.performanceMeasure, this.performanceProgression] = this.adaptiveKmeans(inputLoadShapes,inputSettings, useDefaultRandomizerSeed,this.performanceAxesHandle,this.statusTextHandle);
            if(~isempty(this.centroidShapes))                
                [this.histogram, this.centroidSortMap] = this.calculateAndSortDistribution(this.loadshapeIndex2centroidIndexMap);%  was -->       calculateAndSortDistribution(this.loadshapeIndex2centroidIndexMap);
                this.coiSortOrder2Index = this.centroidSortMap;
                [~,this.coiIndex2SortOrder] = sort(this.centroidSortMap,1,'ascend');

                %                 [a,b]=sort([1,23,5,6],'ascend');
                %                 [c,d] = sort(b,'ascend');  %for testings
                if(~this.setCOISortOrder(this.numCentroids()))
                    fprintf(1,'Warning - could not set the centroid of interest sort order to %u\n',this.numCentroids);
                end
            else
                fprintf('Clustering failed!  No clusters found!\n');
                this.init();     
            end
        end
        
        function h= plotPerformance(this, axesH)
            X = this.performanceProgression.X;
            Y = this.performanceProgression.Y;
            h=this.plot(axesH,X,Y);
            set(axesH,'xlim',[min(X)-0.5,max(X)+0.5],'ylimmode','auto','ygrid','on','ytickmode','auto','xtickmode','auto','xticklabelmode','auto','yticklabelmode','auto');
            title(axesH,this.performanceProgression.statusStr,'fontsize',14);
        end          

        %> @brief Calculates within-cluster sum of squares (WCSS); a metric of cluster tightness.  
        %> @note This measure is not helpful when clusters are not well separated (see @c getCalinskiHarabaszIndex).
        %> @param Instance PACentroid
        %> @retval The within-cluster sum of squares (WCSS); a metric of cluster tightness
        function wcss = getWCSS(varargin)
            fprintf(1,'To be finished');
            wcss = [];
        end
        
        %> @brief Returns struct useful for logisitic or linear regression modelling.
        %> @param Instance of PACentroid.
        %> @retval Struct with fields defining dependent variables to use in the
        %> model.  Fields include:
        %> - @c values NxM array of counts for M centroids (the covariate index) for N subject
        %> keys.
        %> - @c memberIDs Nx1 array of unique keys corresponding to each row.
        %> - @c colnames 1xM cell string of names describing the covariate columns.
        function covariateStruct = getCovariateStruct(this)
            subjectIDs = this.getUniqueLoadShapeIDs(); %    unique(this.loadShapeIDs);
            numSubjects = numel(subjectIDs);
            
            values = zeros(numSubjects,this.numCentroids);
            
            for row=1:numSubjects
                try
                    curSubject = subjectIDs(row);
                    centroidsForSubject = this.loadshapeIndex2centroidIndexMap(this.loadShapeIDs==curSubject);
                    for c=1:numel(centroidsForSubject)
                        coi = centroidsForSubject(c);
                        values(row,coi) = values(row,coi)+1;
                    end
                catch me
                    showME(me);
                    rethrow(me);
                end
            end
            
            colnames = regexp(sprintf('Centroid #%u\n',1:this.numCentroids),'\n','split');            

            colnames(end) = [];  %remove the last cell entry which will be empty.
            
            covariateStruct.memberIDs = subjectIDs;
            covariateStruct.values = values;
            covariateStruct.colnames = colnames;
            
        end
        
    end

    methods(Static, Access=private)
        % ======================================================================
        %> @brief Calculates the distribution of load shapes according to
        %> centroid, in ascending order.
        % @param Instance of PACentroid
        %> @param loadShapeMap Nx1 vector of centroid indices.  Each
        %> element's position represents the loadShape.  
        %> @note This is the @c @b idx parameter returned from kmeans
        % @param number of centroids (i.e number of bins/edges to use when
        % calculating the distribution)
        %> @retval sortedCounts Cx1 vector where sourtedCounts(c) represents the number of
        %> of loadshapes found at centroid 'c'.  
        %> @retval sortedIndices Cx1 vector.  sortedIndices(c) is the
        %> centroid index with loadshape count of sortedCounts(c) at index c.
        %> It can be used to map the popularity of the original order of the loadShapeMap to the index of its position in sorted order.
        % ======================================================================
        function [sortedCounts, sortedIndices] = calculateAndSortDistribution(loadShapeMap)
            centroidCounts = histc(loadShapeMap,1:max(loadShapeMap));
            [sortedCounts,sortedIndices] = sort(centroidCounts,'ascend');
            % sortedIndexToCentroidIndex = sortedIndices;
            %   index of most popular centroid is
            %               sortedIndexToCentroidIndex(end)
            % index of least popular centroid is
            %               sortedIndexToCentroidIndex(1)
            % sortedCounts == centroidCounts(sortedIndices)
            %             this.histogram = sortedCounts;
            %             this.centroidSortMap = sortedIndices;
        end
    end
    
    methods(Static)
        
        % ======================================================================
        %> @param loadShapes NxM matrix to  be clustered (Each row represents an M dimensional value).
        %> @param settings  Optional struct with following fields [and
        %> default values]
        %> - @c minClusters [40]  Used to set initial K
        %> - @c maxClusters [0.5*N]
        %> - @c thresholdScale [1.5]        
        %> @param Boolean
        %> @param Boolean Set randomizer seed to default
        %> - @c true Use 'default' for randomizer (rng)
        %> - @c false (default) Do not update randomizer seed (rng).
        %> - @c true Display calinski index at each adaptive k-means iteration (slower)
        %> - @c false (default) Do not calcuate Calinzki index.
        %> @retval idx = Rx1 vector of cluster indices that the matching (i.e. same) row of the loadShapes is assigned to.
        %> @retval centroids - KxC matrix of cluster centroids.
        %> @retval The Calinski index for the returned idx and centroids
        %> @retrval Struct of X and Y fields containing the progression of
        %> cluster sizes and corresponding Calinksi indices obtained for
        %> each iteration of k means.
        % ======================================================================
        function [idx, centroids, performanceIndex, performanceProgression] = adaptiveKmeans(loadShapes,settings,defaultRandomizer,performanceAxesH,textStatusH)
            performanceIndex = [];
            X = [];
            Y = [];
            idx = [];
            %             centroids = [];
            
            % argument checking and validation ....
            if(nargin<5)
                textStatusH = -1;
                if(nargin<4)
                    performanceAxesH = -1;
                    if(nargin<3)
                        defaultRandomizer = false;
                        if(nargin<2)
                            settings.minClusters = 40;
                            settings.maxClusters = size(loadShapes,1)/2;
                            settings.thresholdScale = 5; %higher threshold equates to fewer clusters.
                        end
                    end
                end
            end
            
            if(defaultRandomizer)
                rng('default');  % To get same results from run to run...
            end            
            
            if(ishandle(textStatusH) && ~(strcmpi(get(textStatusH,'type'),'uicontrol') && strcmpi(get(textStatusH,'style'),'text')))
                fprintf(1,'Input graphic handle is of type %s, but ''text'' type is required.  Status measure will be output to the console window.',get(textStatusH,'type'));
                textStatusH = -1;
            end    
            
            
            if(ishandle(performanceAxesH) && ~strcmpi(get(performanceAxesH,'type'),'axes'))
                fprintf(1,'Input graphic handle is of type %s, but ''axes'' type is required.  Performance measures will not be shown.',get(performanceAxesH,'type'));
                performanceAxesH = -1;
            end    
            
            
            
            % Make sure we have an axes handle.
            if(ishandle(performanceAxesH))
                %performanceAxesH = axes('parent',calinskiFig,'box','on');
                %calinskiLine = line('xdata',nan,'ydata',nan,'parent',performanceAxesH,'linestyle','none','marker','o');
                xlabel(performanceAxesH,'K');
                ylabel(performanceAxesH,'Calinksi Index');                
            end
            
            K = settings.minClusters;
            
            N = size(loadShapes,1);
            % prime the kmeans algorithms starting centroids
            centroids = loadShapes(pa_randperm(N,K),:);
            % prime loop condition since we don't have a do while ...
            numNotCloseEnough = settings.minClusters;
            firstLoop = true;
            while(numNotCloseEnough>0 && K<=settings.maxClusters)
                if(~firstLoop)
                    if(numNotCloseEnough==1)
                        statusStr = sprintf('1 cluster was not close enough.  Setting desired number of clusters to %u.',numNotCloseEnough,K);                        
                    else
                        statusStr = sprintf('%u clusters were not close enough.  Setting desired number of clusters to %u.',numNotCloseEnough,K);                        
                    end
                    fprintf(1,'%s\n',statusStr);                    
                    if(ishandle(textStatusH))
                        curString = get(textStatusH,'string');                        
                        set(textStatusH,'string',[curString(end-1:end);statusStr]);
                    end

                else
                    statusStr = sprintf('Initializing desired number of clusters to %u.',K);
                    fprintf(1,'%s\n',statusStr);
                    if(ishandle(textStatusH))
                        curString = get(textStatusH,'string');
                        set(textStatusH,'string',[curString(end);statusStr]);
                    end

                    firstLoop = false;
                end
                
                tic
                %     IDX = kmeans(X,K) returns an N-by-1 vector IDX containing the cluster
                %     indices of each point -> the loadshapeMap
                %
                %     [IDX, C] = kmeans(X, K) returns the K cluster centroid locations in
                %     the K-by-P matrix C.
                %
                %     [IDX, C, SUMD] = kmeans(X, K) returns the within-cluster sums of
                %     point-to-centroid distances in the 1-by-K vector sumD.
                %
                %     [IDX, C, SUMD, D] = kmeans(X, K) returns distances from each point
                %     to every centroid in the N-by-K matrix D.
                [idx, centroids, sumD, pointToClusterDistances] = kmeans(loadShapes,K,'Start',centroids,'EmptyAction','drop');
                
                %    [~, centroids, sumOfPointToCentroidDistances] = kmeans(loadShapes,K,'EmptyAction','drop');
                if(ishandle(performanceAxesH))
                    performanceIndex  = PACentroid.getCalinskiHarabaszIndex(idx,centroids,sumD);
                    X(end+1)= K;
                    Y(end+1)=performanceIndex;
                    PACentroid.plot(performanceAxesH,X,Y);
                    
                    statusStr = sprintf('Calisnki index = %0.2f for K = %u clusters',performanceIndex,K);
                    
                    fprintf(1,'%s\n',statusStr);
                    if(ishandle(textStatusH))
                        
                        curString = get(textStatusH,'string');
                        set(textStatusH,'string',[curString(end-1:end);statusStr]);
                    end
                    
                    drawnow();
                    %plot(calinskiAxes,'xdata',X,'ydata',Y);
                    %set(calinskiLine,'xdata',X,'ydata',Y);
                    %set(calinkiAxes,'xlim',[min(X)-5,
                    %max(X)]+5,[min(Y)-10,max(Y)+10]);
                end
            
                
                removed = sum(isnan(centroids),2)>0;
                numRemoved = sum(removed);
                if(numRemoved>0)
                    statusStr = sprintf('%u clusters were dropped during this iteration.',numRemoved);
                    fprintf(1,'%s\n',statusStr);
                    if(ishandle(textStatusH))
                        curString = get(textStatusH,'string');
                        set(textStatusH,'string',[curString(end);statusStr]);
                    end

                    centroids(removed,:)=[];
                    K = K-numRemoved;
                    [idx, centroids, sumD, pointToClusterDistances] = kmeans(loadShapes,K,'Start',centroids,'EmptyAction','drop','onlinephase','off');
                                        
                    if(ishandle(performanceAxesH))
                        performanceIndex  = PACentroid.getCalinskiHarabaszIndex(idx,centroids,sumD);
                        X(end+1)= K;
                        Y(end+1)=performanceIndex;
                        PACentroid.plot(performanceAxesH,X,Y);
                        
                        statusStr = sprintf('Calisnki index = %0.2f for K = %u clusters',performanceIndex,K);

                        fprintf(1,'%s\n',statusStr);
                        if(ishandle(textStatusH))
                            curString = get(textStatusH,'string');
                            set(textStatusH,'string',[curString(end);statusStr]);
                        end

                        drawnow();
                        
                        %set(calinskiLine,'xdata',X,'ydata',Y);
                        %set(calinkiAxes,'xlim',[min(X)-5,
                        %max(X)]+5,[min(Y)-10,max(Y)+10]);
                    end                    
                end                
                
                toc
                
                point2centroidDistanceIndices = sub2ind(size(pointToClusterDistances),(1:N)',idx);
                distanceToCentroids = pointToClusterDistances(point2centroidDistanceIndices);
                sqEuclideanCentroids = (sum(centroids.^2,2));
                
                clusterThresholds = settings.thresholdScale*sqEuclideanCentroids;
                notCloseEnoughPoints = distanceToCentroids>clusterThresholds(idx);
                notCloseEnoughClusters = unique(idx(notCloseEnoughPoints));
                
                numNotCloseEnough = numel(notCloseEnoughClusters);
                if(numNotCloseEnough>0)
                    centroids(notCloseEnoughClusters,:)=[];
                    for k=1:numNotCloseEnough
                        curClusterIndex = notCloseEnoughClusters(k);
                        clusteredLoadShapes = loadShapes(idx==curClusterIndex,:);
                        numClusteredLoadShapes = size(clusteredLoadShapes,1);
                        if(numClusteredLoadShapes>1)
                            try
                                [~,splitCentroids] = kmeans(clusteredLoadShapes,2,'EmptyAction','drop');
                                
                            catch me
                                showME(me);
                            end
                            centroids = [centroids;splitCentroids];
                        else
                            if(numClusteredLoadShapes~=1)
                                echo(numClusteredLoadShapes); %houston, we have a problem.
                            end
                            numNotCloseEnough = numNotCloseEnough-1;
                            centroids = [centroids;clusteredLoadShapes];
                        end
                        % for speed
                        %[~,centroids(curRow:curRow+1,:)] = kmeans(clusteredLoadShapes,2);
                        %curRow = curRow+2;
                    end
                    
                    % reset cluster centers now / batch update
                    K = K+numNotCloseEnough;
                    [~, centroids] = kmeans(loadShapes,K,'Start',centroids,'EmptyAction','drop','onlinephase','off');
                end
                
            end
            
            if(numNotCloseEnough~=0)
                statusStr = sprintf('Failed to converge using a maximum limit of %u clusters.',settings.maxClusters);
                fprintf(1,'%s\n',statusStr);
                if(ishandle(textStatusH))
                    curString = get(textStatusH,'string');
                    set(textStatusH,'string',{curString(end);statusStr});
                    drawnow();
                end

            else
                
                if(ishandle(performanceAxesH))
                    if(ishandle(performanceAxesH))
                        performanceIndex  = PACentroid.getCalinskiHarabaszIndex(idx,centroids,sumD);
                        X(end+1)= K;
                        Y(end+1)=performanceIndex;
                        PACentroid.plot(performanceAxesH,X,Y);
                        
                        statusStr = sprintf('Calisnki index = %0.2f for K = %u clusters',performanceIndex,K);

                        fprintf(1,'%s\n',statusStr);
                        if(ishandle(textStatusH))
                            curString = get(textStatusH,'string');
                            set(textStatusH,'string',[curString(end);statusStr]);
                        end

                        drawnow();
                        
                        %set(calinskiLine,'xdata',X,'ydata',Y);
                        %set(calinkiAxes,'xlim',[min(X)-5,
                        %max(X)]+5,[min(Y)-10,max(Y)+10]);
                    end
                end                                
                statusStr = sprintf('Converged with a cluster size of %u.  Calinski index = %0.2f  ',K,performanceIndex);
                fprintf(1,'%s\n',statusStr);
                if(ishandle(textStatusH))
                    curString = get(textStatusH,'string');
                    set(textStatusH,'string',[curString(end);statusStr]);                    
                end
            end             
            
            performanceProgression.X = X;
            performanceProgression.Y = Y;
            performanceProgression.statusStr = statusStr;
        end
        
        
                
        %> @brief Validation metric for cluster separation.   Useful in determining if clusters are well separated.  
        %> If clusters are not well separated, then the Adaptive K-means threshold should be adjusted according to the segmentation resolution desired.
        %> @note See Calinski, T., and J. Harabasz. "A dendrite method for cluster analysis." Communications in Statistics. Vol. 3, No. 1, 1974, pp. 1?27.
        %> @note See also http://www.mathworks.com/help/stats/clustering.evaluation.calinskiharabaszevaluation-class.html 
        %> @param Vector of output from mapping loadShapes to parent
        %> centroids.
        %> @param Centroids calculated via kmeans
        %> @param sum of euclidean distances
        %> @retval The Calinzki-Harabasz index
        function calinskiIndex = getCalinskiHarabaszIndex(loadShapeMap,centroids,sumD)
            [sortedCounts, sortedIndices] = PACentroid.calculateAndSortDistribution(loadShapeMap);
            sortedCentroids = centroids(sortedIndices,:);
            numObservations = numel(loadShapeMap);
            numCentroids = size(centroids,1);
            globalMeans = mean(sortedCentroids,1);
            
            ssWithin = sum(sumD,1);
            ssBetween = (pdist2(sortedCentroids,globalMeans)).^2;
            ssBetween = sortedCounts(:)'*ssBetween(:);  %inner product
            calinskiIndex = ssBetween/ssWithin*(numObservations-numCentroids)/(numCentroids-1);
        end
        
        function h=plot(performanceAxesH,X,Y)
            plotOptions = PACentroid.getPlotOptions();
            h=plot(performanceAxesH,X,Y,plotOptions{:});
            xlabel(performanceAxesH,'K');
            ylabel(performanceAxesH,'Calinksi Index');
        end       
        
        function plotOptions = getPlotOptions()
            plotOptions = {'linestyle',':','linewidth',1,'marker','*','markerfacecolor','k','markeredgecolor','k','markersize',8};
        end
    end
    
end

