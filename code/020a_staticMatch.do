/*

Oliver Seager
o.j.seager@lse.ac.uk
SE 17


Created: 04/05/2023
Last Modified: 13/07/2023


The purpose of this script is to map patents to their filers & owners at grant date by gvkey.


Infiles:
- 019e_patentsHomogenised_wDates.dta (Observations are patents along with grant and (where applicable) application date, their associated original name, associated clean name, data source indicator, and indicators for the methods used to alter the associated clean name.)
- 019h_whoOwnsWhomAndWhen_ReassignmentFriendlyCollated.dta (A mapping of clean names to ultimate parent gvkeys covering both public and private subsidiaries as well as self-owning public firms, with a "for reassignment" gvkey that allows the transfer of ownership of patents away from the ultimate owner)


Outfiles:
- 020a_whoPatentsWhat_grantees.dta (A mapping of patents to the ultimate owner gvkey at the time the patent is assigned, with various details on the patent and accounting sides of the data, at the patent-gvkeyUO-clean_name level)
- 020a_whoPatentsWhat_grantees_skinny.dta (A mapping of patents to the ultimate owner gvkey at the time the patent is assigned, at the patent-gvkeyUO-clean_name level)
- 020a_whoPatentsWhat_applicants.dta (A mapping of patents to the ultimate owner gvkey at the time the patent is applied for, with various details on the patent and accounting sides of the data, at the patent-gvkeyUO-clean_name level)
- 020a_whoPatentsWhat_applicants_skinny.dta (A mapping of patents to the ultimate owner gvkey at the time the patent is applied for, at the patent-gvkeyUO-clean_name level)
- static.csv (For publication; a mapping of patents to the ultimate owner gvkey at the time the patent is applied for, at the patent-gvkeyUO-clean_name level. Identical to 020a_whoPatentsWhat_applicants_skinny.dta.)


Called .do Files:
None


External Packages:
None


*/

********************************************************************************
************* GET TIME-OF-GRANTING AND TIME-OF-APPLICATION MATCHES *************
********************************************************************************

************************** Get Time-of-Granting Match **************************

* Import Homogenised Patent Data *

use "$data/019e_patentsHomogenised_wDates.dta", clear


* Joinby via Clean Name to Accounting-side Data *

joinby clean_name using "$data/019h_whoOwnsWhomAndWhen_ReassignmentFriendlyCollatedSkinny.dta", unmatched(both)
/*
                       _merge |      Freq.     Percent        Cum.
------------------------------+-----------------------------------
          only in master data |  4,478,623       48.14       48.14 -- The patents that do not match to firms on the accounting-side of the data
           only in using data |        123        0.00       48.14 -- Firms that either (1) only match to patents without grant dates or (2) only match to patents granted in 2021.
both in master and using data |  4,824,591       51.86      100.00 -- A total of 20,933 clean names match to 3,998,725 patents
------------------------------+-----------------------------------
                        Total |  9,303,337      100.00
*/
drop if _merge == 2 // We can't use this information to any productive end

drop _merge // Can be inferred using, say, missing(gvkeyUO)


* Pseudo-drop Extemporaneous Mappings (Grant Year) * // By pseudo-drop, I mean move all the accounting-side variables to missing

quietly ds, has(type str# strL) // Gets all string variables into `r(varlist)'

foreach var in `r(varlist)'{ // Loops over string variables
	
	if(strpos("patent_id patentSource_uid patentName clean_name", "`var'") == 0){ // We want to retain the variables in the string
		
		replace `var' = "" if grantYear < cnLink_y1 | grantYear > cnLink_yN
		
	}
	
}

quietly ds, not(type str# strL) // Gets all numeric variables into `r(varlist)'

foreach var in `r(varlist)'{ // Loops over numeric variables
	
	if(strpos("patentSide_FGLMYreparsed patentSide_FtoPauto patentSide_FtoPmanual grantYear appYear patentSide_substringMatch patentSide_JVremap patentSide_subsManual patentSide_subsAuto patentData_source cnLink_y1 cnLink_yN", "`var'") == 0){ // We want to retain the variables in the string
		
		replace `var' = . if grantYear < cnLink_y1 | grantYear > cnLink_yN
		
	}
		
}

replace cnLink_y1 = . if grantYear < cnLink_y1 | grantYear > cnLink_yN // We have to replace these last as we use them for reference for moving to missing

replace cnLink_yN = . if missing(cnLink_y1)


* Drop Variables that are Entirely Missing *

quietly ds // Gets all variables into `r(varlist)'

foreach var in `r(varlist)'{
	
	if(strpos("`var'", "gvkeyIntTier") == 0){ // These could well be missing for all, but are integral to dataset clarity
	
		quietly count if missing(`var') // Gets number of observations with missing value for `var' into `=r(N)'
		
		if(`=r(N)' == _N){ // Executes if all observations have missing value for `var'
			
			drop `var'
			
			di "`var' dropped as all values missing"
			
		}
		
	}
	
}


* Drop Duplicates *

duplicates drop // Created by the pseudo-dropping


* Drop Extraneous Observations * // These come from the joinby where an extemporaneous clean_name-gvkey mapping exists

bysort patent_id clean_name: egen patentHasCleanNameLink = max(!missing(gvkeyFR))

label var patentHasCleanNameLink "Patent is owned by at least one gvkeyFR via given clean_name"

drop if patentHasCleanNameLink == 1 & missing(gvkeyFR)

drop patentHasCleanNameLink // No longer needed


* Randomly Drop Superfluous Observations Where Patent Maps to gvkeyFR via Multiple Clean Names *

set seed 0

gen randomUniform = runiform()

label var randomUniform "Random number in [0,1]"

bysort patent_id gvkeyFR (randomUniform): drop if _n > 1

drop randomUniform // No longer needed


* Export *

compress

save "$data/020a_whoPatentsWhat_grantees.dta", replace


* Export Skinny Version *

drop patentSource_uid patentName patentSide_FGLMYreparsed patentSide_FtoPauto patentSide_FtoPmanual patentSide_substringMatch patentSide_JVremap patentSide_subsManual patentSide_subsAuto patentData_source gvkey? name? name?_source singlePublicSubs gvkeyIntTier* gvkeyCNoriginator

duplicates drop

save "$data/020a_whoPatentsWhat_grantees_skinny.dta", replace
	
	
************************* Get Time-of-Application Match ************************

* Import Homogenised Patent Data *

use "$data/019e_patentsHomogenised_wDates.dta", clear


* Joinby via Clean Name to Accounting-side Data *

joinby clean_name using "$data/019h_whoOwnsWhomAndWhen_ReassignmentFriendlyCollatedSkinny.dta", unmatched(both)
/*
                       _merge |      Freq.     Percent        Cum.
------------------------------+-----------------------------------
          only in master data |  4,478,623       48.14       48.14 -- The patents that do not match to firms on the accounting-side of the data
           only in using data |        123        0.00       48.14 -- Firms that either (1) only match to patents without grant dates or (2) only match to patents granted in 2021.
both in master and using data |  4,824,591       51.86      100.00 -- A total of 20,933 clean names match to 3,998,725 patents
------------------------------+-----------------------------------
                        Total |  9,303,337      100.00
*/
drop if _merge == 2 // We can't use this information to any productive end

drop _merge // Can be inferred using, say, missing(gvkeyUO)


* Pseudo-drop Extemporaneous Mappings (Application Year) * // By pseudo-drop, I mean move all the accounting-side variables to missing
	
quietly ds, has(type str# strL) // Gets all string variables into `r(varlist)'

foreach var in `r(varlist)'{ // Loops over string variables
	
	if(strpos("patent_id patentSource_uid patentName clean_name", "`var'") == 0){ // We want to retain the variables in the string
		
		replace `var' = "" if appYear < cnLink_y1 | appYear > cnLink_yN
		
	}
	
}

quietly ds, not(type str# strL) // Gets all numeric variables into `r(varlist)'

foreach var in `r(varlist)'{ // Loops over numeric variables
	
	if(strpos("patentSide_FGLMYreparsed patentSide_FtoPauto patentSide_FtoPmanual grantYear appYear patentSide_substringMatch patentSide_JVremap patentSide_subsManual patentSide_subsAuto patentData_source cnLink_y1 cnLink_yN", "`var'") == 0){ // We want to retain the variables in the string
		
		replace `var' = . if appYear < cnLink_y1 | appYear > cnLink_yN
		
	}
		
}

replace cnLink_y1 = . if appYear < cnLink_y1 | appYear > cnLink_yN // We have to replace these last as we use them for reference for moving to missing

replace cnLink_yN = . if missing(cnLink_y1)


* Drop Variables that are Entirely Missing *

quietly ds // Gets all variables into `r(varlist)'

foreach var in `r(varlist)'{
		
	if(strpos("`var'", "gvkeyIntTier") == 0){ // These could well be missing for all, but are integral to dataset clarity
	
		quietly count if missing(`var') // Gets number of observations with missing value for `var' into `=r(N)'
		
		if(`=r(N)' == _N){ // Executes if all observations have missing value for `var'
			
			drop `var'
			
			di "`var' dropped as all values missing"
			
		}
		
	}
	
}


* Drop Duplicates *

duplicates drop // Created by the pseudo-dropping


* Drop Extraneous Observations * // These come from the joinby where an extemporaneous clean_name-gvkey mapping exists

bysort patent_id clean_name: egen patentHasCleanNameLink = max(!missing(gvkeyFR))

label var patentHasCleanNameLink "Patent is owned by at least one gvkeyFR via given clean_name"

drop if patentHasCleanNameLink == 1 & missing(gvkeyFR)

drop patentHasCleanNameLink // No longer needed


* Randomly Drop Superfluous Observations Where Patent Maps to gvkeyFR via Multiple Clean Names *

set seed 0

gen randomUniform = runiform()

label var randomUniform "Random number in [0,1]"

bysort patent_id gvkeyFR (randomUniform): drop if _n > 1

drop randomUniform // No longer needed


* Export *

compress

save "$data/020a_whoPatentsWhat_applicants.dta", replace
	
	
* Export Skinny Version *

drop patentSource_uid patentName patentSide_FGLMYreparsed patentSide_FtoPauto patentSide_FtoPmanual patentSide_substringMatch patentSide_JVremap patentSide_subsManual patentSide_subsAuto patentData_source gvkey? name? name?_source singlePublicSubs gvkeyIntTier* gvkeyCNoriginator

duplicates drop

save "$data/020a_whoPatentsWhat_applicants_skinny.dta", replace


* For Publication, Export Skinny Version as .csv *

export delimited "$data/static.csv", replace