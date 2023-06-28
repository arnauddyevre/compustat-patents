/*

Oliver Seager
o.j.seager@lse.ac.uk
SE 17


Created: 04/05/2023
Last Modified: 23/06/2023


The purpose of this script is to map patents to their filers & owners at grant date by gvkey.


Infiles:
- 019f_whoOwnsWhomAndWhen_ReassignmentFriendly.dta (A mapping of clean names to ultimate parent gvkeys, but with a "for reassignment" gvkey that allows the transfer of ownership of patents away from the ultimate owner)
- 019g_whoOwnsWhomAndWhen_privateSubs.dta (A mapping of clean names from private subsidiaries to ultimate parent gvkeys, with a "for reassignment" gvkey that allows the transfer of ownership of patents away from the ultimate owner)
- 019e_patentsHomogenised_wDates.dta (Observations are patents along with grant and (where applicable) application date, their associated original name, associated clean name, data source indicator, and indicators for the methods used to alter the associated clean name.)


Outfiles:
- 020a_whoOwnsWhomAndWhen_ReassignmentFriendlyFinal.dta (A mapping of clean names to ultimate parent gvkeys covering both public and private subsidiaries as well as self-owning public firms, with a "for reassignment" gvkey that allows the transfer of ownership of patents away from the ultimate owner)
- 020a_whoPatentsWhat_grantees.dta (A mapping of patents to the ultimate owner gvkey at the time the patent is assigned, with various details on the patent and accounting sides of the data, at the patent-gvkey_uo-clean_name level)
- 020a_whoPatentsWhat_grantees_skinny.dta (A mapping of patents to the ultimate owner gvkey at the time the patent is assigned, at the patent-gvkey_uo-clean_name level)
- 020a_whoPatentsWhat_applicants.dta (A mapping of patents to the ultimate owner gvkey at the time the patent is applied for, with various details on the patent and accounting sides of the data, at the patent-gvkey_uo-clean_name level)
- 020a_whoPatentsWhat_applicants_skinny.dta (A mapping of patents to the ultimate owner gvkey at the time the patent is applied for, at the patent-gvkey_uo-clean_name level)
- static.csv (For publication; a mapping of patents to the ultimate owner gvkey at the time the patent is applied for, at the patent-gvkey_uo-clean_name level. Identical to 020a_whoPatentsWhat_applicants_skinny.dta.)


Called .do Files:
None


External Packages:
None


*/

********************************************************************************
********************* GET COLLATED WHO-OWNS-WHOM-AND-WHEN **********************
********************************************************************************

* Import Who Owns Whom and When for Listed Firms *

use "$data/019f_whoOwnsWhomAndWhen_ReassignmentFriendly.dta", clear


* Append Who Owns Whom and When for Private Firms *

append using "$data/019g_whoOwnsWhomAndWhen_privateSubs.dta"


* Merge Variables with Distinct Names *

replace singlePublicSubs = singleSubs if missing(singlePublicSubs) // Updates everything from the listed firms WOWAW

drop singleSubs // No longer needed


* Populate Private Subsidiary Indicator for Listed Firms Observations *

replace privateSubsidiary = 0 if missing(privateSubsidiary)


* Order, Compress, Export *

order clean_name privateSubsidiary gvkey_uo gvkeyFR cnLink_y1 cnLink_yN gvkey1 name1 name1_source name1_year1 name1_yearN gvkey2 name2 name2_source name2_year1 name2_yearN gvkey3 name3 name3_source name3_year1 name3_yearN gvkey4 name4 name4_source name4_year1 name4_yearN gvkey5 name5 name5_source name5_year1 name5_yearN gvkey6 name6 name6_source name6_year1 name6_yearN gvkey7 name7 name7_source name7_year1 name7_yearN singlePublicSubs gvkeyIntTier1 gvkeyIntTier2 gvkeyIntTier3 gvkeyCNoriginator

compress

save "$data/020a_whoOwnsWhomAndWhen_ReassignmentFriendlyFinal.dta", replace





********************************************************************************
************* GET TIME-OF-GRANTING AND TIME-OF-APPLICATION MATCHES *************
********************************************************************************


************************** Get Time-of-Granting Match **************************

* Import Homogenised Patent Data *

use "$data/019e_patentsHomogenised_wDates.dta", clear


* Joinby via Clean Name to Accounting-side Data *

joinby clean_name using "$data/020a_whoOwnsWhomAndWhen_ReassignmentFriendlyFinal.dta", unmatched(both)
/*
                       _merge |      Freq.     Percent        Cum.
------------------------------+-----------------------------------
          only in master data |  4,991,974       59.36       59.36 -- The patents that do not match to firms on the accounting-side of the data
           only in using data |        123        0.00       59.36 -- Firms that either (1) only match to patents without grant dates or (2) only match to patents granted in 2021.
both in master and using data |  4,132,950       40.64      100.00 -- A total of 20,834 clean names match to 3,490,141 patents
------------------------------+-----------------------------------
                        Total |  9,125,047      100.00
*/
drop if _merge == 2 // We can't use this information to any productive end

drop _merge // Can be inferred using, say, missing(gvkey_uo)


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
	
	if(strpos("gvkeyIntTier1 gvkeyIntTier2 gvkeyIntTier3", "`var'") == 0){ // These could well be missing for all, but are integral to dataset clarity
	
		quietly count if missing(`var') // Gets number of observations with missing value for `var' into `=r(N)'
		
		if(`=r(N)' == _N){ // Executes if all observations have missing value for `var'
			
			drop `var'
			
			di "`var' dropped as all values missing"
			
		}
		
	}
	
}


* Drop Duplicates *

duplicates drop // Created by the pseudo-dropping


* Drop Empty Observations for Patents that are Otherwise Owned *

// Due to the pseudo-dropping, we have patents which are owned by one gvkey in one observation and owned by no gvkeys in the other

bysort patent_id: egen patentIsOwned = max(!missing(gvkey_uo))

label var patentIsOwned "Patent is owned by at least one gvkey_uo at time of granting"

drop if patentIsOwned == 1 & missing(gvkey_uo) // Drops redundant empty observations


* Export *

compress

save "$data/020a_whoPatentsWhat_grantees.dta", replace


* Export Skinny Version *

drop patentSource_uid patentName patentSide_FGLMYreparsed patentSide_FtoPauto patentSide_FtoPmanual patentSide_substringMatch patentSide_JVremap patentSide_subsManual patentSide_subsAuto patentData_source cnLink_y1 cnLink_yN gvkey1 name1 name1_source name1_year1 name1_yearN gvkey2 name2 name2_source name2_year1 name2_yearN gvkey3 name3 name3_source name3_year1 name3_yearN gvkey4 name4 name4_source name4_year1 name4_yearN gvkey5 name5 name5_source name5_year1 name5_yearN gvkey6 name6 name6_source name6_year1 name6_yearN gvkey7 name7 name7_source name7_year1 name7_yearN singlePublicSubs gvkeyIntTier1 gvkeyIntTier2 gvkeyIntTier3 gvkeyCNoriginator

save "$data/020a_whoPatentsWhat_grantees_skinny.dta", replace
	
	
************************* Get Time-of-Application Match ************************

* Import Homogenised Patent Data *

use "$data/019e_patentsHomogenised_wDates.dta", clear


* Joinby via Clean Name to Accounting-side Data *

joinby clean_name using "$data/020a_whoOwnsWhomAndWhen_ReassignmentFriendlyFinal.dta", unmatched(both)
/*
                       _merge |      Freq.     Percent        Cum.
------------------------------+-----------------------------------
          only in master data |  4,991,974       59.36       59.36 -- The patents that do not match to firms on the accounting-side of the data
           only in using data |        123        0.00       59.36 -- Firms that either (1) only match to patents without grant dates or (2) only match to patents granted in 2021.
both in master and using data |  4,132,950       40.64      100.00 -- A total of 20,834 clean names match to 3,490,141 patents
------------------------------+-----------------------------------
                        Total |  9,125,047      100.00
*/
drop if _merge == 2 // We can't use this information to any productive end

drop _merge // Can be inferred using, say, missing(gvkey_uo)


* Pseudo-drop Extemporaneous Mappings (Application Year) * // By pseudo-drop, I mean move all the accounting-side variables to missing
	
quietly ds, has(type str# strL) // Gets all string variables into `r(varlist)'

foreach var in `r(varlist)'{ // Loops over string variables
	
	if(strpos("patent_id patentSource_uid patentName clean_name", "`var'") == 0){ // We want to retain the variables in the string
		
		replace `var' = "" if appYear < cnLink_y1 | appYear > cnLink_yN
		
	}
	
}

quietly ds, not(type str# strL) // Gets all numeric variables into `r(varlist)'

foreach var in `r(varlist)'{ // Loops over numeric variables
	
	if(strpos("grantYear appYear patentSide_substringMatch patentSide_JVremap patentSide_subsManual patentSide_subsAuto patentData_source cnLink_y1 cnLink_yN", "`var'") == 0){ // We want to retain the variables in the string
		
		replace `var' = . if appYear < cnLink_y1 | appYear > cnLink_yN
		
	}
		
}

replace cnLink_y1 = . if appYear < cnLink_y1 | appYear > cnLink_yN // We have to replace these last as we use them for reference for moving to missing

replace cnLink_yN = . if missing(cnLink_y1)


* Drop Variables that are Entirely Missing *

quietly ds // Gets all variables into `r(varlist)'

foreach var in `r(varlist)'{
		
	if(strpos("gvkeyIntTier1 gvkeyIntTier2 gvkeyIntTier3", "`var'") == 0){ // These could well be missing for all, but are integral to dataset clarity
	
		quietly count if missing(`var') // Gets number of observations with missing value for `var' into `=r(N)'
		
		if(`=r(N)' == _N){ // Executes if all observations have missing value for `var'
			
			drop `var'
			
			di "`var' dropped as all values missing"
			
		}
		
	}
	
}


* Drop Duplicates *

duplicates drop // Created by the pseudo-dropping


* Drop Empty Observations for Patents that are Otherwise Owned *

// Due to the pseudo-dropping, we have patents which are owned by one gvkey in one observation and owned by no gvkeys in the other

bysort patent_id: egen patentIsOwned = max(!missing(gvkey_uo))

label var patentIsOwned "Patent is owned by at least one gvkey_uo at time of application"

drop if patentIsOwned == 1 & missing(gvkey_uo) // Drops redundant empty observations


* Export *

compress

save "$data/020a_whoPatentsWhat_applicants.dta", replace
	
	
* Export Skinny Version *

drop patentSource_uid patentName patentSide_FGLMYreparsed patentSide_FtoPauto patentSide_FtoPmanual patentSide_substringMatch patentSide_JVremap patentSide_subsManual patentSide_subsAuto patentData_source cnLink_y1 cnLink_yN gvkey1 name1 name1_source name1_year1 name1_yearN gvkey2 name2 name2_source name2_year1 name2_yearN gvkey3 name3 name3_source name3_year1 name3_yearN gvkey4 name4 name4_source name4_year1 name4_yearN gvkey5 name5 name5_source name5_year1 name5_yearN gvkey6 name6 name6_source name6_year1 name6_yearN gvkey7 name7 name7_source name7_year1 name7_yearN singlePublicSubs gvkeyIntTier1 gvkeyIntTier2 gvkeyIntTier3 gvkeyCNoriginator

save "$data/020a_whoPatentsWhat_applicants_skinny.dta", replace


* For Publication, Export Skinny Version as .csv *

export delimited "$data/static.csv", replace