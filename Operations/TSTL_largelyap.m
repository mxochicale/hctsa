function out = TSTL_largelyap(y,Nref,maxtstep,past,NNR,embedparams)
% Uses TSTOOL code largelyap
% Computes the largest Lyapunov exponent of a time-delay reconstructed time
% series s, using formula (1.5) in Parlitz Nonlinear Time Series Analysis
% book.
% Inputs:
% Nref: number of randomly-chosen reference points (-1==all)
% maxtstep: maximum prediction length (samples)
% past: exclude -- Theiler window idea
% NNR: number of nearest neighbours [opt]
% embedparams: input to benembed, how to time-delay-embed the time series
% Ben Fulcher November 2009

%% Preliminaries
N = length(y); % length of time series


% (1) Nref: number of randomly-chosen reference points
if nargin < 2 || isempty(Nref)
    Nref = 0.5; % use half the length of the time series
end
if Nref<1 && Nref>0
    Nref = round(N*Nref); % specify a proportion of time series length
end

% (2) maxtstep: maximum prediction length
if nargin < 3 || isempty(maxtstep)
    maxtstep = 0.1; % 10% length of time series
end
if maxtstep<1 && maxtstep>0
    maxtstep = round(N*maxtstep); % specify a proportion of time series length
end
if maxtstep<10;
    maxtstep=10; % minimum prediction length; for output stats purposes...
end
if maxtstep>0.5*N;
    maxtstep=0.5*N; % can't look further than half the time series length, methinks
end

% (3) past/theiler window
if nargin < 4 || isempty(past)
    past = 40;
end
if past<1 && past>0
    past = floor(past*N);
end

% (4) Number of neighest neighbours
if nargin < 5 || isempty(NNR)
    NNR=3;
end

% (5) Embedding parameters, embedparams
if nargin < 6 || isempty(embedparams)
    embedparams={'ac','cao'};
    disp('using default embedding using autocorrelation and cao')
else
    if length(embedparams)~=2
        disp('given embedding parameters incorrectly formatted -- need {tau,m}')
    end
end


%% Embed the signal
% convert to embedded signal object for TSTOOL
s = benembed(y,embedparams{1},embedparams{2},1);

if ~strcmp(class(s),'signal') && isnan(s); % embedding failed
    out = NaN;
    return
end

%% Run
try
    rs = largelyap(s,Nref,maxtstep,past,NNR);
catch
   disp('error evaluating largelyap')
   out = NaN;
   return
end
    
p = data(rs);
t = spacing(rs);
% plot(t,p,'.-k')

% we have the prediction error p as a function of the prediction length...?
% * function file says: output - vector of length taumax+1, x(tau) = 1/Nref *
%                                sum(log2(dist(reference point + tau, nearest neighbor +
%                                tau)/dist(reference point, nearest neighbor)))

%% Get output stats

if all(p==0)
    out=NaN; return
end

% p at lags up to 5
out.p1 = p(1);
out.p2 = p(2);
out.p3 = p(3);
out.p4 = p(4);
out.p5 = p(5);
out.maxp = max(p);
% number/proportion of crossings at 90%, 80% of maximum
out.ncross09max = sum((p(1:end-1)-0.9*max(p)).*(p(2:end)-0.9*max(p))<0);
out.ncross08max = sum((p(1:end-1)-0.8*max(p)).*(p(2:end)-0.8*max(p))<0);
out.pcross09max = sum((p(1:end-1)-0.9*max(p)).*(p(2:end)-0.9*max(p))<0)/(length(p)-1);
out.pcross08max = sum((p(1:end-1)-0.8*max(p)).*(p(2:end)-0.8*max(p))<0)/(length(p)-1);

% time taken to get to n% maximum
out.to095max = find(p>0.95*max(p),1,'first')-1;
if isempty(out.to095max), out.to095max = NaN; end
out.to09max = find(p>0.9*max(p),1,'first')-1;
if isempty(out.to09max), out.to09max = NaN; end
out.to08max = find(p>0.8*max(p),1,'first')-1;
if isempty(out.to08max), out.to08max = NaN; end
out.to07max = find(p>0.7*max(p),1,'first')-1;
if isempty(out.to07max), out.to07max = NaN; end
out.to05max = find(p>0.5*max(p),1,'first')-1;
if isempty(out.to05max), out.to05max = NaN; end


%% find scaling region:
% fit from zero to 95% of maximum...
imax = find(p>0.95*max(p),1,'first');

if imax<=3
    % not a suitable range for finding scaling
    % return NaNs for these
    out.vse_meanabsres = NaN;
    out.vse_rmsres = NaN;
    out.vse_gradient = NaN;
    out.vse_intercept = NaN;
    out.vse_minbad = NaN;
    
    out.ve_meanabsres = NaN;
    out.ve_rmsres = NaN;
    out.ve_gradient = NaN;
    out.ve_intercept = NaN;
    out.ve_minbad = NaN;
else
    t_scal = t(1:imax);
    p_scal = p(1:imax);
%     pp = polyfit(t_scal,p_scal',1); pfit = pp(1)*t_scal+pp(2);
    % hold on; plot(t_scal,p_scal,'.-r'); hold off
    % hold on; plot(t_scal,pfit,'-r'); hold off;
    % keyboard
    
    
    %% Adjust start and end times for best scaling
    
    l = imax; % = length(t_scal)
    stptr = 1:floor(l/2)-1; % start point must be in the first half (not necessarily, but for here)
    endptr = ceil(l/2)+1:l; % end point must be in second half (not necessarily, but for here)
    mybad = zeros(length(stptr),length(endptr));
    for i=1:length(stptr)
        for j=1:length(endptr)
            mybad(i,j) = lfitbadness(t_scal(stptr(i):endptr(j)),p_scal(stptr(i):endptr(j))');
        end
    end
    [a b] = find(mybad == min(min(mybad))); % this defines the 'best' scaling range
    
    % Do the optimum fit again
    t_opt = t_scal(stptr(a):endptr(b));
    p_opt = p_scal(stptr(a):endptr(b))';
    pp = polyfit(t_opt,p_opt,1);
    pfit = pp(1)*t_opt+pp(2);
    res = pfit - p_opt;
    
    % hold on; plot(t_opt,p_opt,'og'); hold off;
    % hold on; plot(t_opt,pfit,'-g'); hold off;
    % vse == vary start and end times
    out.vse_meanabsres = mean(abs(res));
    out.vse_rmsres = sqrt(mean(res.^2));
    out.vse_gradient = pp(1);
    out.vse_intercept = pp(2);
    out.vse_minbad = min(mybad(:));
    if isempty(out.vse_minbad), out.vse_minbad = NaN; end
    
    %% Adjust just end time for best scaling
    imin = find(p>0.50*max(p),1,'first');
    
    endptr = imin:imax; % end point is at least at 50% mark of maximum
    mybad = zeros(length(endptr),1);
    for i = 1:length(endptr)
        mybad(i) = lfitbadness(t_scal(1:endptr(i)),p_scal(1:endptr(i))');
    end
    b = find(mybad == min(min(mybad))); % this defines the 'best' scaling range
    
    % Do the optimum fit again
    t_opt = t_scal(1:endptr(b));
    p_opt = p_scal(1:endptr(b))';
    pp = polyfit(t_opt,p_opt,1);
    pfit = pp(1)*t_opt+pp(2);
    res = pfit-p_opt;
    
    % hold on; plot(t_opt,p_opt,'om'); hold off;
    % hold on; plot(t_opt,pfit,'-m'); hold off;
    out.ve_meanabsres = mean(abs(res));
    out.ve_rmsres = sqrt(mean(res.^2));
    out.ve_gradient = pp(1);
    out.ve_intercept = pp(2);
    out.ve_minbad = min(mybad(:));
    if isempty(out.ve_minbad), out.ve_minbad = NaN; end
    
end
    
    

% fit exponential
s = fitoptions('Method','NonlinearLeastSquares','StartPoint',[max(p) -0.5]);
f = fittype('a*(1-exp(b*x))','options',s);
fitworked=1;
try
    [c, gof] = fit(t',p,f);
catch me
    if strcmp(me.message,'Inf computed by model function.')
        fitworked = 0;
    end
end
if fitworked
    out.expfit_a = c.a;
    out.expfit_b = c.b;
    out.expfit_r2=gof.rsquare;
    out.expfit_adjr2=gof.adjrsquare;
    out.expfit_rmse=gof.rmse;
else
    out.expfit_a = NaN;
    out.expfit_b = NaN;
    out.expfit_r2 = NaN;
    out.expfit_adjr2 = NaN;
    out.expfit_rmse = NaN;
end


% hold on; plot(t,c.a*(1-exp(c.b*t)),':r');hold off


    function badness = lfitbadness(x,y,gamma)
        if nargin < 3,
            gamma = 0.006; % CHOSEN AD HOC!! (maybe it's nicer to say 'empirically'...)
        end
        pp = polyfit(x,y,1);
        pfit = pp(1)*x+pp(2);
        res = pfit-y;
        badness = mean(abs(res))-gamma*length(x); % want to still maximize length(x)
    end


end