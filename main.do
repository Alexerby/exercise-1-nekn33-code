cd .
use "data/exercise_1.dta", clear

// ******************************************************************************
// EXERCISE 1: Data Cleaning and Variable Generation
// ******************************************************************************

** Recode missing values as specified in instructions
mvdecode _all, mv(9 99 999 9999 99999999 999999999)
replace tchid1 = "." if tchid1 == "99999999"
replace tchid2 = "." if tchid2 == "999999999"
replace tchid3 = "." if tchid3 == "999999999"
replace tchidk = "." if tchidk == "99999999"

// Question 1a: Create variables for each grade 
foreach g in k 1 2 3 {
    ** 1. Create lunch dummy variables
    gen lunchdummy`g' = .
    replace lunchdummy`g' = 1 if ses`g' == 1
    replace lunchdummy`g' = 0 if ses`g' == 2
    label var lunchdummy`g' "Free Lunch Grade `g'"
    
    ** 2. Average test scores per grade 
    gen score`g' = (math`g' + read`g') / 2 
    label var score`g' "Average Score Grade `g'"
    
    ** 3. GENERATE TREATMENT DUMMIES (Fixed the r(111) error)
    * ctype: 1=small, 2=regular, 3=regular with aid
    gen small_`g' = (ctype`g' == 1) if !missing(ctype`g')
    gen regaide_`g' = (ctype`g' == 3) if !missing(ctype`g')
    
    label var small_`g' "Small Class Dummy Grade `g'"
    label var regaide_`g' "Regular w/ Aide Dummy Grade `g'"
}

** 4. Race dummy (White/Asian vs. others) 
gen whiteasiandummy = .
replace whiteasiandummy = 1 if inlist(race, 1, 3)
replace whiteasiandummy = 0 if inlist(race, 2, 4, 5, 6)
label var whiteasiandummy "White/Asian"

** 5. Age in 1985 
gen agein85 = 1985 - yob
label var agein85 "Age in 1985"

** Output summary stats for the full sample
estpost summarize lunchdummyk lunchdummy1 lunchdummy2 lunchdummy3 whiteasiandummy agein85 scorek score1 score2 score3
esttab using output/question_1/descriptive_stats.doc, replace cells("mean(fmt(3)) sd(fmt(3)) count") label


// ******************************************************************************
// Q1 b: Summary Statistics by Treatment Status 
// ******************************************************************************

capture erase "output/question_1/Table1.doc"
shell mkdir -p output/question_1
shell mkdir -p output/question_2
shell mkdir -p output/question_3

foreach g in k 1 2 3 {
    est sto clear
    
    * Define covariates for this grade loop
    local current_vars lunchdummy`g' whiteasiandummy agein85 score`g' csize`g'

    * 1. Store means by treatment status
    foreach t in 1 2 3 {
        quietly estpost summarize `current_vars' if ctype`g' == `t'
        est store grp`t'
    }

    * 2. Calculate Joint P-Values (Randomization check)
    foreach v of local current_vars {
        quietly reg `v' i.ctype`g'
        quietly testparm i.ctype`g'
        local pval = string(r(p), "%9.3f")
        estadd local jointp_`v' = "`pval'" : grp3
    }

    * 3. Export Grade Panel
    esttab grp1 grp2 grp3 using "output/question_1/Table1.doc", ///
            cells("mean(fmt(3))") ///
            stats(jointp_lunchdummy`g' jointp_whiteasiandummy jointp_agein85 jointp_score`g' jointp_csize`g', ///
                labels("P-val: Lunch" "P-val: Race" "P-val: Age" "P-val: Score" "P-val: Size")) ///
            title("Panel: Grade `g'") mtitles("Small" "Regular" "Regular+Aide") ///
            label nodepvars nonumber append plain
}


// ******************************************************************************
// EXERCISE 2: Plain Text Output for Interpretation
// ******************************************************************************

local grades k 1 2 3
local covars lunchdummy whiteasiandummy agein85

foreach g in `grades' {
    display _newline(2) "=========================================================="
    display "RESULTS FOR GRADE: `g' (Conditional on School FE)"
    display "=========================================================="
    display "Variable" _col(25) "F-Stat" _col(35) "P-Value"
    display "----------------------------------------------------------"
    
    foreach v in `covars' {
        * Handle the lunchdummy name suffix
        local depvar `v'
        if "`v'" == "lunchdummy" local depvar lunchdummy`g'
        
        * Run the regression with school fixed effects
        quietly xi: reg `depvar' small_`g' regaide_`g' i.schid`g' if inlist(ctype`g', 1, 2, 3)
        
        * Run the joint test
        quietly testparm small_`g' regaide_`g'
        
        * Display results neatly in the console
        display "`v'" _col(25) %9.3f r(F) _col(35) %9.3f r(p)
    }
}



// ******************************************************************************
// EXERCISE 3: OLS Replications (Krueger Table 5 Style)
// ******************************************************************************

** 1. Ensure the 'girl' variable exists (Instructions call it 'female', colleague used 'girl')
gen girl = (sex == 2) if !missing(sex)
label var girl "Female"

** 2. Define grades to loop through
local grades k 1 2 3

foreach g in k 1 2 3 {
    
    * 1. Prep variables (identical names for all grades)
    cap drop small regaide lunch score
    gen small = small_`g'
    gen regaide = regaide_`g'
    gen lunch = lunchdummy`g'
    gen score = score`g'
    
    label var small "Small Class"
    label var regaide "Regular w/ Aide"
    label var lunch "Free Lunch"
    label var girl "Female"

    est clear
    
    * 2. Run Regressions
    quietly reg score small regaide if inlist(ctype`g', 1, 2, 3), robust
    est store basic_`g'
    
    quietly xi: reg score small regaide i.schid`g' if inlist(ctype`g', 1, 2, 3), robust
    est store schoolFE_`g'
    
    quietly xi: reg score small regaide whiteasiandummy lunch girl i.schid`g' if inlist(ctype`g', 1, 2, 3), robust
    est store full_`g'
    
    * 3. Export as PURE TEXT (.txt)
    * We remove 'booktabs' and 'fragment' and add 'plain' for clean text
    esttab basic_`g' schoolFE_`g' full_`g' using "output/question_3/panel_`g'.txt", ///
        replace plain b(3) se(3) nodepvars nonumbers ///
        keep(small regaide whiteasiandummy lunch girl) ///
        indicate("School FE = _Ischid*") ///
        title("Results for Grade `g'")
}
