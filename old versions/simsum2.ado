*! version 0.5 13jun2008 - works without by(); renamed simsum (was simoutwide)
* version 0.4 6jun2008 - modelse(mean) computes mean rather than RMSE; modelse_mcse corrected
* version 0.3 18feb2008 - clearer listing of funny obs; df() option
* version 0.2 19nov2007 - wide option, outsheet option, mcse option, if & in
prog def simsum2
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
    check formulae for prec1 and relerror
    change output() to specific options and only do computations needed 
    
*/

syntax anything [if] [in], true(string) [level(real $S_level) max(real 10) semax(real 100) graph format(string) pctformat(string) by(varlist) sepby(passthru) sep(passthru) nolist wide mcse outsheet(string) replace df(string) output(string) MODELSEmethod(string) FIRSTmethod(int 1) REFmethod(int 1)]
tokenize "`anything'"
local beta `1'
local sebeta `2'

if "`modelsemethod'"=="" local modelsemethod rmse

if "`by'"!="" {
    local byby by(`by')
    local byvar `by'
}
else {
    tempvar byvar
    gen `byvar'=0
}

marksample touse

tempvar truevar
qui gen `truevar' = `true'
qui count if missing(`truevar')
if r(N)>0 {
    di as error "Missing values found for true value `true'"
    exit 498
}

local i `firstmethod'
local stop 0
while !`stop' {
    cap confirm var `beta'_`i'
    if !_rc {
        confirm var `sebeta'_`i'
        local ++i
    }
    else local stop 1
}
local m=`i'-1
if `m'==0 {
    di as error "Variable `beta'_1 not found"
    exit 498
}

* LIST FUNNY OBS
tempvar missing
gen `missing' = 0
forvalues i=`firstmethod'/`m' {
    qui replace `missing' = 1 if missing(`beta'_`i')
    qui replace `missing' = 1 if missing(`sebeta'_`i')
}
qui count if `missing'==1
if "`list'"=="" & r(N)>0 {
    di as text _newline "Found observations with missing values:"
    l if `missing'
}

tempvar infinite
gen `infinite' = 0
forvalues i=`firstmethod'/`m' {
    qui replace `infinite' = 1 if abs(`beta'_`i')>`max' & !missing(`beta'_`i') 
    qui replace `infinite' = 1 if  `sebeta'_`i'>`semax' & !missing(`sebeta'_`i')
}
qui count if `infinite'==1
if "`list'"=="" & r(N)>0 {
    di as text _newline "Found observations with infinite values:"
    l if `infinite'
}

preserve
qui keep if `touse'
qui drop if `infinite'

if "`graph'"=="graph" {
    * DESCRIPTIVE GRAPH
    tempfile graph
    set graphics off
    forvalues i=`firstmethod'/`m' {
        cap gr7 `sebeta'_`i' `beta'_`i', xla yla saving(`graph'`i', replace) `byby'
        if !_rc local gphlist `gphlist' `graph'`i'
    }
    set graphics on
    gr7 using `gphlist', title(`sebeta' vs. `beta' by method)
}

* PROCESS RESULTS
forvalues i=`firstmethod'/`m' {
    local label`i' : var label `beta'_`i'
    local label`i' : subinstr local label`i' " method" ""
}

if `level'<1 local level=`level'*100
*** df may need to be df_`i'?
if "`df'"=="" local crit = -invnorm((1-`level'/100)/2)
else local crit = invttail(`df',(1-`level'/100)/2)
forvalues i=`firstmethod'/`m' {
    qui gen var_`i'=`sebeta'_`i'^2
    qui gen cover_`i' = 100*(abs(`beta'_`i'-`truevar')<`crit'*`sebeta'_`i') if !missing(`beta'_`i')     &   !missing(`sebeta'_`i') 
    qui gen power_`i' = 100*(abs(`beta'_`i')>=`crit'*`sebeta'_`i') if !missing(`beta'_`i') &        !missing(`sebeta'_`i') 
    qui gen bias_`i' = `beta'_`i' - `truevar'
    local collmean `collmean' bias_`i' varmean_`i'=var_`i' cover_`i' power_`i'  modelse_`i'=`sebeta'_`i'
    local collsd `collsd' empse_`i'=`beta'_`i' varsd_`i'=var_`i' modelsesd_`i'=`sebeta'_`i'
    local collcount `collcount' bsims_`i'=`beta'_`i' sesims_`i'=`sebeta'_`i'    bothsims_`i'=cover_`i'
    qui byvar `byvar', r(rho N) gen unique: corr `beta'_1 `beta'_`i'
    rename Rrho_ corr_`i'
    rename RN_ ncorr_`i'
    local corrlist `corrlist' corr_`i' ncorr_`i'
}
collapse (mean) `collmean' (sd) `collsd' (count) `collcount' (sum) `corrlist', by(`by')

forvalues i=`firstmethod'/`m' {
    qui gen bias_mcse_`i' = empse_`i' / sqrt(bsims_`i')
    qui gen empse_mcse_`i' = empse_`i'/sqrt(2*(bsims_`i'-1))
    if "`modelsemethod'"=="rmse" {
        qui replace modelse_`i' = sqrt(varmean_`i')
        gen modelse_mcse_`i' = varsd_`i' / sqrt(4 * sesims_`i' * varmean_`i') 
    }
    else if "`modelsemethod'"=="mean" {
        gen modelse_mcse_`i' = modelsesd_`i' / sqrt(sesims_`i')
    }
    qui gen relerror_`i' = 100*(modelse_`i'/empse_`i'-1)
    qui gen relerror_mcse_`i' = 100*(modelse_`i'/empse_`i') * sqrt(     (modelse_mcse_`i'/modelse_`i')^2    + (empse_mcse_`i'/empse_`i')^2 )
    qui gen cover_mcse_`i' = sqrt(cover_`i'*(100-cover_`i')/bothsims_`i')
    qui gen power_mcse_`i' = sqrt(power_`i'*(100-power_`i')/bothsims_`i') 
    qui gen prec1_`i' = 100 * ((empse_`refmethod'/empse_`i')^2-1)
    qui gen prec1_mcse_`i' = 200 * (empse_`refmethod'/empse_`i')^2 * sqrt((1-corr_`i'^2)/ncorr_`i')
    drop varmean_`i' varsd_`i'
}
qui replace prec1_`refmethod' = .
qui replace prec1_mcse_`refmethod' = .

if "`format'"=="" local format %6.3f
if "`pctformat'"=="" local pctformat %6.1f
format bias* empse* modelse* `format'
format prec1* cover* power* relerror* `pctformat'
    
* Wide output
local alpha=100-`level'
local bsimsname Non-missing values of `beta'
local sesimsname Non-missing values of `sebeta'
local biasname Bias in point estimate `beta'
local empsename Empirical standard error of `beta'
local prec1name % gain in precision relative to method `label`refmethod''
if "`modelsemethod'" =="mean" local modelsename Mean model-based standard error `sebeta'
if "`modelsemethod'" =="rmse" local modelsename RMS model-based standard error `sebeta'
local relerrorname Relative % error in `sebeta'
local covername Coverage of nominal `level'% confidence interval
local powername Power of `alpha'% level test
if "`output'"=="" local output bsims sesims bias empse prec1 modelse relerror cover power
foreach name in `output' {
    local domcse = "`mcse'"=="mcse" & "`name'"!="bsims" & "`name'"!="sesims" 
    forvalues i=`firstmethod'/`m' {
        char `name'_`i'[varname] "`label`i''"
        local `name'list ``name'list' `name'_`i'
        if `domcse' {
            char `name'_mcse_`i'[varname] "`label`i''"
            local `name'_mcselist ``name'_mcselist' `name'_mcse_`i'
        }
    }
    di _newline(3) as text "``name'name'"
    l `by' ``name'list', noo subvarname `sepby' `sep'
    if `domcse' {
        di _newline(1) as text "... Monte Carlo error"
        l `by' ``name'_mcselist', noo subvarname `sepby' `sep'
    }
    if "`outsheet'"!="" {
        local `name'list
        forvalues i=`firstmethod'/`m' {
            local newname = subinstr("`label`i''"," ","",.)
            rename `name'_`i' `newname'
            local `name'list ``name'list' `newname'
            if `domcse' {
                rename `name'_mcse_`i' `newname'_mcse
                local `name'list ``name'list' `newname'_mcse
            }
        }
        outsheet `by' ``name'list' using `outsheet'_`name'.csv, `replace' comma
        drop ``name'list'
    }
}

end

