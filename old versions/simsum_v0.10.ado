*! version 0.10 7sep2009 - df() updated to df(var) dflist(varlist) dfprefix(string) dfsuffix(string)
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
Simple example: data set contains 
        simno      - identifies simulation settings
        true       - true parameter value in this setting
        X_1 X_se_1 - estimated parameter and its standard error using method 1
        X_2 X_se_2 - estimated parameter and its standard error using method 2
then simply run:
    simout X X_se, true(true) by(simno)

Queries: is df option right?
To do:
    check formulae for relprec and relerror
    improve output format 
        (a) if m=1, output statistics as columns?
        (b) if no by-variable, output statistcs as rows?
        (c) single table, so that column widths match
*/

syntax varlist [if] [in], ///
    [true(string) long(varname) id(varlist)                                  /// main options
    SEPrefix(string) SESuffix(string) se(varlist)                            /// SE options
    graph noMEMcheck max(real 10) semax(real 100) dropbig nolistbig listmiss /// data checking options
    level(real $S_level) by(varlist) mcse                                    /// calculation options
    df(string) DFList(varlist) DFPrefix(string) DFSuffix(string) MODELSEMethod(string) ref(varname)                            /// calculation options
    bsims sesims bias empse relprec modelse relerror cover power             /// statistic options
    sepby(varlist) sep(passthru) clear saving(string)                        /// output options
    nolist format(string) gen(string)                                        /// output options
    oldout                                                                   /// undocumented options
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
    if "`beta'"=="`ref'" local refmethod `i'
    local betalist `betalist' `beta'
}
local m `i'
if "`refmethod'"=="" {
    if "`ref'"!="" {
        di as error "ref(`ref') is not one of the listed point estimates"
        exit 498
    }
    else local refmethod 1
}

* SORT OUT SE'S
if "`seprefix'"!="" | "`sesuffix'"!="" {
    if "`se'"!="" {
        di as error "Can't specify se() with seprefix() or sesuffix()"
        exit 498
    }
    forvalues i=1/`m' {
        local se`i' `seprefix'`beta`i''`sesuffix'
        local se `se`i'' /* for reshape? */
    }
}
else if "`se'"!="" {
    local i 0
    foreach sevar of varlist `se' {
        local ++i
        local se`i' `sevar'
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
    if "`df'"!="" | "`dflist'"!=""{
        di as error "Can't specify df() or dflist() with dfprefix() or dfsuffix()"
        exit 498
    }
    forvalues i=1/`m' {
        local df`i' `dfprefix'`beta`i''`dfsuffix'
        local df `df`i'' /* for reshape? */
    }
}
else if "`dflist'"!="" {
    local i 0
    foreach dfvar of varlist `dflist' {
        local ++i
        local df`i' `dfvar'
    }
    if `i'<`m' {
        di as error "Fewer variables in dflist(`df') than in `betalist'"
        exit 498
    }
    if `i'>`m' {
        di as error "More variables in dflist(`df') than in `betalist'"
        exit 498
    }
    local df `df`m''
}
else if "`df'"!="" {
    forvalues i=1/`m' {
        local df`i' `df'
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
}
local output `bsims' `sesims' `bias' `empse' `relprec' `modelse' `relerror' `cover' `power'
if "`bias'`empse'`relprec'`modelse'`relerror'`cover'`power'"=="" & "`mcse'"=="mcse" {
    di as error "Only bsims and/or sesims specified - mcse ignored"
    local mcse
}

if "`long'"!="" {
    if `m'>1 {
        di as error "Only one estimate variable allowed with long format"
        exit 498
    }
    if "`id'"=="" {
        di as error "id() is required with long format"
        exit 498
    }
}

if "`list'"=="nolist" & "`clear'"=="" {
    di as error "No output requested! Please specify clear or don't specify nolist"
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
if "`clear'"=="" preserve
qui keep if `touse'

// CONVERT FROM LONG FORMAT IF NECESSARY, AND EXTRACT METHOD LABELS
if "`long'"!="" {
    qui levelsof `long', local(methods)
    local label : val label `long'
    local i 0
    cap confirm var `df'
    if _rc & "`df'"!="" {
        local dfval `df'
        tempname df
        gen `df' = `dfval'
    }
    foreach method in `methods' {
        local ++i
        local beta`i' `betalist'`method'
        local se`i' `se'`method'
        if "`df'"!="" local df`i' `df'`method'
        if "`label'"!="" local label`i' : label `label' `method'
        else local label`i' "`method'"
    }
    local m `i'
    di as text "Reshaping data to wide format ..."
    cap confirm string var `long'
    if _rc==0 local string string
    qui reshape wide `betalist' `se' `df', i(`by' `id') j(`long') `string'
}
else forvalues i=1/`m' {
    local label`i' : var label `beta`i''
    if "`label`i''"=="" local label`i' "`i'"
}

// LIST MISSING OBS
tempvar missing
gen `missing' = 0
forvalues i=1/`m' {
    qui replace `missing' = 1 if missing(`beta`i'') & `touse'
    if "`se'"!="" qui replace `missing' = 1 if missing(`se`i'') & `touse'
}
qui count if `missing'
if r(N)>0 {
    di as text _newline "Warning: found " as result r(N) as text " observations with missing values"
    if "`listmiss'"=="listmiss" l if `missing'
}

// CHECK FOR TOO-BIG OBS & OPTIONALLY LIST / DROP THEM
tempvar infb infse
gen `infb' = 0
gen `infse' = 0
forvalues i=1/`m' {
    qui summ `beta`i''
    qui replace `infb' = (abs(`beta`i''-r(mean))/r(sd) > `max') & !missing(`beta`i'')  
    if "`se'"!="" {
        qui summ `se`i''
        qui replace `infse' = (`se`i''/r(mean) > `semax') & !missing(`se`i'') 
    }
    qui count if `infb'
    local ninfb = r(N)
    qui count if `infse'
    local ninfse = r(N)
    if `ninfb'+`ninfse' > 0 {
        di as text _newline `"Warning: found "' as result `ninfb' as text `" observations with standardised `beta`i'' >`max'"' 
        if "`se'"!="" di as text `"               "' as result `ninfse' as text `" observations with scaled `se`i'' >`semax'"'
        if "`listbig'"!="nolistbig" l `by' `id' `beta`i'' `se`i'' if `infb'|`infse'
        if "`dropbig'"!="dropbig" {
            di as error "Use dropbig option to drop these observations"
            if "`listbig'"!="nolistbig" di as error "Use listbig option to list these observations"
            di as error "Use max() option to change acceptable limit of point estimates"
            if "`se'"!="" di as error "Use semax() option to change acceptable limit of standard errors"
            exit 498
        }
        qui replace `beta`i'' = . if `infb'
        if "`se'"!="" qui replace `se`i'' = . if `infse'
        di as text _newline `"These observations have been changed to missing values."'
    }
}

// OPTIONAL DESCRIPTIVE GRAPH
if "`graph'"=="graph" {
    tempfile graph
    set graphics off
    forvalues i=1/`m' {
        cap gr7 `se`i'' `beta`i'', xla yla saving(`graph'`i', replace) /*`byby'*/
        if !_rc local gphlist `gphlist' `graph'`i'
    }
    set graphics on
    gr7 using `gphlist', title(`sebeta' vs. `beta' by method)
}

// PROCESS RESULTS
di as text "Starting to process results ..."
if `level'<1 local level=`level'*100
forvalues i=1/`m' {
    if "`df`i''"!="" local crit`i' invttail(`df`i'',(1-`level'/100)/2)
    else             local crit`i' -invnorm((1-`level'/100)/2)
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
        rename Rrho_ corr_`i'
        rename RN_ ncorr_`i'
        local corrlist `corrlist' corr_`i' ncorr_`i'
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
}
if "`collmean'"!="" local collmean (mean) `collmean'
if "`collsd'"!="" local collsd (sd) `collsd'
if "`collcount'"!="" local collcount (count) `collcount'
if "`corrlist'"!="" local corrlist (sum) `corrlist'
collapse `collmean' `collsd' `collcount' `corrlist', by(`byvar')
forvalues i=1/`m' {
    if "`bias'"=="bias" {
        qui gen bias_mcse_`i' = empse_`i' / sqrt(bsims_`i')
    }
    if "`empse'"=="empse"  | "`relerror'"=="relerror" {
        qui gen empse_mcse_`i' = empse_`i'/sqrt(2*(bsims_`i'-1))
    }
    if "`relprec'"=="relprec" {
        if `i'!=`refmethod' {
            qui gen relprec_`i' = 100 * ((empse_`refmethod'/empse_`i')^2-1)
            qui gen relprec_mcse_`i' = 200 * (empse_`refmethod'/empse_`i')^2 * sqrt((1-(corr_`i')^2)/(ncorr_`i'-2))
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
        qui gen relerror_mcse_`i' = 100*(modelse_`i'/empse_`i') * sqrt((modelse_mcse_`i'/modelse_`i')^2 + (empse_mcse_`i'/empse_`i')^2 )
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

// OUTPUT
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
if "`list'"!="nolist" list `ids' `betas', noo subvarname sepby(`gen'num `sepby')
char `gen'num[varname] 


if "`saving'"!="" {
    save `saving'
}
if "`clear'"=="clear" di as text "Results are now in memory."
end

