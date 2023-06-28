/*

Oliver Seager
o.j.seager@lse.ac.uk
SE 17


Created: 14/09/2022
Last Modified: 27/06/2023


Here we implement the final stages of our manual cleaning, namely...
- Arbitrating to which party of a joint venture patents should be attributed
- Automatically mapping clean names with fewer than 50 associated patents to an appropriate parent (among the top 250 patenters). This is "manual" in the sense that the substrings we choose to use for each parent among the top 250 patenters is discretionary, and is intended to catch firms not caught in the substring mapping.
- Manually mapping clean names with 50 or more patents to an appropriate parent (among the top 250 patenters)


Infiles:
- lowPat_vacuumNames.csv (Observations are the appropriate substring and clean name for top patenters for whom we can automatically match subsidiaries [with fewer than 50 patents] using the start of the subsidiaries' clean name)
- subsidiaryManualRemap.csv (Observations are clean_name-to-clean_name mappings from the subsidiaries [with 50 or more patenters] of top patenters to the central clean name of said patenter)
- 017d_fglmy_names_4.dta (Observations are all original firm names from the FGLMY dataset with their clean counterparts *following* the substring matching)
- uspto.govt.reliance.metadata.dta (Patent data from Fleming, Greene, Li, Marx and Yao (2019), 1926-2017)
- 017d_pview_names_4.dta (Observations are all original firm names from the PatentsView dataset with their clean counterparts *following* the substring matching)
- patent_assignee.dta (PatentsView's link between patents and their associated PatentsView assignee_id.)
- 017d_jvManualRemap.dta (Observations are mappings from a clean name representing a joint venture between two companies to the clean name chosen to associate this joint venture with)


Outfiles:
- 017e_lowPat_vacuumNames.dta (Observations are the appropriate substring and clean name for top patenters for whom we can automatically match subsidiaries [with fewer than 50 patents] using the start of the subsidiary's clean name)
- 017e_subsidiaryManualRemap.dta (Observations are clean_name-to-clean_name mappings from the subsidiaries [with 50 or more patents] of top patenters to the central clean name of said patenter)
- 017e_lowPat_autoMapping.dta (Observations are clean names with fewer than 50 associated patents that have been automatically remapped to one of the top 250 patenters)
- 017e_fglmy_names_5.dta (Observations are all original firm names from the FGLMY dataset with their clean counterparts *following* the manual review of joint ventures and subsidiaries)
- 017e_pview_names_5.dta (Observations are all original firm names from the PatentsView dataset with their clean counterparts *following* the manual review of joint ventures and subsidiaries)


Called .do Files:
None


External Packages:
None

*/
  
********************************************************************************
***** PROCESS TARGET CLEAN NAMES FOR AUTOMATED REMAPPING OF LOW-PATENTERS ******
********************************************************************************

/*
The below code allows one to obtain the top 250 clean names by patenting following our substring match...

use "$data/017d_fglmy_names_4.dta", clear
merge 1:m assignee using "$data/Fleming/uspto.govt.reliance.metadata.dta", keep(3) keepusing(grantyear)
drop if grantyear > 1975
gen unity = 1
collapse (sum) pc2675 = unity, by(clean_name)
save "$data/temp.dta", replace
use "$data/017d_pview_names_4.dta", clear
merge 1:m assignee_id using "$data/PatentsView/patent_assignee.dta", keep(3) keepusing(patent_id)
bysort patent_id: gen ps = 1/_N
collapse (sum) pc7621 = ps, by(clean_name)
merge 1:1 clean_name using "$data/temp.dta"
drop _merge
replace pc2675 = 0 if missing(pc2675)
replace pc7621 = 0 if missing(pc7621)
gen pc = pc2675 + pc7621
gsort -pc clean_name
drop if pc < pc[250]
*/

// The idea here is that, having reviewed the top 250 patenters in our dataset following the substring mapping, we select an appropriate substring (say, "SAMSUNG" for mapping to "SAMSUNGELECTRONICS") which will redirect patents from firm clean names with less than 50 associated patents in the case that the appropriate substring matches the first portion of the appropriate substring (thus, "SAMSUNGADVANCEDINSTITUTEOFTECH" will map to "SAMSUNGELECTRONICS")

import delimited "$data/lowPat_vacuumNames.csv", varnames(1) clear bindquotes(strict)

compress

save "$data/017e_lowPat_vacuumNames.dta", replace




********************************************************************************
******************** PROCESS SUBSIDIARIES OF HIGH-PATENTERS ********************
********************************************************************************

// Inspecting the top 250 patenters using the commented-out code above, we conduct manual searches for their subsidiaries both in the data (for similarly-name entities) and online. This produces the below dataset.

import delimited "$data/subsidiaryManualRemap.csv", varnames(1) clear bindquotes(strict)

compress

save "$data/017e_subsidiaryManualRemap.dta", replace



  
  
********************************************************************************
***************** AUTOMATED REMAPPING OF <50 PATENT CLEAN NAMES ****************
********************************************************************************
  
// Here we employ an automated mapping for low-patenting clean names. For example, any clean_name associated with less than 50 patents that begins with the 7-character string "SAMSUNG" will be remapped to "SAMSUNGELEC".

* Import Post-Substring Match Fleming Names *

use "$data/017d_fglmy_names_4.dta", clear


* Merge to Fleming Patent Data *

merge 1:m assignee using "$data/Fleming/uspto.govt.reliance.metadata.dta", keep(3) keepusing(grantyear)

drop if grantyear > 1975 // We use PatentsView for 1976-2021


* Get Counts at the Clean Name Level *

gen unity = 1 // For summing in the collapse

collapse (sum) pc2675 = unity, by(clean_name)

label var pc2675 "Clean name patent count, 1926-1975"


* Save Temporarily *

save "$data/temp.dta", replace


* Import Post-Substring Match PatentsView Names *

use "$data/017d_pview_names_4.dta", clear


* Merge to PatentsView Patent Data *

merge 1:m assignee_id using "$data/PatentsView/patent_assignee.dta", keep(3) keepusing(patent_id)


* Get Counts at the Clean Name Level *

bysort patent_id: gen ps = 1/_N // Gets the correct share of each patent

collapse (sum) pc7621 = ps, by(clean_name)

label var pc7621 "Clean name patent count, 1976-2021"


* Merge to Fleming Patent Counts *

merge 1:1 clean_name using "$data/temp.dta"

drop _merge // No longer needed


* Get a Total 1926-2021 Patent Count *

replace pc2675 = 0 if missing(pc2675)

replace pc7621 = 0 if missing(pc7621)

gen pc = pc2675 + pc7621


* Drop Names with 50 or More Patents *

drop if pc >= 50 & !missing(pc) // These have already been reviewed manually


* Append the Substring Name Data *

append using "$data/017e_lowPat_vacuumNames.dta", gen(appended) // This is the "manual part": these were constructed by researching the top 250 firms by 1926-2021 patent counts, as identified using the code available at the top of this section.


* Generate "Parent Name" Variable * // ...for the low-patenting clean_names to map to.

gen clean_name_parent = ""


* Prepare Loop *

quietly count if appended == 1 // Gets number of vacuum names into `=r(N)'

gsort -appended // Gets all vacuum names to the top of the data


* Loop through All Vacuum Names *

forvalues i = 1/`=r(N)'{
	
	replace clean_name_parent = clean_name[`i'] if strpos(clean_name, clean_name[`i']) == 1 & appended == 0 // Creates the mapping, one vacuum name at a time
	
}


* Retain Only Remapped Clean Names, Relevant Variables; Rename Variables *

keep if !missing(clean_name_parent)

keep clean_name clean_name_parent

rename clean_name clean_name_child // To indicate that this is the name that is being mapped


* Export *

compress

save "$data/017e_lowPat_autoMapping.dta", replace





********************************************************************************
*************** UPDATE FGLMY NAMES WITH MANUALLY CONSTRUCTED DATA **************
********************************************************************************

* Import Current FGLMY Names *

use "$data/017d_fglmy_names_4.dta", clear


* Merge to Joint Ventures Match Mapping *

rename clean_name jv // For the merge

merge m:1 jv using "$data/017d_jvManualRemap.dta", keep(1 3) // Names that only appear in PatentsView data will not merge

rename jv clean_name


* Generate "Joint Venture Remap" Variable; Over-write Clean Names where Necessary *

gen jv_remap = (_merge == 3)

label var jv_remap "Clean name constructed via remapping of joint venture"

replace clean_name = clean_name_parent if _merge == 3 

drop clean_name_parent _merge // No longer needed


* Merge to Manual Subsidiary Mapping *

rename clean_name clean_name_child // For the merge  

merge m:1 clean_name_child using "$data/017e_subsidiaryManualRemap.dta", keep(1 3) // Names that only appear in PatentsView data will not merge

rename clean_name_child clean_name


* Generate "Substring Match" Variable; Over-write Clean Names where Necessary *

gen subsidiary_manual = (_merge == 3)

label var subsidiary_manual "Clean name constructed via manual subsidiary mapping"

replace clean_name = clean_name_parent if _merge == 3 

drop clean_name_parent _merge // No longer needed


* Merge to Automated Subsidiary Mapping *

rename clean_name clean_name_child // For the merge  

merge m:1 clean_name_child using "$data/017e_lowPat_autoMapping.dta", keep(1 3) // Names that only appear in PatentsView data will not merge

rename clean_name_child clean_name


* Generate "Substring Match" Variable; Over-write Clean Names where Necessary *

gen subsidiary_auto = (_merge == 3)

label var subsidiary_auto "Clean name constructed via automated small-subsidiary mapping"

replace clean_name = clean_name_parent if _merge == 3 

drop clean_name_parent _merge // No longer needed


* Export *

compress

save "$data/017e_fglmy_names_5.dta", replace





********************************************************************************
************ Update PatentsView Names with Manually Constructed Data ***********
********************************************************************************

* Import Current PatentsView Names *

use "$data/017d_pview_names_4.dta", clear


* Merge to Joint Ventures Match Mapping *

rename clean_name jv // For the merge

merge m:1 jv using "$data/017d_jvManualRemap.dta", keep(1 3) // Names that only appear in FGLMY data will not merge

rename jv clean_name


* Generate "Joint Venture Remap" Variable; Over-write Clean Names where Necessary *

gen jv_remap = (_merge == 3)

label var jv_remap "Clean name constructed via remapping of joint venture"

replace clean_name = clean_name_parent if _merge == 3 

drop clean_name_parent _merge // No longer needed


* Merge to Manual Subsidiary Mapping *

rename clean_name clean_name_child // For the merge  

merge m:1 clean_name_child using "$data/017e_subsidiaryManualRemap.dta", keep(1 3) // Names that only appear in FGLMY data will not merge

rename clean_name_child clean_name


* Generate "Substring Match" Variable; Over-write Clean Names where Necessary *

gen subsidiary_manual = (_merge == 3)

label var subsidiary_manual "Clean name constructed via manual subsidiary mapping"

replace clean_name = clean_name_parent if _merge == 3 

drop clean_name_parent _merge // No longer needed


* Merge to Automated Subsidiary Mapping *

rename clean_name clean_name_child // For the merge  

merge m:1 clean_name_child using "$data/017e_lowPat_autoMapping.dta", keep(1 3) // Names that only appear in FGLMY data will not merge

rename clean_name_child clean_name


* Generate "Substring Match" Variable; Over-write Clean Names where Necessary *

gen subsidiary_auto = (_merge == 3)

label var subsidiary_auto "Clean name constructed via automated small-subsidiary mapping"

replace clean_name = clean_name_parent if _merge == 3 

drop clean_name_parent _merge // No longer needed


* Export *

compress

save "$data/017e_pview_names_5.dta", replace