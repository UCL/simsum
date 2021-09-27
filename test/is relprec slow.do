/* 
how much slower is relprec than other measures?
settings below show it to be 10 times slower
other settings show it not so bad
IRW 27sep2021
*/

* SETTINGS

local allpms bsims sesims bias mean empse relprec mse rmse modelse ciwidth relerror cover power   
local reps 10

// local data misim
// local cmd simsum b, se(se) methodvar(method) id(dataset) by(rep) true(0.5) format(%7.0g) 

local data C:\ado\ian\simsum\test\bvsim1_results.dta
local cmd simsum beta*, id(_dnum) true(truebeta) seprefix(se) by(n truebeta rep)

* RUN

scalar drop _all
use "`data'", clear
gen id = _n
expand `reps'
sort id
by id: gen rep = _n
foreach pm of local allpms {
	time `pm': `cmd' `pm'
}
scalar dir