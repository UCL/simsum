* simsum certification script 1
* moved to c:\ado\ian\simsum and file path removed, 2may2019
* NB see cscript2.do for fuller checks
* now in N:\Home\ado\ian\simsum\test, 6jan2020
* now in c:\ian\git\simsum\test, 21jul2023
* add test of new lci(), uci(), p() 14mar2024
* add test of just one of lci(), uci() 26mar2025

local path c:\ian\git\simsum
adopath + `path'/package
set logtype text
cap log close
cd `path'/test
set linesize 100
log using cscript1, replace

cscript "Simple checks on simsum" adofile simsum
set linesize 158

which simsum

// handling wide format
use check, clear
simsum b*, sep(se_) true(0)

// handling ref() in wide format
simsum b*, sep(se_) true(0) ref(b_2)

// handling mcse
simsum b*, sep(se_) true(0) mcse

// handling se
simsum b*, se(se*) true(0) mcse

// handling df
simsum b*, sep(se_) true(0) mcse df(5)
gen dfvar=5
simsum b*, sep(se_) true(0) mcse df(dfvar)

// handling awkward variables
gen bias_1=0
simsum b_*, sep(se_) true(0) 

// handling long format
use ppsim1, clear
keep i method b1 seb1
simsum b1, sep(se) method(method) id(i) true(1)  

// handling extra variables
use ppsim1, clear
simsum b1, sep(se) method(method) id(i) true(1)  

// handling ref() in long format
use ppsim1, clear
simsum b1, sep(se) method(method) id(i) true(1) ref(boot)

// handling df, lci and uci, including comparison of results 
use ppsim1, clear
simsum b1, sep(se) method(method) id(i) true(1) ref(boot) df(5) saving(z1a,replace)
gen df=5
simsum b1, sep(se) method(method) id(i) true(1) ref(boot) df(df) saving(z1b,replace)

simsum b1, sep(se) method(method) id(i) true(1) ref(boot) df(5) saving(z2a,replace) mean power

forvalues i=1/3 {
	gen mylcib`i' = b`i' - invt(5,.975)*seb`i'
	gen myucib`i' = b`i' + invt(5,.975)*seb`i'
	gen mypb`i' = abs(b`i'/seb`i') < invt(5,.975)
}
simsum b1, lciprefix(mylci) ucipre(myuci) method(method) id(i) true(1) ref(boot) saving(z2b,replace) mean power
simsum b1, pprefix(myp) method(method) id(i) true(1) ref(boot) saving(z2c,replace) mean power
simsum b1, lciprefix(mylci) ucipre(myuci) method(method) id(i) true(1) ref(boot) saving(z3a,replace) cover
simsum b1, ucipre(myuci) method(method) id(i) true(1) ref(boot) saving(z3b,replace) cover
simsum b1, lciprefix(mylci) method(method) id(i) true(1) ref(boot) saving(z3c,replace) cover
* same results with df(5) and df(df)?
use z1a, clear
cf _all using z1b
* same results for power with se, ci and p?
use z2a, clear
cf _all using z2b
cf _all using z2c
* corresponding results for cover with 1 or 2 tails?
use z3a, clear
append using z3b
append using z3c
for var b1*: assert 100-X[1]==100-X[2]+100-X[3] // type 2 errors should sum

foreach z in 1a 1b 2a 2b 2c 3a 3b 3c {
	erase z`z'.dta
}

log close

