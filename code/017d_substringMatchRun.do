/*

Oliver Seager
o.j.seager@lse.ac.uk
SE 17


Created: 14/09/2022
Last Modified: 27/06/2023


Here we collate all our patent data with the clean names established in all preceding .do files. We then conduct "substring matching" amongst all clean names associated with 50 or more patents. We integrate this substring matching, which is manually reviewed, into the clean names we use for patents in both the 1926-1975 and 1976-2021 data. Although much of this code really comes under the banner of manual review, due to its intricacy we include it here.


Infiles:
- 017c_fglmy_names_3.dta (Observations are all original firm names from the FGLMY dataset with their clean counterparts *following* automated and manual homogenisation between FGLMY and PatentsView)
- uspto.govt.reliance.metadata.dta (Patent data from Fleming, Greene, Li, Marx and Yao (2019), 1926-2017)
- 017a_pview_names_1.dta (Observations are all original firm names from the PatentsView dataset with their clean counterparts)
- patent_assignee.dta (PatentsView's link between patents and their associated PatentsView assignee_id.)
- jvManualRemap.csv (Observations are mappings from a clean name representing a joint venture between two companies to the clean name chosen to associate this joint venture with)
- substringMatch_manuallyReviewed.csv (Observations are clean_name-to-clean_name mappings from the internal substring match process that are retained following manual review)

Outfiles:
- 017d_namesForSubstringMatch.dta (Observations are names from either 017_fglmy_names_3.dta or 017_pview_names_1.dta, with associated patent counts for 1926-1975, 1976-2021, and 1926-2021)
- 017d_substringMatch.dta (Observations are all clean names with 50 or more associated patents that contain as a substring a different clean name with 50 or more associated patents, along with the longest clean name that is a strict substring)
- 017d_jvManualRemap.dta (Observations are mappings from a clean name representing a joint venture between two companies to the clean name chosen to associate this joint venture with)
- 017d_substringMatch_manuallyReviewed.dta (A manually reviewed version of the data produced in 017d_substringMatch.dta)
- 017d_substringMatch_mapping.dta (Observations are those observations from 017_substringMatch.dta that are deemed to be legitimate)
- 017d_fglmy_names_4.dta (Observations are all original firm names from the FGLMY dataset with their clean counterparts *following* the substring matching)
- 017d_pview_names_4.dta (Observations are all original firm names from the PatentsView dataset with their clean counterparts *following* the substring matching) [Note that 017_pview_names_2.dta and 017_pview_names_3.dta do not exist by design]


Called .do Files:
None


External Packages:
None


*/


********************************************************************************
* COLLATE ALL FGLMY AND PATENTSVIEW CLEAN NAMES, OBTAIN PATENT COUNTS FOR EACH *
********************************************************************************

* Import Fleming Names *

use "$data/017c_fglmy_names_3.dta", clear


* Merge to Patent Data *

merge 1:m assignee using "$data/Fleming/uspto.govt.reliance.metadata.dta", keepusing(assignee grantyear)

drop if _merge == 2 | grantyear > 1975 // We don't want patents not bearing a name, nor patents after 1975

drop _merge grantyear orig_name_fglmy assignee // No longer needed


* Collapse to Clean Name Level *

gen unity = 1 // For the clean name patent count

collapse (sum) pc2675 = unity, by(clean_name)


* Export 1926-1975 Patent Counts Temporarily *

compress

save "$data/temp.dta", replace


* Import PatentsView Names *

use "$data/017a_pview_names_1.dta", clear


* Merge to PatentsView Patent Data *

merge 1:m assignee_id using "$data/PatentsView/patent_assignee.dta", keepusing(assignee_id patent_id)

keep if _merge == 3

duplicates drop // Multiple location_ids for the same assignee_id-patent_id pairing cause duplicates here

drop _merge assignee_id orig_name_pview // No longer needed


* Get Patent Counts at Clean Name Level *

bysort patent_id: gen patent_share = 1/_N

collapse (sum) pc7621 = patent_share, by(clean_name)


* Merge to 1926-1975 Patent Counts *

merge 1:1 clean_name using "$data/temp.dta"

drop _merge // Not needed


* Fill Missing Patent Count Values with Zeros, Get Total Patent Count *

replace pc2675 = 0 if missing(pc2675)

replace pc7621 = 0 if missing(pc7621)

gen total_pc = pc2675 + pc7621


* Drop if Clean Name Missing *

drop if missing(clean_name)


* Export *

compress

save "$data/017d_namesForSubstringMatch.dta", replace





********************************************************************************
**************************** CONDUCT SUBSTRING MATCH ***************************
********************************************************************************

* Import Pre Substring Match Clean Name Data *

use "$data/017d_namesForSubstringMatch.dta", clear


* Drop Extraneous Variables, Firms that Patent Less than 50 Times *

keep clean_name total_pc

drop if total_pc < 50


* Get Loop Variables *

gen match_name = "" // To be populated for the "ASSIGNORS TO" clean_names, with their best match

label var match_name "Longest substring that is a different firm clean_name"

gen match_pc = .

label var match_pc "Patent count of match"

gen no_match = .

label var no_match "Indicator that clean name DOESN'T match iterand misparsed clean name"

gen neg_clean_name_len = -1*length(clean_name)

drop if neg_clean_name_len >= -2 // We avoid clean_names with less than 3 characters to prevent pointless overmatching

label var neg_clean_name_len "Negative of length of clean_name"

sort clean_name

gen obs_nr = _n // A small, easy to order immutable variable


* Loop Through all Observations *

forvalues i = 1/`=_N'{
	
	** Sort Observations **
	
	sort obs_nr
	
	
	** Get No Match Indicator to Flag Observations Whose Clean Name is not Substring of Iterand Clean Name **
	
	replace no_match = 1 - (strpos(clean_name[`i'], clean_name) & `i' != obs_nr)
	
	
	** Sort, Populate Match Name **
	
	sort no_match neg_clean_name_len
	
	replace match_name = clean_name[1] if obs_nr == `i' & no_match[1] == 0
	
	replace match_pc = total_pc[1] if obs_nr == `i' & no_match[1] == 0
	
}


* Drop Unmatched Observations *

drop if missing(match_name)


* Drop Extraneous Variables *

drop no_match neg_clean_name_len obs_nr // No longer needed


* Clarify Variable Names, Order, Sort, Export for Analysis *

rename total_pc cn_pc

order match_name match_pc clean_name cn_pc

gsort match_name -cn_pc

save "$data/017d_substringMatch.dta", replace





********************************************************************************
************* PROCESS JOINT VENTURES IDENTIFIED IN SUBSTRING MATCH *************
********************************************************************************

* Process the Joint Venture Resolution Data * // We find several joint ventures in the dataset 017d_substringMatch.dta. This data resolves these joint ventures, having been constructed based on criteria given in the paper.

import delimited "$data/jvManualRemap.csv", varnames(1) clear bindquotes(strict)

compress

save "$data/017d_jvManualRemap.dta", replace





********************************************************************************
******** INITIALLY PROCESS MANUALLY REVIEWED PORTION OF SUBSTRING MATCH ********
********************************************************************************

// We review *the entirety* of 017d_substringMatch.dta, dropping roughly 80% of observations. The remainder, which we deem to be correct, are contained in substringMatch_manuallyReviewed.csv.

import delimited "$data/substringMatch_manuallyReviewed.csv", varnames(1) clear bindquotes(strict)

compress

save "$data/017d_substringMatch_manuallyReviewed.dta", replace





********************************************************************************
********* FURTHER PROCESS MANUALLY REVIEWED PORTION OF SUBSTRING MATCH *********
********************************************************************************
  
// This step is necessary as we have several mappings that work in multiple stages from the substring match. Right now one observation is (ROBERTBOSCHTOOL maps to ROBERTBOSCH) and another is (ROBERTBOSCH maps to BOSCH). We want observations such that we have instead (ROBERTBOSCHTOOL maps to BOSCH) and (ROBERTBOSCH maps to BOSCH)

* Import Manually Reviewed Version of 017_substringMatch.dta *

use "$data/017d_substringMatch_manuallyReviewed.dta", clear


* Drop Patent Counts *

drop match_pc cn_pc


* Give Each Observation a Number * // This is necessary as multiple observations might be part of one chain - for example CARLZEISSVISIONINT (Carl Zeiss Vision International) maps to CARLZEISSVISION (Carl Zeiss Vision). In turn, CARLZEISSVISION maps to CARLZEISS.

sort match_name clean_name // Just to establish an order of things.

gen map_nr = _n


* Export Temporarily *

compress

save "$data/temp.dta", replace


* Establish All Chains of Mapping: Pre-loop Administration *

rename match_name top_level_name

rename map_nr base_map_nr

local i = 0 // Just an iterand


* Establish All Chains of Mapping: Loop *

while 1{ // Essentially just a "while True" loop
	
	** Update Iterand **
	
	local i = `i' + 1
	
	
	** Populate Empty Clean Names with an Idiosyncratic Name to Facilitate Merge **
	
	replace clean_name = "EmptyName-Rd`i'-Obs" + string(_n) if missing(clean_name) // We do this because we want to do a 1:m merge, so each clean name needs to be idiosyncratic.
	
	
	** Merge to Existing Mappings **
	
	rename clean_name match_name // To facilitate the merge
	
	merge 1:m match_name using "$data/temp.dta", keep(1 3) // We keep only using unmerged and merged observations.
	
	rename match_name downstream_clean_name`i'
	
	
	** Exit if No Observations Merge ** // This means all chains of names have reached their maximum length
	
	quietly count if _merge == 3 // Gets the number of merging observations into `=r(N)'
	
	if(`=r(N)' == 0){
		
		drop clean_name map_nr _merge base_map_nr // First two empty anyway, neither _merge nor base_map_number needed
		
		continue, break // Exits loop
		
	}
	
	
	** Delete Base Observations that Another Observation has Merged To **
	
	if(`i' == 1){ // (Only Necessary for First Round - Every Observation with a Further Downstream Observation Will Be Deleted in the First Round Here)
	
		gsort -_merge // Gets all the merging observations to the top
		
		gen to_drop = 0 // We can't be losing observations during the loop: that'll mess everything up.
		
		forvalues j = 1/`=r(N)'{ // Loops through the merging observations 
			
			replace to_drop = 1 if base_map_nr == map_nr[`j'] // Flags for dropping any observation that another observation has mapped to
			
		}
		
		drop if to_drop == 1
		
		drop to_drop // No longer needed
	
	}
	
	
	** Drop Extraneous Observations **
	
	drop map_nr _merge // No longer needed
	
}


* Reshape Such that Names at All Levels Map to Top Level Name *

gen obs_nr = _n // Facilitates the reshape

reshape long downstream_clean_name, i(obs_nr top_level_name)

drop _j obs_nr // Neither needed

drop if strpos(downstream_clean_name, "EmptyName") == 1 // Drops all the idiosyncratic empty names we needed to facilitate the 1:m merge in the loop.

duplicates drop // We get duplicates if downstream_clean_name1 maps to multiple names for downstream_clean_name2, for example


* Export *

compress

save "$data/017d_substringMatch_mapping.dta", replace





********************************************************************************
****************** UPDATE FGLMY ASSIGNEE-TO-CLEAN_NAME MAPPING *****************
********************************************************************************
 
* Import Current Names *

use "$data/017c_fglmy_names_3.dta", clear


* Merge to Substring Match Mapping *

rename clean_name downstream_clean_name // For the merge

merge m:1 downstream_clean_name using "$data/017d_substringMatch_mapping.dta", keep(1 3) // Names that only appear in PatentsView data will not merge

rename downstream_clean_name clean_name


* Generate "Substring Match" Variable; Over-write Clean Names where Necessary *

gen substring_match = (_merge == 3)

label var substring_match "Clean name constructed via substring match"

replace clean_name = top_level_name if _merge == 3 

drop top_level_name _merge // No longer needed


* Export *

compress

save "$data/017d_fglmy_names_4.dta", replace





********************************************************************************
************* UPDATE PATENTSVIEW ASSIGNEE_ID-TO-CLEAN_NAME MAPPING *************
********************************************************************************
 
* Import Current Names *

use "$data/017a_pview_names_1.dta", clear


* Merge to Substring Match Mapping *

rename clean_name downstream_clean_name // For the merge

merge m:1 downstream_clean_name using "$data/017d_substringMatch_mapping.dta", keep(1 3) // Names that only appear in FGLMY data will not merge

rename downstream_clean_name clean_name


* Generate All-zero Variables for Homogenisation Steps Only Applicable to FGLMY Clean Names *

gen fglmy_reparsed = 0

label var fglmy_reparsed "Clean name constructed via reparsed FGLMY clean name"

gen fglmy_to_pview_auto = 0

label var fglmy_to_pview_auto "Clean name constructed via automated FGLMY-to-PatentsView mapping"

gen fglmy_to_pview_manual = 0

label var fglmy_to_pview_manual "Clean name constructed via manual FGLMY-to-PatentsView mapping"


* Generate "Substring Match" Variable; Over-write Clean Names where Necessary *

gen substring_match = (_merge == 3)

label var substring_match "Clean name constructed via substring match"

replace clean_name = top_level_name if _merge == 3 

drop top_level_name _merge // No longer needed


* Export *

compress

save "$data/017d_pview_names_4.dta", replace