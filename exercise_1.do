cd .
use "data/exercise_1.dta", clear


**missing values**
mvdecode _all, mv(9 99 999 9999 99999999 999999999)
replace tchid1 = "." if tchid1 == "99999999"
replace tchid2 = "." if tchid2 == "999999999"
replace tchid3 = "." if tchid3 == "999999999"
replace tchidk = "." if tchidk == "99999999"

//Question 1a
**Gen lunchdummy**
gen lunchdummy = .
replace lunchdummy = 1 if sesk == 1
replace lunchdummy = 0 if sesk == 2
**Race dummy**
gen whiteasiandummy = .
replace whiteasiandummy = 1 if inlist(race, 1, 3)
replace whiteasiandummy = 0 if inlist(race, 2, 4, 5, 6)
**Age variable**
gen agein85 = .
replace agein85 = 1985 - yob if yob < .
**Test scores**
gen scorek = .
replace scorek = (mathk + readk) / 2 
gen score1 = .
replace score1 = (math1 + read1) / 2 
gen score2 = .
replace score2 = (math2 + read2) / 2 
gen score3 = .
replace score3 = (math3 + read3) / 2 
**Output summary stats.**
estpost summarize lunchdummy whiteasiandummy agein85 scorek score1 score2 score3
esttab using summary_stats.doc, replace ///
    cells("mean(fmt(3)) sd(fmt(3)) count") ///
    label


//Q1 b
**1=small, 2=regular, 3=regular with aid**
**mean by class type**
label var lunchdummy "Free Lunch"
label var whiteasiandummy "White/Asian"
label var agein85 "Age in 1985"
label var scorek "Average Score (Kindergarten)"
label var score1 "Average Score (Grade 1)"
label var score2 "Average Score (Grade 2)"
label var score3 "Average Score (Grade 3)"

* Clear the old file to make idempotent
capture erase "tables/Table1.doc"

* Add labels for the table
label var lunchdummy "Free Lunch"
label var whiteasiandummy "White/Asian"
label var agein85 "Age in 1985"

local vars lunchdummy whiteasiandummy agein85 score`g' csize`g'

* 1. Set the file path
local outfile "Table1_Final.tex"
capture erase "`outfile'"
shell mkdir -p output/question_1

* The Loop
foreach g in k 1 2 3 {
    
    est sto clear
    
    * Define the variables for THIS specific grade loop
    local current_vars lunchdummy whiteasiandummy agein85 score`g' csize`g'

    * 1. Store the means for the three columns
    foreach t in 1 2 3 {
        quietly estpost summarize `current_vars' if ctype`g' == `t'
        est store grp`t'
    }

    * 2. Calculate Joint P-Values using regressions
    * We store these in a matrix or locals to add to the table
    foreach v of local current_vars {
        quietly reg `v' i.ctype`g'
        quietly testparm i.ctype`g'
        local pval = string(r(p), "%9.3f")
        
        * We have to "stow" the p-value into the stored estimate
        * We'll attach it to grp3 so it appears as a trailing column/stat
        estadd local jointp_`v' = "`pval'" : grp3
    }

* 3. Export/Display to Log
    * Removed booktabs and added plain/compress for console readability
    esttab grp1 grp2 grp3 using "output/question_1/Table1.txt", ///
            cells("mean(fmt(3))") ///
            stats(jointp_lunchdummy jointp_whiteasiandummy jointp_agein85 jointp_score`g' jointp_csize`g', ///
                labels("P-val: Lunch" "P-val: Race" "P-val: Age" "P-val: Score" "P-val: Size")) ///
            title("Panel: Grade `g'") ///
            mtitles("Small" "Regular" "Regular+Aide") ///
            label nodepvars nonumber ///
            varwidth(40) modelwidth(15) ///
            append plain
}
