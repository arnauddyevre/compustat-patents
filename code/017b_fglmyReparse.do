/*

Oliver Seager
o.j.seager@lse.ac.uk
SE 17


Created: 14/09/2022
Last Modified: 27/06/2023


Here we reparse FGLMY clean names that are of the form "ASSIGNORSTOCOMPANYNAMEOFCOMPANYLOCATION" such that we just have "COMPANYNAME".


Infiles:
- 017_fglmy_names_1.dta (Observations are all original firm names from the FGLMY dataset with their clean counterparts)
- fglmyReparse_mapping_manuallyReviewed.csv (Observations are manually confirmed mappings from an original FGLMY name of the form "ASSIGNORSTOCOMPANYNAME..." to "COMPANYNAME")


Outfiles:
- 017b_fglmyReparse_mapping.dta (Observations are all reparsable clean names from the FGLMY dataset with their reparsed clean names)
- 017b_fglmyReparse_mapping_manuallyReviewed.dta (A manually cleaned version of the outfile dataset 017b_fglmyReparse_mapping.dta)
- 017b_fglmy_names_2.dta (Observations are all original firm names from the FGLMY dataset with their clean counterparts *following* reparsing)


Called .do Files:
None

External Packages:
- strdist by Michael Barker and Felix Pöge


*/

********************************************************************************
***************************** RE-PARSE CLEAN NAMES *****************************
********************************************************************************
  
// In FGLMY, alongside, say, clean name RELIANCEELECANDENG, we get clean name ASSIGNORSTORELIANCEELECANDENGAOFOHIOAPPLICATIONMARCH221947SERIALNO736532. These are the same company, but we can't really do much with the latter. Thanks to the standardised format of these, we can attribute them to the proper company with a bit of simple string parsing (we don't even use regular expressions here).

* Import FGLMY Names *

use "$data/017a_fglmy_names_1.dta", clear


* Drop Extraneous Variables *

drop orig_name_fglmy assignee // We don't really need these here.


* Flag "ASSIGNORS TO" Names *

gen misparse_flag = 0

gen first_6_chars = substr(clean_name, 1, 6) // For comparing to "ASSIGN" via Levenshtein distance. We allow a maximum distance of 1.

ustrdist first_6_chars "ASSIGN", gen(assign_dist) maxdist(1) // Get Levenshtein distance of first 6 characters from "ASSIGN"

drop first_6_chars // no longer needed

gen to_pos = strpos(clean_name, "TO") // We use this to work out where the company name starts - in ASSIGNORSTORELIANCEELECANDENGAOFOHIOAPPLICATIONMARCH221947SERIALNO736532 the company name (RELIANCEELECANDENG) has to_pos = 11 and the company name starts in position 12

replace misparse_flag = 1 if !missing(assign_dist) & to_pos > 5 & to_pos < 15 // We know roughly where we want "to" to appear.

label var misparse_flag "Original name contains full 'Assignors to...' sentence"

drop assign_dist // No longer needed


* Get A Slightly Cleaner Name for Misparsed Names *

// Here we change ASSIGNORSTORELIANCEELECANDENGAOFOHIOAPPLICATIONMARCH221947SERIALNO736532 to RELIANCEELECANDENGAOFOHIOAPPLICATIONMARCH221947SERIALNO736532

gen cleaner_name = substr(clean_name, to_pos + 2, .) if misparse_flag == 1

label var cleaner_name "For misparsed clean names, clean_name after 'ASSIGNORTO' or close variation"

drop to_pos // No longer needed


* Get Clean Name Length *

gen neg_clean_name_len = -1*length(clean_name) if misparse_flag == 0 // We don't need this for the ASSIGNORSTO clean_names - allows using sort instead of gsort

label var neg_clean_name_len "Negative of length of clean_name (for non-misparsed clean names)"

keep if neg_clean_name_len < -2 | misparse_flag == 1 // We drop one- and two-letter clean_names for the sake of not matching things over and over again


* Get Loop Variables *

gen match_name = "" // To be populated for the "ASSIGNORS TO" clean_names, with their best match

label var match_name "non-Misparsed clean name best matching misparsed clean name"

gen no_match = .

label var no_match "Indicator, non-misparsed clean name DOESN'T match iterand misparsed clean name"


* Get Ending Position of Loop *

gsort -misparse_flag clean_name // We want all the mis-parsed companies at the top

replace misparse_flag = _n if misparse_flag == 1 // 

replace misparse_flag = . if misparse_flag == 0

rename misparse_flag misparse_order

count if !missing(misparse_order) // Gets number of observations to loop through into `=r(N)'

local loop_end = `=r(N)'


* Loop Through All "ASSIGNORS TO" Clean Names *

// Our strategy for finding names is to find the clean_name in the observations with misparsed_flag = 0 that occupies the longest substring starting at position 1 of cleaner_name for a given observation with misparse_flag = 1. For example, we have cleaner_name = "HARRISINTERTYPECLEVELANDOHIOAOFDELAWARE5FILED". We have firms named "HARRIS CO" (clean name HARRIS) and "HARRIS-INTERTYPE CORPORATION" (clean name HARRISINTERTYPE). These will both be substrings starting in position 1. We opt for the longer one as, logically, this is the most likely to be correct.

sort misparse_order

forvalues i = 1/`loop_end'{
	
	** Sort Observations **
	
	sort misparse_order
	
	
	** Get "Match" Indicator for each Non-"ASSIGNORS TO" Name **
	
	replace no_match = 1 - (strpos(cleaner_name[`i'], clean_name) == 1) if missing(misparse_order) // Indicator for whether non-"ASSIGNORS TO" observation *does not* match iterand "ASSIGNORS TO" cleaner_name in position 1
	
	
	** Sort, Populate match_name **
	
	sort misparse_order no_match neg_clean_name_len // Retains order for the "ASSIGNORS TO" observations
	
	replace match_name = clean_name[`loop_end' + 1] if no_match[`loop_end' + 1] == 0 & _n == `i' // Populates closest match variablex
	
	
	** Display Progress **
	
	if(mod(`i',50) == 0){
		
		di "{bf:`i' of `loop_end' observations complete.}"
		
	}
	
}


* Drop Extraneous Variables *

keep clean_name match_name


* Drop Duplicates *

duplicates drop // Duplicates arise where the same assignor clean_name is attached to multiple patents.


* Export *

compress

save "$data/017b_fglmyReparse_mapping.dta", replace


/*
The below code retains only the clean names in need of manual review from 017b_fglmyReparse_mapping.dta

use "$data/017b_fglmyReparse_mapping.dta", clear
gen misparse_flag = 0
gen first_6_chars = substr(clean_name, 1, 6)
ustrdist first_6_chars "ASSIGN", gen(assign_dist) maxdist(1)
drop first_6_chars
gen to_pos = strpos(clean_name, "TO")
replace misparse_flag = 1 if !missing(assign_dist) & to_pos > 5 & to_pos < 15
keep if misparse_flag == 1
drop assign_dist to_pos misparse_flag
drop if missing(match_name)

*/





********************************************************************************
*************** PROCESS THE MANUALLY REVIEWED FGLMY REPARSE DATA ***************
********************************************************************************

// This is produced using the commented out code above.

import delimited "$data/fglmyReparse_mapping_manuallyReviewed.csv", varnames(1) clear bindquotes(strict)

compress

save "$data/017b_fglmyReparse_mapping_manuallyReviewed.dta", replace





********************************************************************************
****************************** UPDATE FGLMY NAMES ******************************
********************************************************************************

* Import All FGLMY Names *

use "$data/017a_fglmy_names_1.dta", clear


* Merge to Reparse Mapping * // This mapping comes from a manual review of all remapped clean names that is constructed using the code at the bottom of the above subsection.

merge m:1 clean_name using "$data/017b_fglmyReparse_mapping_manuallyReviewed.dta"


* Generate "Reparsed" Variable; Over-write Clean Names where Necessary *

gen fglmy_reparsed = (_merge == 3)

label var fglmy_reparsed "Clean name constructed via reparsed FGLMY clean name"

replace clean_name = match_name if _merge == 3 

drop match_name _merge // No longer needed


* Export *

compress

save "$data/017b_fglmy_names_2.dta", replace