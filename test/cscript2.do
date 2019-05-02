* simsum certification script 2
* revised for version 0.10
* revised for version 0.11, 23dec09
* revised for version 0.14, 9jun2010
* revised for v0.15 (mse option), 13apr2011
* moved to c:\ado\ian\simsum and file path removed, 2may2019

cscript "Detailed checks on simsum" adofile simsum

// check it works even without personal adofiles!
pda
cap simsum
adopath -PERSONAL
adopath -OLDPLACE
adopath -PLUS

local opts graph nomemcheck max(20) semax(50) dropbig nolistbig ///
	listmiss level(99) mcse "robust mcse" df(5) df(dfvar) ///
	"saving(z,replace) nolist" "saving(z,replace) transpose" format(%8.2f) gen(new) ///
	listsep "listsep format(%8.3f %6.1f %6.0f)" abb(14)
local allopts graph nomemcheck max(20) semax(50) dropbig nolistbig ///
	listmiss level(99) mcse robust df(5) ///
	saving(z,replace) format(%8.2f) gen(new) listsep abb(14)
	
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

// CHECK CLEAR
simsum beta, true(truebeta) seprefix(se) by(n truebeta) method(method) id(_dnum) clear transpose

// RESTORE ADOPATH
clear
adopath +PERSONAL
adopath +PLUS
adopath +OLDPLACE
erase z.dta
