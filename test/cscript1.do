* simsum certification script 1
* moved to c:\ado\ian\simsum and file path removed, 2may2019
* NB see cscript2.do for fuller checks
* now in N:\Home\ado\ian\simsum\test, 6jan2020
* now in c:\ian\git\simsum\test, 21jul2023
* add test of new lci(), uci(), p() 14mar2024

local path c:\ian\git\simsum
adopath + `path'/package
set logtype text
cap log close
cd `path'/test
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

// handling df, lci and uci
use ppsim1, clear
simsum b1, sep(se) method(method) id(i) true(1) ref(boot) df(5)
gen df=5
simsum b1, sep(se) method(method) id(i) true(1) ref(boot) df(df)
forvalues i=1/3 {
	gen mylcib`i' = b`i' - invt(5,.975)*seb`i'
	gen myucib`i' = b`i' + invt(5,.975)*seb`i'
	gen mypb`i' = abs(b`i'/seb`i') < invt(5,.975)
}
simsum b1, lciprefix(mylci) ucipre(myuci) method(method) id(i) true(1) ref(boot) 
simsum b1, pprefix(myp) method(method) id(i) true(1) ref(boot) 

log close

