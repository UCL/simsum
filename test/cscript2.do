/* 
simsum certification script 2
revised for version 0.10
revised for version 0.11, 23dec09
revised for version 0.14, 9jun2010
revised for v0.15 (mse option), 13apr2011
moved to c:\ado\ian\simsum and file path removed, 2may2019
now in N:\Home\ado\ian\simsum\test, 6jan2020
add test of each PM by itself for v0.19, 8jan2020
now in c:\ian\git\simsum\test, 21jul2023
add test for missing byvar, 30aug2023
add test of logical relationships between mean, bias and pctbias, 19nov2023
*/

local path c:\ian\git\simsum
adopath + `path'/package
set logtype text
cap log close
log using `path'/test/cscript2, replace

// check it works even without personal adofiles!
prog drop _all
cap adopath -PERSONAL
cap adopath -OLDPLACE
cap adopath -PLUS

cscript "Detailed checks on simsum" adofile simsum
set linesize 158

which simsum
cap simsum
di r(simsum_version)

local opts graph nomemcheck max(20) semax(50) dropbig nolistbig ///
	listmiss level(99) mcse "robust mcse" df(5) df(dfvar) ///
	"saving(z,replace) nolist" "saving(z,replace) transpose" format(%8.2f) gen(new) ///
	listsep "listsep format(%8.3f %6.1f %6.0f)" abb(14)
local allopts graph nomemcheck max(20) semax(50) dropbig nolistbig ///
	listmiss level(99) mcse robust df(5) ///
	saving(z,replace) format(%8.2f) gen(new) listsep abb(14)
local allpms bsims sesims bias mean empse relprec mse rmse modelse ciwidth relerror cover power   

use bvsim1_results, clear
drop gamma* segam*
drop hazard-pmcar
drop beta_4-sebeta_9
drop if corr>0
drop corr
keep if truegamma==0
drop truegamma simno
summ

set trace off
set tracedepth 1
set more off

// Main syntax
simsum beta*, true(truebeta) seprefix(se) by(n truebeta) mcse 

// Ditto without se's
simsum beta*, true(truebeta) by(n truebeta) 

// CHECK SEPARATE OUTPUTS WORK
* not requiring truebeta
foreach stat in bsims sesims empse relprec modelse relerror power {
    simsum beta*, seprefix(se) by(n truebeta) `stat' 
    simsum beta*, seprefix(se) by(n truebeta) `stat' mcse
}
* requiring truebeta
foreach stat in bias mse cover {
    simsum beta*, true(truebeta) seprefix(se) by(n truebeta) `stat' 
    simsum beta*, true(truebeta) seprefix(se) by(n truebeta) `stat' mcse
}

// CHECK REF METHODS WORK
forvalues j=1/3 {
    simsum beta*, true(truebeta) seprefix(se) by(n truebeta) ref(beta_`j') relprec mcse
}

// CHECK MODELSEMETHOD()
foreach meth in rmse mean {
    simsum beta*, true(truebeta) seprefix(se) by(n truebeta) modelsemethod(`meth')
}

// CHECK ALL OPTIONS
gen dfvar=5
foreach opt in `opts' `"`allopts'"' {
	di as input _new(3) "*** Wide: simsum beta*, true(truebeta) seprefix(se) by(n truebeta) `opt' ***"
	simsum beta*, true(truebeta) seprefix(se) by(n truebeta) `opt'
}

// CHECK EACH PERFORMANCE MEASURE
foreach opt of local allpms {
	di as input _new(3) "*** Wide: simsum beta*, true(truebeta) seprefix(se) by(n truebeta) `opt' ***"
	simsum beta*, true(truebeta) seprefix(se) by(n truebeta) `opt'
}

// CHECK IT WORKS FROM LONG FORMAT
reshape long beta_ sebeta_, i(truebeta n _dnum) j(method)
reshape clear
label def method 1 "Perfect" 2 "CC" 3 "LogT"
label val method method
simsum beta, true(truebeta) seprefix(se) by(n truebeta) relprec relerror methodvar(method) id(_dnum)

foreach opt in `opts' `"`allopts'"' {
	di as input _new(3) "*** Long: simsum beta, true(truebeta) seprefix(se) by(n truebeta) method(method) id(_dnum) `opt' ***"
	simsum beta, true(truebeta) seprefix(se) by(n truebeta) method(method) id(_dnum) `opt'
}

// CHECK NULL(), PART 1
simsum beta*, true(truebeta) seprefix(se) by(n truebeta) saving(z1, replace)
simsum beta*, true(truebeta) seprefix(se) by(n truebeta) null(0) saving(z2, replace)
simsum beta*, true(truebeta) seprefix(se) by(n truebeta) null(.5) saving(z3, replace)

// CHECK CLEAR
simsum beta, true(truebeta) seprefix(se) by(n truebeta) method(method) id(_dnum) clear transpose

// CHECK NULL(), PART 2
use z1, clear
cap cf _all using z2
assert _rc==0
cap cf _all using z3
assert _rc==9
use z3, clear
drop perfmeasnum
reshape wide beta_, i(n truebeta) j( perfmeascode) string
assert reldif(beta_cover + beta_power, 100) < 1E-7 if truebeta==.5
assert reldif(beta_cover + beta_power, 100) > .1   if truebeta!=.5

// CHECK HANDLING OF A SINGLE REPETITION
use bvsim1_results, clear
keep if _dnum==1
cap noi simsum beta*, true(truebeta) seprefix(se) by(n truebeta truegamma corr) mcse
assert _rc==498

// CHECK MISSING BYVAR
use bvsim1_results, clear
drop gamma* segam*
drop hazard-pmcar
drop beta_4-sebeta_9
drop if corr>0
drop corr
keep if truegamma==0
drop truegamma simno
simsum beta*, true(truebeta) seprefix(se) by(n truebeta) mcse relprec saving(z4,replace)
replace n=. if n==84
simsum beta*, true(truebeta) seprefix(se) by(n truebeta) mcse relprec saving(z5,replace) 
use z4, clear
local beta_2_mcse = beta_2_mcse[1]
use z5, clear
assert beta_2_mcse == float(`beta_2_mcse') if n==.

// CHECK LOGICAL RELATIONSHIPS BETWEEN MEAN, BIAS AND PCTBIAS
use bvsim1_results, clear
drop gamma* segam*
drop hazard-pmcar
drop beta_4-sebeta_9
drop if corr>0
drop corr
keep if truegamma==0
drop truegamma simno
simsum beta*, true(truebeta) seprefix(se) by(n truebeta) mcse bias pctbias mean clear
drop perfmeasnum
reshape wide beta*, i(n truebeta) j(perf) string
forvalues i=1/3 {
	assert reldif(beta_`i'bias, beta_`i'mean - truebeta) < 1E-7
	assert reldif(beta_`i'pctbias, beta_`i'bias/truebeta*100) < 1E-7
	assert reldif(beta_`i'_mcsebias, beta_`i'_mcsemean) < 1E-7
	assert reldif(beta_`i'_mcsepctbias, beta_`i'_mcsebias/truebeta*100) < 1E-7
}


// END LOG FILE

di as result _n "****************************************" ///
	_n "*** SIMSUM HAS PASSED ALL ITS TESTS ***" ///
	_n "****************************************"

log close


// RESTORE ADOPATH & TIDY UP
clear
adopath +PERSONAL
adopath +PLUS
adopath +OLDPLACE
cap erase z.dta
forvalues i=1/5 {
	cap erase z`i'.dta
}
