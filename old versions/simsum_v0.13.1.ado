*! version 0.13.1 26may2010 - in wide format, unlabelled variables are listed by their name, not numbered; seprefix abbreviation lengthened to sepr() to avoid confusion with sep() - but what does the latter do?
* version 0.13 8mar2010 - new listsep and listsepformat(bfmt pctfmt) options gives narrower & better formatted output; missing b <=> missing se; zero se changed to missing; better listing of problem observations
* version 0.12 4mar2010 - much clearer error message if -byvar- not installed
* version 0.11 23dec2009 - robust option; temporary byvar dropped from saving() file; keep before reshape means extra variables don't cause crash; ref(label) for long format; dflist() dropped; long() renamed methodvar(); only keeps variables that are needed (may leave problems if it crashes with clear option)
* version 0.10 7sep2009 - df() updated to df(var) dflist(varlist) dfprefix(string) dfsuffix(string)
* version 0.9 4sep2009 - renamed selist() as se()
* version 0.8 12feb2009 - corrected error in resetting big values to missing; new nomemcheck option
* version 0.7 8dec2009 - NEW SYNTAX simsum betalist, selist() [long(methodvar)]
* version 0.6 13nov2008 - new options firstmethod() and refmethod() 
* version 0.5 13jun2008 - works without by(); renamed simsum (was simoutwide)
* version 0.4  6jun2008 - modelse(mean) computes mean rather than RMSE; modelse_mcse corrected
* version 0.3 18feb2008 - clearer listing of funny obs; df() option
* version 0.2 19nov2007 - wide option, outsheet option, mcse option, if & in
prog def simsum
version 9

/*
To do list:
	improve output format?
		(a) if m=1, output statistics as columns?
		(b) if no by-variable, output statistics as rows?
		(c) single table, so that column widths match
*/

syntax varlist [if] [in], ///
	[true(string) METHodvar(varname) id(varlist)                             /// main options
	SEPRefix(string) SESuffix(string) se(varlist)                            /// SE options
	graph noMEMcheck max(real 10) semax(real 100) dropbig nolistbig listmiss /// data checking options
	level(real $S_level) by(varlist) mcse robust ref(string)                 /// calculation options
	df(string) DFPrefix(string) DFSuffix(string) MODELSEMethod(string)       /// calculation options
	bsims sesims bias empse relprec modelse relerror cover power             /// statistic options
	sepby(varlist) SEParate(passthru) clear saving(string)                        /// output options
	nolist listsep listsepformat(string) format(string) gen(string)                                /// output options
																			 /// undocumented options
	]

// CHECK OPTIONS 

if "`modelsemethod'"=="" local modelsemethod rmse
if "`modelsemethod'"!="rmse" & "`modelsemethod'"!="mean" {
	di as error "Syntax: modelsemethod(rmse|mean)"
	exit 498
}

* SORT OUT BY
if "`by'"!="" {
	local byby by(`by')
	local byvar `by'
}
else {
	tempvar byvar
	gen `byvar'=0
}

* COUNT AND STORE BETA'S 
local i 0
foreach beta of varlist `varlist' {
	local ++i
	local beta`i' `beta'
	local betalist `betalist' `beta'
}
local m `i'

* SORT OUT SE'S
if "`seprefix'"!="" | "`sesuffix'"!="" {
	if "`se'"!="" {
		di as error "Can't specify se() with seprefix() or sesuffix()"
		exit 498
	}
	forvalues i=1/`m' {
		local se`i' `seprefix'`beta`i''`sesuffix'
		confirm var `se`i''
		local selist `selist' `se`i''
	}
}
else if "`se'"!="" {
	local i 0
	foreach sevar of varlist `se' {
		local ++i
		local se`i' `sevar'
		local selist `selist' `se`i''
	}
	if `i'<`m' {
		di as error "Fewer variables in se(`se') than in `betalist'"
		exit 498
	}
	if `i'>`m' {
		di as error "More variables in se(`se') than in `betalist'"
		exit 498
	}
}
else { // just working with beta's
	if "`sesims'`relprec'`modelse'`relerror'`cover'`power'"!="" {
		di as error "Can't compute `sesims' `relprec' `modelse' `relerror' `cover' `power' without standard errors"
		exit 498
	}
}   

* SORT OUT DF'S
if "`dfprefix'"!="" | "`dfsuffix'"!="" {
	if "`df'"!="" {
		di as error "Can't specify df() with dfprefix() or dfsuffix()"
		exit 498
	}
	forvalues i=1/`m' {
		local df`i' `dfprefix'`beta`i''`dfsuffix'
		confirm var `df`i''
		local dflist `dflist' `df`i''
	}
}
else if "`df'"!="" {
	cap confirm number `df'
	if !_rc local dftype number
	else {
		cap assert `df'==`df'
		if !_rc local dftype varname
		else {
			cap confirm var `df'
			if !_rc local dftype varlist
			else local dftype error
		}
	}
	if inlist("`dftype'","number","varname") {
		forvalues i=1/`m' {
			local df`i' `df'
		}
		if "`dftype'"=="varname" local dflist `df'
	}
	else if "`dftype'"=="varlist" {
		local i 0
		foreach dfvar of varlist `df' {
			local ++i
			local df`i' `dfvar'
			local dflist `dflist' `dfvar'
		}
		if `i'!=`m' local dftype error
	}
	if "`dftype'"=="error" {
		di as error "df must contain number, string or varlist of same length as estimates"
		exit 498
	}

}

* IF NO STATISTICS SPECIFIED, USE ALL AVAILABLE 
if "`bsims'`sesims'`bias'`empse'`relprec'`modelse'`relerror'`cover'`power'"=="" {
	foreach stat in bsims bias empse relprec {
		local `stat' `stat'
	}
	if "`se1'"!="" {
		foreach stat in sesims modelse relerror cover power {
			local `stat' `stat'
		}
	}
	if "`true'"=="" {
		di as text "true() not specified: can't calculate bias and coverage"
		local bias
		local cover
	}
}
local output `bsims' `sesims' `bias' `empse' `relprec' `modelse' `relerror' `cover' `power'
if "`bias'`empse'`relprec'`modelse'`relerror'`cover'`power'"=="" & "`mcse'"=="mcse" {
	di as error "Only bsims and/or sesims specified - mcse ignored"
	local mcse
}

if "`methodvar'"!="" {
	if `m'>1 {
		di as error "Only one estimate variable allowed with long format"
		exit 498
	}
	if "`id'"=="" {
		di as error "id() is required with long format"
		exit 498
	}
}

if "`list'"=="nolist" & "`clear'"=="" & "`saving'"=="" {
	di as error "No output requested! Please specify clear or saving(), or don't specify nolist"
	exit 498
}

if "`gen'"=="" local gen stat
cap confirm new variable `gen'num
local rc1=_rc
cap confirm new variable `gen'code
if _rc | `rc1' {
	di as error as smcl "{p}Variable `gen'num and/or `gen'code already exists. This is probably because the current data are -simsum- output. If this is what you want, use the gen() option.{p_end}"
	exit 498
}   

if "`memcheck'"!="nomemcheck" {
	qui desc, short
	if r(width)/r(widthmax)>0.45 {
		di as error "simsum is memory-hungry and can fail slowly if memory is more than 50% occupied."
		di as error as smcl "Please increase the memory using {help memory:set memory}, or use the nomemcheck option."
		exit 498
	}
}

// SET UP
marksample touse, novarlist

* check true is specified if bias or cover chosen
if "`bias'"=="bias" | "`cover'"=="cover" {
	if "`true'"=="" {
		di as error "true() must be specified when bias and/or cover is requested"
		exit 498
	}
	tempvar truevar
	qui gen `truevar' = `true'
	qui count if missing(`truevar') & `touse'
	if r(N)>0 {
		di as error "Missing values found for true value `true'"
		exit 498
	}
}

// START CALCULATION
preserve
qui keep if `touse'

// CONVERT FROM LONG FORMAT IF NECESSARY, EXTRACT METHOD LABELS AND FIND REFERENCE METHOD
if "`methodvar'"!="" {
	* DATA ARE LONG, CONVERTING TO WIDE
	qui levelsof `methodvar', local(methods)
	local label : val label `methodvar'
	local i 0
	foreach method in `methods' {
		local ++i
		local beta`i' `betalist'`method'
		local se`i'   `selist'`method'
		local newbetalist `newbetalist' `betalist'`method'
		local newselist   `newselist'   `selist'`method'
		if "`dftype'"=="number" local df`i' `df'
		if "`dftype'"=="varname" local df`i' `dflist'`method'
		if "`label'"!="" local label`i' : label `label' `method'
		else local label`i' "`method'"
		if "`label`i''"=="`ref'" local refmethod `i'
	}
	local m `i'
	if "`refmethod'"=="" {
		if "`ref'"!="" {
			if "`label'"!="" local labelled "labelled "
			di as error "ref(`ref') is not one of the `labelled'values of `methodvar'"
			exit 498
		}
		else local refmethod 1
	}
	di as text "Reshaping data to wide format ..."
	keep `betalist' `selist' `dflist' `by' `byvar' `id' `methodvar' `touse' `truevar'
	cap confirm string var `methodvar'
	if _rc==0 local string string
	qui reshape wide `betalist' `selist' `dflist', i(`by' `id') j(`methodvar') `string'
	local betalist `newbetalist'
	local selist `newselist'
}
else { // DATA ARE ALREADY WIDE
	forvalues i=1/`m' {
		local label`i' : var label `beta`i''
		if "`label`i''"=="" local label`i' "`beta`i''" /* corrected, v0.13.1 */
		if "`beta`i''"=="`ref'" local refmethod `i'
	}
	if "`refmethod'"=="" {
		if "`ref'"!="" {
			di as error "ref(`ref') is not one of the listed point estimates"
			exit 498
		}
		else local refmethod 1
	}
	keep `betalist' `selist' `dflist' `by' `byvar' `id' `touse' `truevar' 
}

// LIST MISSING/PROBLEM OBS
tempvar missing
gen `missing' = 0
forvalues i=1/`m' {
	qui replace `missing' = missing(`beta`i'') & `touse'
	if "`se`i''"!="" qui replace `missing' = 1 if missing(`se`i'') & `touse'
	if "`se`i''"!="" qui replace `missing' = 1 if `se`i''==0 & `touse'
	qui count if `missing'
	if r(N)>0 {
		if "`se`i''"!="" {
			qui replace `missing' = missing(`beta`i'') & missing(`se`i'') & `touse'
			qui count if `missing'
			if r(N)>0 {
				di as text _new "Warning: found " as result r(N) as text " observations with both `beta`i'' and `se`i'' missing" _c
				if "`listmiss'"=="listmiss" list `by' `id' `beta`i'' `se`i'' if `missing', sepby(`sepby')
				di as text "--> no action taken"
			}

			qui replace `missing' = !missing(`se`i'') & missing(`beta`i'') & `touse'
			qui count if `missing'
			if r(N)>0 {
				di as text _new "Warning: found " as result r(N) as text " observed values of `se`i'' with missing `beta`i''" _c
				if "`listmiss'"=="listmiss" list `by' `id' `beta`i'' `se`i'' if `missing', sepby(`sepby')
				qui replace `se`i'' = . if `missing'
				di as text "--> `se`i'' changed to missing"
			}

			qui replace `missing' = missing(`se`i'') & !missing(`beta`i'') & `touse'
			qui count if `missing'
			if r(N)>0 {
				di as text _new "Warning: found " as result r(N) as text " observed values of `beta`i'' with missing `se`i''" _c
				if "`listmiss'"=="listmiss" list `by' `id' `beta`i'' `se`i'' if `missing', sepby(`sepby')
				qui replace `beta`i'' = . if `missing'
				di as text "--> `beta`i'' changed to missing"
			}

			qui replace `missing' = (`se`i''==0) & `touse'
			qui count if `missing'
			if r(N)>0 {
				di as text _new "Warning: found " as result r(N) as text " zero values of `se`i''" _c
				if "`listmiss'"=="listmiss" list `by' `id' `beta`i'' `se`i'' if `missing', sepby(`sepby')
				qui replace `beta`i'' = . if `missing'
				qui replace `se`i'' = . if `missing'
				di as text "--> `beta`i'' and `se`i'' have been changed to missing values for these observations"
			}
		}
	}
}
drop `missing'

// CHECK FOR TOO-BIG OBS & OPTIONALLY LIST / DROP THEM
tempvar infb infse
gen `infb' = 0
gen `infse' = 0
local errorbig 0
forvalues i=1/`m' {
	qui summ `beta`i''
	qui replace `infb' = (abs(`beta`i''-r(mean))/r(sd) > `max') & !missing(`beta`i'')  
	if "`se`i''"!="" {
		qui summ `se`i''
		qui replace `infse' = (`se`i''/r(mean) > `semax') & !missing(`se`i'') 
	}
	qui count if `infb'
	local ninfb = r(N)
	qui count if `infse'
	local ninfse = r(N)
	if `ninfb'+`ninfse' > 0 {
		di as text _newline `"Warning: found "' as result `ninfb' as text `" observations with standardised `beta`i'' > `max'"' _c
		if "`se`i''"!="" di as text `" and "' as result `ninfse' as text `" observations with scaled `se`i'' > `semax'"' _c
		if "`listbig'"!="nolistbig" l `by' `id' `beta`i'' `se`i'' if `infb'|`infse', sepby(`sepby')
		if "`dropbig'"=="dropbig" {
			qui replace `beta`i'' = . if `infb'|`infse'
			if "`se`i''"!="" qui replace `se`i'' = . if `infb'|`infse'
			di as text `"--> `beta`i'' "' _c
			if "`se`i''"!="" di as text `"and `se`i'' "' _c
			di as text `"have been changed to missing values for these observations"'
		}
		else local errorbig 1
	}
}
if `errorbig' {
	di as error "Use dropbig option to drop these observations"
	if "`listbig'"=="nolistbig" di as error "Remove nolistbig option to list these observations"
	di as error "Use max() option to change acceptable limit of point estimates"
	if "`se'"!="" di as error "Use semax() option to change acceptable limit of standard errors"
	exit 498
}

// OPTIONAL DESCRIPTIVE GRAPH
if "`graph'"=="graph" {
	tempfile graph
	set graphics off
	forvalues i=1/`m' {
		cap gr7 `se`i'' `beta`i'', xla yla b2title("`beta`i''") l1title("`se`i''") t1title("`label`i''") saving(`graph'`i', replace) /*`byby'*/
		if !_rc local gphlist `gphlist' `graph'`i'
	}
	set graphics on
	gr7 using `gphlist', title(Std error vs. point estimate by method)
}

// PROCESS RESULTS
di as text _newline "Starting to process results ..."
if `level'<1 local level=`level'*100
if "`robust'"=="robust" & ("`relprec'"=="relprec" | "`relprec'"=="relprec" | "`relerror'"=="relerror") {
	forvalues i=1/`m' {
		tempvar betamean`i'
		egen `betamean`i'' = mean(`beta`i''), `byby'        
	}
}
forvalues i=1/`m' {
	if "`df`i''"!="" local crit`i' invttail(`df`i'',(1-`level'/100)/2)
	else             local crit`i' = -invnorm((1-`level'/100)/2)
	if "`dftype'"=="number" local crit`i' = `crit`i'' // for speed
	local collcount `collcount' bsims_`i'=`beta`i''
	if "`bias'"=="bias" {
		qui gen bias_`i' = `beta`i'' - `truevar'
		local collmean `collmean' bias_`i' 
	}
	if "`relerror'"=="relerror" | "`modelse'"=="modelse" {
		qui gen var_`i'=`se`i''^2
	}
	if "`empse'"=="empse" | "`relerror'"=="relerror" | "`relprec'"=="relprec" | "`bias'"=="bias" {
		local collsd `collsd' empse_`i'=`beta`i''
	}
	if "`relprec'"=="relprec" & `i'!=`refmethod' {
		cap byvar `byvar', r(rho N) gen unique: corr `beta`refmethod'' `beta`i''
		if _rc==199 {
			di as error "Sorry, simsum's relprec option requires you to have installed byvar"
			di as error "Please use {stata ssc install byvar}"
			exit 199
		}
		rename Rrho_ corr_`i'
		rename RN_ ncorr_`i'
		local collsum `collsum' corr_`i' ncorr_`i'
	}
	if "`modelse'"=="modelse" | "`relerror'"=="relerror" | "`sesims'"=="sesims" {
		local collcount `collcount' sesims_`i'=`se`i'' 
	}
	if "`modelse'"=="modelse" | "`relerror'"=="relerror" {
		local collmean `collmean' modelse_`i'=`se`i''
		local collmean `collmean' varmean_`i'=var_`i'
		local collsd `collsd' varsd_`i'=var_`i' 
		local collsd `collsd' modelsesd_`i'=`se`i''
	}
	if "`cover'"=="cover" | "`power'"=="power" {
		if "`cover'"=="cover" local collcount `collcount' bothsims_`i'=cover_`i'
		else local collcount `collcount' bothsims_`i'=power_`i'
	}
	if "`cover'"=="cover" {
		qui gen cover_`i' = 100*(abs(`beta`i''-`truevar')<(`crit`i'')*`se`i'') if !missing(`beta`i'') &   !missing(`se`i'') 
		local collmean `collmean' cover_`i' 
	}
	if "`power'"=="power" {
		qui gen power_`i' = 100*(abs(`beta`i'')>=(`crit`i'')*`se`i'') if !missing(`beta`i'') & !missing(`se`i'') 
		local collmean `collmean' power_`i' 
	}
	if "`robust'"=="robust" {
		if "`empse'"=="empse" {
			tempvar empseT`i' empseB`i' empseTT`i' empseBB`i' empseTB`i' 
			qui gen `empseT`i'' = (`beta`i''-`betamean`i'')^2
			qui gen `empseB`i'' = 1
			qui gen `empseTT`i'' = `empseT`i''^2
			qui gen `empseBB`i'' = `empseB`i''^2
			qui gen `empseTB`i'' = `empseT`i''*`empseB`i''
			local collsum `collsum' `empseT`i'' `empseB`i'' `empseTT`i'' `empseTB`i'' `empseBB`i''
		}
		if "`relprec'"=="relprec" {
			tempvar relprecT`i' relprecB`i' relprecTT`i' relprecBB`i' relprecTB`i' 
			qui gen `relprecT`i'' = (`beta`refmethod''-`betamean`refmethod'')^2
			qui gen `relprecB`i'' = (`beta`i''-`betamean`i'')^2
			qui gen `relprecTT`i'' = `relprecT`i''^2
			qui gen `relprecBB`i'' = `relprecB`i''^2
			qui gen `relprecTB`i'' = `relprecT`i''*`relprecB`i''
			local collsum `collsum' `relprecT`i'' `relprecB`i'' `relprecTT`i'' `relprecTB`i'' `relprecBB`i''
		}
		if "`relerror'"=="relerror" {
			tempvar relerrorT`i' relerrorB`i' relerrorTT`i' relerrorBB`i' relerrorTB`i' 
			qui gen `relerrorT`i'' = `se`i''^2
			qui gen `relerrorB`i'' = (`beta`i''-`betamean`i'')^2
			qui gen `relerrorTT`i'' = `relerrorT`i''^2
			qui gen `relerrorBB`i'' = `relerrorB`i''^2
			qui gen `relerrorTB`i'' = `relerrorT`i''*`relerrorB`i''
			local collsum `collsum' `relerrorT`i'' `relerrorB`i'' `relerrorTT`i'' `relerrorTB`i'' `relerrorBB`i''
		}
	}
}
if "`collmean'"!="" local collmean (mean) `collmean'
if "`collsd'"!="" local collsd (sd) `collsd'
if "`collcount'"!="" local collcount (count) `collcount'
if "`collsum'"!="" local collsum (sum) `collsum'
collapse `collmean' `collsd' `collcount' `collsum', by(`byvar')
forvalues i=1/`m' {
	qui gen k_`i' = bsims_`i'/(bsims_`i'-1)
	if "`bias'"=="bias" {
		qui gen bias_mcse_`i' = empse_`i' / sqrt(bsims_`i')
	}
	if ("`empse'"=="empse"  | "`relerror'"=="relerror") & "`robust'"=="" {
		qui gen empse_mcse_`i' = empse_`i'/sqrt(2*(bsims_`i'-1))
	}
	else if ("`empse'"=="empse") & "`robust'"=="robust" {
		qui replace `empseTT`i''=`empseTT`i''*(k_`i'^2)
		qui replace `empseTB`i''=`empseTB`i''*k_`i'
		qui replace `empseT`i'' =`empseT`i'' *k_`i'
		qui gen empse_mcse_`i' = sqrt(k_`i') * sqrt(`empseTT`i'' -2*(`empseT`i''/`empseB`i'')*`empseTB`i'' +(`empseT`i''/`empseB`i'')^2*`empseBB`i'') / `empseB`i''
		qui replace empse_mcse_`i' = empse_mcse_`i' / (2*empse_`i')
	}
	if "`relprec'"=="relprec" {
		if `i'!=`refmethod' {
			qui gen relprec_`i' = 100 * ((empse_`refmethod'/empse_`i')^2-1)
			if "`robust'"=="" {
				qui gen relprec_mcse_`i' = 200 * (empse_`refmethod'/empse_`i')^2 * sqrt((1-(corr_`i')^2)/(ncorr_`i'-2))
			}
			else {
				qui gen relprec_mcse_`i' = 100 * sqrt(`relprecTT`i'' -2*(`relprecT`i''/`relprecB`i'')*`relprecTB`i'' +(`relprecT`i''/`relprecB`i'')^2*`relprecBB`i'') / `relprecB`i''
			}
		}
		else {
			qui gen relprec_`i' = .
			qui gen relprec_mcse_`i' = .
		}
	}
	if "`modelse'"=="modelse" | "`relerror'"=="relerror" {
		if "`modelsemethod'"=="rmse" {
			qui replace modelse_`i' = sqrt(varmean_`i')
			qui gen modelse_mcse_`i' = varsd_`i' / sqrt(4 * sesims_`i' * varmean_`i') 
		}
		else if "`modelsemethod'"=="mean" {
			qui gen modelse_mcse_`i' = modelsesd_`i' / sqrt(sesims_`i')
		}
	}
	if "`relerror'"=="relerror" {
		qui gen relerror_`i' = 100*(modelse_`i'/empse_`i'-1)
		if "`robust'"=="" qui gen relerror_mcse_`i' = 100*(modelse_`i'/empse_`i') * sqrt((modelse_mcse_`i'/modelse_`i')^2 + (empse_mcse_`i'/empse_`i')^2 )
		else {
			qui gen relerror_mcse_`i' = sqrt(`relerrorTT`i'' -2*(`relerrorT`i''/`relerrorB`i'')*`relerrorTB`i'' +(`relerrorT`i''/`relerrorB`i'')^2*`relerrorBB`i'') / `relerrorB`i''
			qui replace relerror_mcse_`i' = relerror_mcse_`i' * 100 / (2*(1+relerror_`i'/100))
		}
	}
	if "`cover'"=="cover" {
		qui gen cover_mcse_`i' = sqrt(cover_`i'*(100-cover_`i')/bothsims_`i')
	}
	if "`power'"=="power" {
		qui gen power_mcse_`i' = sqrt(power_`i'*(100-power_`i')/bothsims_`i') 
	}
	cap drop varmean_`i' 
	cap drop varsd_`i'
}

// PREPARE FOR OUTPUT
local alpha=100-`level'
local bsimsname Non-missing point estimates
local sesimsname Non-missing standard errors
local biasname Bias in point estimate
local empsename Empirical standard error
local relprecname % gain in precision relative to method `label`refmethod''
if "`modelsemethod'" =="mean" local modelsename Mean model-based standard error `sebeta'
if "`modelsemethod'" =="rmse" local modelsename RMS model-based standard error `sebeta'
local relerrorname Relative % error in standard error
local covername Coverage of nominal `level'% confidence interval
local powername Power of `alpha'% level test

local keeplist `byvar'
foreach name in `output' {
	local domcse = "`mcse'"=="mcse" & "`name'"!="bsims" & "`name'"!="sesims"
	forvalues i=1/`m' {
		rename `name'_`i' method`i'`name'
		local keeplist `keeplist' method`i'`name'
		if `domcse' {
			rename `name'_mcse_`i' method`i'`name'_mcse
			local keeplist `keeplist' method`i'`name'_mcse
		}
	}
}
forvalues i=1/`m' {
	local methodlist `methodlist' method`i'
}
keep `keeplist'
qui reshape long `methodlist', i(`byvar') j(`gen'code) string
forvalues i=1/`m' {
	char method`i'[varname] "`label`i''"
	label var method`i' "`label`i''"
}
local i 0
qui gen mcse = .
qui gen `gen'num = .
foreach stat in bsims sesims bias empse relprec modelse relerror cover power {
	local ++i
	qui replace mcse=0 if `gen'code=="`stat'"
	qui replace mcse=1 if `gen'code=="`stat'_mcse"
	qui replace `gen'code="`stat'" if `gen'code=="`stat'_mcse"
	qui replace `gen'num = `i' if `gen'code=="`stat'" | `gen'code=="`stat'_mcse"
}
* label statistics
label def `gen'num  1 "Non-missing point estimates", add
label def `gen'num  2 "Non-missing standard errors", add
label def `gen'num  3 "Bias in point estimate", add
label def `gen'num  4 "Empirical standard error", add
label def `gen'num  5 "% gain in precision relative to method `label`refmethod''", add
if "`modelsemethod'" =="mean" label def `gen'num  6 "Mean model-based standard error", add
if "`modelsemethod'" =="rmse" label def `gen'num  6 "RMS model-based standard error", add
label def `gen'num  7 "Relative % error in standard error", add
label def `gen'num  8 "Coverage of nominal `level'% confidence interval", add
label def `gen'num  9 "Power of `alpha'% level test", add
label val `gen'num `gen'num 
assert !mi(mcse)
foreach var in `methodlist' {
	rename `var' `var'_
	local methodlist2 `methodlist2' `var'_
}
qui reshape wide `methodlist2', i(`byvar' `gen'num) j(mcse)
local ids `gen'num `by'
local betas
forvalues i=1/`m' {
	rename method`i'_0 `beta`i''
	label var `beta`i'' "`label`i''"
	char `beta`i''[varname] "`label`i''"
	local betas `betas' `beta`i''
	if "`mcse'"=="mcse" {
		rename method`i'_1 `beta`i''_mcse
		local betas `betas' `beta`i''_mcse
		label var `beta`i''_mcse "`label`i'' (MCse)"
		char `beta`i''_mcse[varname] "(MCse)"
	}
}
char `gen'num[varname] "Statistic"
label var `gen'num "Statistic"
label var `gen'code "Statistic code"
order `ids' `betas'
sort `gen'num `by'
if "`format'" != "" format `betas' `format'

// OUTPUT
if "`list'"!="nolist" {
	if "`listsepformat'"!="" local listsep listsep
	if "`listsep'"=="" list `ids' `betas', noo subvarname sepby(`gen'num `sepby')
	else {
		if "`listsepformat'"!="" {
			tokenize `listsepformat'
			local bfmt `1'
			local pctfmt `2'
			local nfmt `3'
			if "`pctfmt'"=="" local pctfmt `1'
			if "`nfmt'"=="" local nfmt %7.0f
		}
		foreach stat in `output' {
			di as text _new "``stat'name'"
			if inlist("`stat'","bsims","sesims") local format `nfmt'
			else if inlist("`stat'","bias","empse","modelse") local format `bfmt'
			else local format `pctfmt'
			qui format `format' `betas'
			list `by' `betas' if `gen'code=="`stat'", noo subvarname sepby(`gen'num `sepby')
			qui format `betas' `format'
		}
	}
}

// FINISH OFF
char `gen'num[varname] 
if "`saving'"!="" {
	if "`by'"=="" drop `byvar'
	save `saving'
}
if "`clear'"=="clear" {
	restore, not
	di as text "Results are now in memory."
}
end

