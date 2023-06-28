/*

Oliver Seager
o.j.seager@lse.ac.uk
SE 17


Created: 14/09/2022
Last Modified: 27/06/2023


Here we create an automated mapping from clean names in FGLMY to clean names in PatentsView using the 1976-2017 overlap between the two datasets. Applying this mapping to clean names in FGLMY associated with 1926-1975 patents, and appending this with some manually cleaned additions to this mapping, we update the names we use for 1926-1975 patents.


Infiles:
- uspto.govt.reliance.metadata.dta (Patent data from Fleming, Greene, Li, Marx and Yao (2019), 1926-2017)
- patent_assignee.dta (PatentsView's link between patents and their associated PatentsView assignee_id.)
- rawassignee.dta (A detailed link between patents and their associated PatentsView assignee_id, which includes the order in which assignees appear on patents with multiple assignees.)
- 017a_pview_names_1.dta (Observations are all original firm names from the PatentsView dataset with their clean counterparts)
- 017b_fglmy_names_2.dta (Observations are all original firm names from the FGLMY dataset with their clean counterparts *following* reparsing)
- resolve_fglmyToPview_errors.csv (Observations are correct mappings from FGLMY to PatentsView for those FGLMY clean names whose automated mapping to PatentsView is erroneous)
- resolve_fglmyToPview_manualAdditions.csv (Observations are FGLMY-to-PatentsView mappings from top patenters in the FGLMY data who have no automated mapping to PatentsView)


Outfiles:
- 017c_pviewFGLMY_namePairs.dta (Observations are pairs of clean names [one from FGLMY, one from PatentsView] that are together associated with one or more patents, along with patent counts)
- 017c_resolve_fglmyToPview_errors.dta (Observations are correct mappings from FGLMY to PatentsView for those FGLMY clean names whose automated mapping to PatentsView is erroneous)
- 017c_fglmyToPview_nameMap.dta (Observations are mappings from FGLMY clean names to probabilistically associated PatentsView clean names)
- 017c_resolve_flemToPview_manualAdditions.dta (Observations are FGLMY-to-PatentsView mappings from top patenters in the FGLMY data who have no automated mapping to PatentsView)
- 017c_fglmy_names_3.dta (Observations are all original firm names from the FGLMY dataset with their clean counterparts *following* automated and manual homogenisation between FGLMY and PatentsView)


Called .do Files:
None


External Packages:
- jarowinkler by James Feigenbaum
- strdist by Michael Barker and Felix Pöge

*/

********************************************************************************
************** BUILDING A COMMON FGLMY-PATENTSVIEW PATENT DATASET **************
********************************************************************************
  
// Here we build a dataset of all pairs of clean names from FGLMY and PatentsView that are associated with one or more patents.
  
* Import Fleming Data *

use "$data/Fleming/uspto.govt.reliance.metadata.dta", clear


* Drop Observations with Empty Assignee *

drop if assignee == "" // Obviously, we can't clean an empty name


* Drop Observations for Pre-1976 Patents * //...as these will not overlap with the PatentsView data.

drop if grantyear < 1976


* Drop Extraneous Variables *

keep patno assignee


* Merge to PatentsView Assignee Data *

rename patno patent_id // To align with patent_assignee.dta

merge 1:m patent_id using "$data/PatentsView/patent_assignee.dta", keep(3) keepusing(patent_id assignee_id) // This fetches the assignee ID for each patent. We drop patents for which we have no name in the PatentsView data.

duplicates drop // These come from the multiple "location IDs" that appear for the same assignee_id-patent_id pair in the PatentsView assignee data

drop _merge


* Merge to PatentsView Assignee Order Data *

// Since Fleming only include the first assignee for each patent, we similarly need to include only the first assignee for each patent in the PatentsView data. This comes from the variable "sequence" in the rawassignee.dta dataset

merge 1:m patent_id assignee_id using "$data/PatentsView/rawassignee.dta", keep(1 3) keepusing(patent_id assignee_id sequence) // We avoid keeping the using data since we don't have sufficient information on these patents.

keep if sequence == 0 // I.e. keep the patent's *first* assignee

drop sequence _merge patent_id // No longer needed


* Merge to PatentsView Clean Name Data *

merge m:1 assignee_id using "$data/017a_pview_names_1.dta", keep(3) keepusing(assignee_id clean_name) // We don't strictly need the PatentsView original name, so we elect to ignore it here. We also ignore unmerged observations - those from the master will be non-firm assignees (government, individuals) and those from the using will be firms who PatentsView assign patents that are absent from the Fleming data.

drop _merge assignee_id // No longer needed

rename clean_name clean_name_pview

label var clean_name_pview "Clean name associated with first assignee in PatentsView"


* Merge to Fleming Clean Name Data *

merge m:1 assignee using "$data/017b_fglmy_names_2.dta", keep(3) keepusing(assignee clean_name) // Nothing here from the master is unmerged by design. The clean names from the using that are unmerged are those who Fleming assign patents that are absent from the PatentsView data (esp. those only patenting before 1976)

drop _merge assignee // No longer needed

rename clean_name clean_name_fglmy 

label var clean_name_fglmy "Clean name associated with assignee in Fleming"


* Get Counts *

bysort clean_name_pview: gen pview_count = _N

label var pview_count "Number of patents associated with the PatentsView clean name"

bysort clean_name_fglmy: gen flem_count = _N 

label var flem_count "Number of patents associated with the Fleming clean name"

bysort clean_name_pview clean_name_fglmy: gen both_count = _N

label var both_count "Number of patents associated with both clean names in combination"


* Reduce to Clean Name Pair Level *

duplicates drop

label var clean_name_pview "Clean name in PatentsView" // These names now have different meanings

label var clean_name_fglmy "Clean name in Fleming"


* Export *

compress

save "$data/017c_pviewFGLMY_namePairs.dta", replace


/*
The below obtains the portion of the top 1,000 patenters in FGLMY that do not map solely to an identical clean name in PatentsView.

use assignee grantyear using "$data/Fleming/uspto.govt.reliance.metadata.dta", clear
drop if grantyear > 1975
gen unity = 1 
collapse (sum) pc = unity, by(assignee)
merge 1:1 assignee using "$data/017a_fglmy_names_1.dta", keepusing(clean_name) keep(3)
collapse (sum) pc, by(clean_name)
rename clean_name clean_name_fglmy
merge 1:m clean_name_fglmy using "$data/017c_pviewFGLMY_namePairs.dta", keep(3)
drop _merge 
gsort -pc
drop if pc < pc[1000]
bysort clean_name_fglmy: egen maps_to_same_name = max(clean_name_fglmy == clean_name_pview)
bysort clean_name_fglmy: drop if maps_to_same_name == 1 & _N == 1
drop maps_to_same_name
gsort -pc clean_name_fglmy clean_name_pview
*/





********************************************************************************
***** PROCESS THE FGLMY-TO-PATENTSVIEW CLEAN NAME MAPPING RESOLUTION DATA ******
********************************************************************************

* Process the FGLMY-to-PatentsView Clean Name Mapping Resolution Data * // This data contains corrections to errors in the Fleming-to-PatentsView "probabilistic match" mapping. Each observation is the "correct" mapping, and by merging this to the automated mappings by FGLMY clean name we can remove the erroneous automated mappings.

import delimited "$data/resolve_fglmyToPview_errors.csv", varnames(1) clear bindquotes(strict)

compress

save "$data/017c_resolve_fglmyToPview_errors.dta", replace





********************************************************************************
**** BUILDING m:1 MAPPING FROM FGLMY CLEAN NAMES TO PATENTSVIEW CLEAN NAMES ****
********************************************************************************

// We resolve the issue of FGLMY according to the paper's description - first by most patents, then by closest Levenshtein distance, then arbitrarily using a random seed.

* Import Clean Names Pairs Data *

use "$data/017c_pviewFGLMY_namePairs.dta", clear


* Drop Associated PatentsView Clean Names According to Highest Common Patent Count *

bysort clean_name_fglmy (both_count): drop if both_count < both_count[_N] // Retains PatentsView clean names tied for the most common patents


* Drop Associated PatentsView Clean Names According to Highest Jaro Similarity *

bysort clean_name_fglmy: gen fp1m = (_N > 1) // FGLMY-PatentsView One-to-Many Indicator. We flag this because finding the Jaro similarity between all pairs would be a nightmare.

preserve // We use a temporary save file here so we only generate Jaro similarity where needed - the command jarowinkler doesn't take an "if" statement.

	keep if fp1m == 0

	save "$data/temp.dta", replace 

restore

keep if fp1m == 1

jarowinkler clean_name_fglmy clean_name_pview, gen(jaro_sim) pwinkler(0)  // Jaro Similarity between Clean FGLMY Name and Clean PatentsView Name

bysort clean_name_fglmy (jaro_sim): drop if jaro_sim < jaro_sim[_N] // Retains PatentsView clean names tied for the most common patents and most Jaro similarity

append using "$data/temp.dta"

drop fp1m jaro_sim // No longer needed


* Drop Associated PatentsView Clean Names According to Lowest Levenshtein Distance *

bysort clean_name_fglmy: gen fp1m = (_N > 1) // FGLMY-PatentsView One-to-Many Indicator. We flag this because finding the Levenshtein distance between all pairs would also be a nightmare.

ustrdist clean_name_fglmy clean_name_pview if fp1m == 1, gen(lev_dist)  // Levenshtein distance between Clean FGLMY Name and Clean PatentsView Name

bysort clean_name_fglmy (lev_dist): drop if lev_dist > lev_dist[1] // Retains PatentsView clean names tied for the most common patents and the most Jaro similarity and the least Levenshtein distance

drop fp1m lev_dist // No longer needed


* Drop Associated PatentsView Clean Names Arbitrarily *

set seed 0 // Set random seed

gen random_uniform = runiform() // Generate random number

bysort clean_name_fglmy (random_uniform): drop if _n > 1 // Drop mappings arbitrarily

drop random_uniform // No longer needed


* Integrate Resolution Data *

append using "$data/017c_resolve_fglmyToPview_errors.dta", gen(resolution) // This has all been manually constructed by reviewing the mappings associated with the portion of the top 1,000 patenters in FGLMY that map to a clean_name different from their own in PatentsView. Code is given at the bottom of the above subsection for attaining this dataset.

bysort clean_name_fglmy (resolution): drop if _n < _N // Drops observations generated automatically where manual resolution observation exists

drop if missing(clean_name_pview) // Some of the manual resolution data intentionally leaves clean_name_pview blank as there is no correct PatentsView clean name to map to.


* Drop Extraneous Variables *

keep clean_name_fglmy clean_name_pview

order clean_name_fglmy clean_name_pview


* Rename, Re-label *

label var clean_name_fglmy "FGLMY clean name"

label var clean_name_pview "PatentsView clean name probabilistically matched with Fleming clean name"


* Drop Observations with Identical Clean Names *

drop if clean_name_fglmy == clean_name_pview // This isn't really an "alteration", so much as a confirmation of the cleaning algorithm's successful homogenisation.


* Export *

compress

save "$data/017c_fglmyToPview_nameMap.dta", replace


/*
The below code gives the top 500 patenters in FGLMY that do not map to a PatentsView clean name at all.

use assignee grantyear using "$data/Fleming/uspto.govt.reliance.metadata.dta", clear
drop if grantyear > 1975
gen unity = 1 
collapse (sum) pc = unity, by(assignee)
merge 1:1 assignee using "$data/017a_fglmy_names_1.dta", keepusing(clean_name) keep(3)
collapse (sum) pc, by(clean_name)
rename clean_name clean_name_fglmy
merge 1:m clean_name_fglmy using "$data/017c_pviewFGLMY_namePairs.dta", keep(1)
drop _merge clean_name_pview pview_count flem_count both_count
gsort -pc
drop if pc < pc[500]
gsort -pc clean_name_fglmy
*/





********************************************************************************
***** PROCESS THE FGLMY-TO-PATENTSVIEW CLEAN NAME MAPPING RESOLUTION DATA ******
********************************************************************************

// These data come from the review of the top 500 patenters of the FGLMY data whose clean name does not map to a PatentsView clean name in an automated fashion.

import delimited "$data/resolve_fglmyToPview_manualAdditions.csv", varnames(1) clear bindquotes(strict)

compress

save "$data/017c_resolve_fglmyToPview_manualAdditions.dta", replace





********************************************************************************
*************** UPDATE FGLMY ASSIGNEE-TO-CLEAN_NAME MAPPING WITH ***************
*********** AUTOMATED MAPPING AND ITS MANUALLY CONSTRUCTED ADDITIONS ***********
********************************************************************************
  
// "assignee" acts as the unique, firm-level identifier in FGLMY. Hence we update the mapping from assignee to a clean name using our automated mapping and its manually constructed additions, which are constructed from the top 500 patenters in FGLMY that do not map to a PatentsView clean name at all; this is done using the dataset for which code is given at the bottom of the above subsection.

* Import Current FGLMY Name Mapping *

use "$data/017b_fglmy_names_2.dta", clear


* Merge to the Automated Name Mapping *

rename clean_name clean_name_fglmy

merge m:1 clean_name_fglmy using "$data/017c_fglmyToPview_nameMap.dta"


* Generate "Automatically Mapped to PatentsView" Indicator; Replace Clean Names *

gen fglmy_to_pview_auto = (_merge == 3)

label var fglmy_to_pview_auto "Clean name constructed via automated FGLMY-to-PatentsView mapping"

replace clean_name_fglmy = clean_name_pview if _merge == 3 // Updates the clean name to that which is mapped to.

drop clean_name_pview _merge // No longer needed


* Merge to the Manual Additions to the Automated Name Mapping *

merge m:1 clean_name_fglmy using "$data/017c_resolve_fglmyToPview_manualAdditions.dta"


* Generate "Manually Mapped to PatentsView"; Replace Clean Names *

gen fglmy_to_pview_manual = (_merge == 3)

label var fglmy_to_pview_manual "Clean name constructed via manual FGLMY-to-PatentsView mapping"

replace clean_name_fglmy = clean_name_verified if _merge == 3

drop clean_name_verified _merge

rename clean_name_fglmy clean_name


* Export *

compress

save "$data/017c_fglmy_names_3.dta", replace