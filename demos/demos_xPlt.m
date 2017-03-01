%% Run simulation - Sparse Pyramidal-Interneuron-Network-Gamma (sPING)
% Get ready...

demos_path = findDemosPath;
cd(demos_path)

% Set path to your copy of the DynaSim toolbox
dynasim_path = fullfile(demos_path, '..');

% add DynaSim toolbox to Matlab path
addpath(genpath(dynasim_path)); % comment this out if already in path

% Set where to save outputs
output_directory = fullfile(demos_path, 'outputs');

% define equations of cell model (same for E and I populations)
eqns={ 
  'dv/dt=Iapp+@current+noise*randn(1,N_pop)';
  'monitor iGABAa.functions, iAMPA.functions'
};
% Tip: monitor all functions of a mechanism using: monitor MECHANISM.functions

% create DynaSim specification structure
s=[];
s.populations(1).name='E';
s.populations(1).size=80;
s.populations(1).equations=eqns;
s.populations(1).mechanism_list={'iNa','iK'};
s.populations(1).parameters={'Iapp',5,'gNa',120,'gK',36,'noise',40};
s.populations(2).name='I';
s.populations(2).size=20;
s.populations(2).equations=eqns;
s.populations(2).mechanism_list={'iNa','iK'};
s.populations(2).parameters={'Iapp',0,'gNa',120,'gK',36,'noise',40};
s.connections(1).direction='I->E';
s.connections(1).mechanism_list={'iGABAa'};
s.connections(1).parameters={'tauD',10,'gSYN',.1,'netcon','ones(N_pre,N_post)'};
s.connections(2).direction='E->I';
s.connections(2).mechanism_list={'iAMPA'};
s.connections(2).parameters={'tauD',2,'gSYN',.1,'netcon',ones(80,20)};

% Vary two parameters (run a simulation for all combinations of values)
vary={
  'E'   ,'Iapp',[0 10 20];      % amplitude of tonic input to E-cells
  'I->E','tauD',[5 10 15]       % inhibition decay time constant from I to E
  };
SimulateModel(s,'save_data_flag',1,'study_dir',fullfile(output_directory, 'demo_sPING_3b'),...
                'vary',vary,'verbose_flag',1, ...
                'save_results_flag',1,'plot_functions',@PlotData,'plot_options',{'format','png'} );

%% Load the data and import into nDDict class
demos_path = findDemosPath;
cd(demos_path)

% ...Assumes we have some DynaSim data already loaded...
data=ImportData(fullfile('outputs', 'demo_sPING_3b'));

% Load the data linearly
[data_linear,ax,ax_names,time] = DynaSimExtract(data);
  % data_linear: row cell array with cols = num_sims * num_labels. i.e. 1 col
  %   for each time series recorded over all sims
  %     looping over (outer to inner): sims, pops, vars
  % ax: row cell array with num cols = length(ax_names). each cell contains
  %   row vector or cell array array with length = length(data_linear). Gives
  %   the parameters associated with each col of data_linear.
  % ax_names: row cell array with string contents describing the parameter that
  %   each col of ax represents.
  % time: col vector of time points from simulation

% Import into an xPlt class
xp = xPlt;
xp = xp.importLinearData(data_linear,ax{:});
xp = xp.importAxisNames(ax_names);
meta = struct;
meta.datainfo(1:2) = nDDictAxis;      % Use nDDictAxis here, because why not?
meta.datainfo(1).name = 'time(ms)';
meta.datainfo(1).values = time;
meta.datainfo(2).name = 'cells';
meta.datainfo(2).values = [];
xp = xp.importMeta(meta);


%% Run another recursive plot
clear xp2 xp3
xp4 = xp.subset([],[],1,8);
xp4.getaxisinfo

% recursivePlot(xp4,{@xp_subplot,@xp_subplot,@xp_matrix_basicplot},{1:2,3},{{[],1},{1,1},{}});
% recursivePlot(xp4,{@xp_subplot_grid3D,@xp_subplot,@xp_matrix_basicplot},{1:2,3},{{},{0,1},{}});
% recursivePlot(xp4,{@xp_subplot_grid3D,@xp_matrix_basicplot},{[3,1,2]},{{},{}});
recursivePlot_2(xp4,{@xp_subplot,@xp_matrix_basicplot},{[1,2]},{{0,0},{}});

recursivePlot(xp4,{@xp_subplot,@xp_matrix_basicplot},{[1,2]},{{0,0},{}});



%% Run another recursive plot
clear xp2 xp3
xp4 = xp.subset([],[],[],8);
xp4.getaxisinfo

% recursivePlot(xp4,{@xp_subplot,@xp_subplot,@xp_matrix_basicplot},{1:2,3},{{[],1},{1,1},{}});
% recursivePlot(xp4,{@xp_subplot_grid3D,@xp_subplot,@xp_matrix_basicplot},{1:2,3},{{},{0,1},{}});
% recursivePlot(xp4,{@xp_subplot_grid3D,@xp_matrix_basicplot},{[3,1,2]},{{},{}});
recursivePlot(xp4,{@xp_subplot_grid3D,@xp_matrix_basicplot},{[3,1,2]},{{},{}});




%% Run another recursive plot
clear xp2 xp3
xp4 = xp.subset([],[],1,[]);
xp4 = xp4.squeeze;
xp4.getaxisinfo

% recursivePlot(xp4,{@xp_subplot,@xp_subplot,@xp_matrix_basicplot},{1:2,3},{{[],1},{1,1},{}});
% recursivePlot(xp4,{@xp_subplot_grid3D,@xp_subplot,@xp_matrix_basicplot},{1:2,3},{{},{0,1},{}});
% recursivePlot(xp4,{@xp_subplot_grid3D,@xp_matrix_basicplot},{[3,1,2]},{{},{}});
recursivePlot(xp4,{@xp_subplot_grid3D,@xp_matrix_basicplot},{[3,1,2]},{{},{}});



%% Run a recursive plot

clear xp2 xp3
xp4 = xp.subset([],[],[],8);
xp4.getaxisinfo

% recursivePlot(xp4,{@xp_subplot,@xp_subplot,@xp_matrix_basicplot},{1:2,3},{{[],1},{1,1},{}});
% recursivePlot(xp4,{@xp_subplot_grid3D,@xp_subplot,@xp_matrix_basicplot},{1:2,3},{{},{0,1},{}});
% recursivePlot(xp4,{@xp_subplot_grid3D,@xp_matrix_basicplot},{[3,1,2]},{{},{}});
recursivePlot(xp4,{@xp_subplot_grid3D,@xp_subplot_grid3D,@xp_matrix_basicplot},{[1,2,4],3},{{},{0,1},{}});



%% Test subset selection using regular expressions
xp5 = xp.subset([],[],[1],'iNa*');
xp5.getaxisinfo

xp5 = xp.subset([],[],[1],'_s');
xp5.getaxisinfo

%% Test packDims
clear xp2 xp3 xp4 xp5
% xp2 = xp.subset(2,2,[],[1,3,5:8]);      % Selection based on index locations
xp2 = xp.subset(2,2,[],'(v|^i||ISYN$)');  % Same thing as above using regular expression. Selects everything except the _s terms. "^" - beginning with; "$" - ending with
xp2 = xp2.squeeze;
xp2.getaxisinfo;
src = 2;
dest = 3;
xp2 = xp2.packDim(src,dest);
xp2.getaxisinfo;

%% Average over membrane voltages
% Analogous to cell2mat

xp2 = xp;
xp2 = xp.subset([],[],[],'v');  % Same thing as above using regular expression. Selects everything except the _s terms. "^" - beginning with; "$" - ending with
xp2 = xp2.squeeze;
%
% Average across all cells
xp2.data = cellfun(@(x) mean(x,2), xp2.data,'UniformOutput',0);

% Pack E and I cells together
src=3;
dest=2;
xp3 = xp2.packDim(src,dest);


% Plot 
recursivePlot(xp3,{@xp_subplot_grid3D,@xp_matrix_basicplot},{[1,2]},{{},{}});


%% Average over synaptic currents
% Analogous to cell2mat
warning('Hadley Wickham');

xp2 = xp.subset([],[],[],'(ISYN$)');  % Same thing as above using regular expression. Selects everything except the _s terms. "^" - beginning with; "$" - ending with
xp2.getaxisinfo;

xp3 = xp2.packDim(4,3);
xp3 = xp3.squeeze;
xp3.getaxisinfo;

% Average across membrane currents
xp3.data = cellfun(@(x) nanmean(x,3), xp3.data,'UniformOutput',0);

% Plot 
recursivePlot(xp3,{@xp_subplot_grid3D,@xp_matrix_basicplot},{[3,1,2]},{{},{}});

%% Test mergeDims
% Analogous to Reshape
xp2 = xp.mergeDims([3,4]);
xp2.getaxisinfo;

%% Convert to Jason's format
% Analogous to Reshape
xp2 = xp.mergeDims([1,2]);
xp2 = xp2.mergeDims([3,4]);
xp2.getaxisinfo;



%% Load nDDict structure of images

cd outputs
file = 'demo_sPING_3b';
data = ImportPlots(file);
cd ..

[data_linear,ax,ax_names] = DynaSimPlotExtract (data);

xp = nDDict;
xp = xp.importLinearData(data_linear,ax{:});
xp = xp.importAxisNames(ax_names);


recursivePlot(xp,{@xp_subplot_grid3D,@xp_plotimage},{[1,2]},{{},{.25}});



%% To implement
% 
% 
% Implement the following:
% 1. Example of averaging across cells
% 2. Example of averaging synaptic currents (e.g. LFP estimate)
% 3. Plotting - plots with embedded images
% 4. Plotting - load images directly from DynaSim 
% 5. Starting work on PlotData2 - any new requests?
