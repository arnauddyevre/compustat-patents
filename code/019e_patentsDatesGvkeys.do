/*

Oliver Seager
o.j.seager@lse.ac.uk
SE 17


Created: 23/06/2023
Last Modified: 23/06/2023


This script essentially serves as some intermediary housekeeping for the upcoming scripts; it...
- Appends dates to the homogenised patent data created in 017f_fullData_patentHomogenisation.do
- Cleans the names from the dynamic name dataset created in 019a_dynamicNames.do
- Produces a dataset of *only* clean names that map to the homogenised patent data


Infiles:
- patent.dta (PatentsView's largest patent dataset, most pertinently containing the patent's publication number and the publication date.)
- application.dta (PatentsView's data on patent applications, including application date)
- uspto.govt.reliance.metadata.dta (Patent data from Fleming, Greene, Li, Marx and Yao (2019), 1926-2017)
- 014_FGLMY2675appYears.dta (USPTO patents from 1926-1975 with their application dates, as inferred from the Fleming, Greene, Li, Marx and Yao (2019) OCR.)
- 017f_patents_homogenised.dta (Observations are patents along with their associated original name, associated clean name, data source indicator, and indicators for the methods used to alter the associated clean name.)
- 019a_dynamicNames.dta (A dynamic mapping of names to gvkeys, derived from Compustat and the CRSP Daily Stock File)


Outfiles:
- 019e_patentsHomogenised_wDates.dta (Observations are patents along with grant and (where applicable) application date, their associated original name, associated clean name, data source indicator, and indicators for the methods used to alter the associated clean name.)
- 019e_dynamicNamesClean.dta (A dynamic mapping of names, as cleaned by the Dyèvre-Seager algorithm, to gvkeys)
- 019e_dynamicNamesClean_matched.dta (A dynamic mapping of clean names [that also feature in our patent dataset] to gvkeys)


Called .do Files:
- 500_nameCleaning.do (The centralised name cleaning algorithm)


External Packages:
None


*/

********************************************************************************
***************** GET PATENTS WITH YEAR OF FILING AND GRANTING *****************
********************************************************************************

* Import PatentsView (1976-2021) Patent Data with Grant Date *

use id date using "$data/PatentsView/patent.dta", clear // This is a large dataset, so we only use a few variables


* Rename, Label Variables *

rename id patent_id // In accordance with the rest of the data

label var patent_id "USPTO patent number"

rename date grantDate

label var grantDate "Date patent is granted as string YYYY-MM-DD"


* Extract Grant Year from Grant Date *

gen grantYear = substr(grantDate, 1, 4) // Just takes the YYYY from YYYY-MM-DD

destring grantYear, replace

label var grantYear "Year in which patent is granted"

drop grantDate // No longer needed


* Merge to Patent Application Data * // This is where we extract the application year from

merge 1:1 patent_id using "$data/PatentsView/application.dta", keepusing(date) // Since application.dta is also quite large, we keep only the "date" variable from the dataset
/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                         2,259
        from master                     2,259  (_merge==1) -- These are all just H documents, and not patents themselves
        from using                          0  (_merge==2) -- Every patent with application data also has granting data

    Matched                         7,988,799  (_merge==3) -- 99.972% of patents merge.
    -----------------------------------------
*/
drop if _merge != 3 // We don't want H documents in our data

drop _merge


* Extract Application Year from Application Date *

rename date appDate

label var appDate "Date patent is applied for as string YYYY-MM-DD"

gen appYear = substr(appDate, 1, 4) // Just takes the YYYY from YYYY-MM-DD

destring appYear, replace

label var appYear "Year in which patent application is filed (1976-2020 grants only)"

drop appDate // No longer needed


* Correct Erroneous Application Years *

// These, assumedly, are poorly OCR'd. We only correct the ones that are absurdly wrong

replace appYear = appYear + 1000 if appYear >= 900 & appYear <= 999 // 1 left out from beginning of string

replace appYear = appYear + 900 if appYear >= 1000 & appYear <= 1100 // second digit misread
replace appYear = appYear + 700 if appYear >= 1200 & appYear <= 1300
replace appYear = appYear + 300 if appYear >= 1600 & appYear <= 1700
replace appYear = appYear + 100 if appYear >= 1800 & appYear <= 1889

replace appYear = appYear + 90 if appYear >= 1890 & appYear <= 1899 // 8 and 9 mixed up

replace appYear = appYear + 80 if appYear >= 1900 & appYear <= 1909 & grantYear - appYear < 90 // 8 misread as 0

replace appYear = appYear + 90 if appYear >= 1900 & appYear <= 1909 & grantYear - appYear >= 90 // 9 misread as 0

replace appYear = appYear - 1000 if appYear >= 2900 & appYear <= 2999 // leading 1 misread as 2

replace appYear = appYear - 6000 if appYear >= 7900 & appYear <= 7999 // leading 1 misread as 7

replace appYear = appYear - 6300 if appYear >= 8100 & appYear <= 8199 // 1 and 8 mixed up?

replace appYear = appYear - 7200 if appYear >= 9100 & appYear <= 9199 // 1 and 9 mixed up


* Drop Nonsensical Application Years *

replace appYear = . if appYear > grantYear | appYear < grantYear - 30


* Append FGLMY Data for 1926-2017 (with grant year only) *

append using "$data/Fleming/uspto.govt.reliance.metadata.dta", gen(appended) keep(patno grantyear) // Since the using dataset is large, we only keep two variables here


* Homogenise Variables *

replace patent_id = patno if missing(patent_id) // Same variable, different names

drop patno // No longer needed

replace grantYear = grantyear if missing(grantYear) // Same variable, different names. Again.

drop grantyear // No longer needed


* Retain FGLMY Patents where We Have No PatentsView Information *

bysort patent_id (appended): drop if _n == 2 // Since patent_id is a unique identifier in each dataset, this drops all superfluous observations from FGLMY. This is *every single patent from 1976-2017* in the FGLMY dataset (verify with tabulate grantYear appended)

drop appended // Can now be inferred from grantYear


* Merge to FGLMY Application Date Information For 1926-1975 Patents *

gen patent_idStr = patent_id

label var patent_idStr "Placeholder for USPTO patent numbers (some of which contain alphabetical characters)"

destring patent_id, replace force // The FGLMY patents are *all* numeric, so patent_id is stored as a numeric. Not so with some of the PatentsView ones, but we keep these safe in patent_idStr

merge m:1 patent_id using "$data/014_FGLMY2675appYears.dta" // This only needs to be m:1 because of all the missing values for patent_id in the master (from alphanumeric patent numbers like RE41351 or D769631). In effect, it isn't really m:1.
/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                     8,697,111
        from master                 8,697,018  (_merge==1) -- (708,219 of the 2,358,126 1926-1975 patents in the main FGLMY dataset do not appear in the FGLMY OCR. The other 7,988,799 patents here are 1976-)
        from using                         93  (_merge==2) -- (96 of the 1,650,000 patents in the FGLMY OCR .zip file do not make it into the final FGLMY data)

    Matched                         1,649,907  (_merge==3) -- (1,649,907 of the 2,358,126 1926-1975 patents in the main FGLMY dataset appear in the FGLMY OCR .zip file [and, vice versa, 1,649,907 of 1,650,000])
    -----------------------------------------
*/
drop if _merge == 2 // Cannot be used

drop _merge // Can be inferred from presence of foundFiled

label var appDate "Year in which patent application is filed (FGLMY OCR, 1926-1975 patents only)"

label var foundFiled "Word 'Filed' appears in FGLMY OCR (1926-1975 patents only)"

tostring patent_id, replace

replace patent_id = patent_idStr if patent_id == "." // Add back in the alphanumeric patent numbers

drop patent_idStr // No longer needed


* Clean FGLMY OCR Application Dates *

replace appDate = . if appDate > 1975 | appDate > grantYear | appDate < grantYear - 30 // There are so many errors here that it's difficult to know how to fix them.


* Integrate FGLMY OCR Application Dates into Main Variable *

replace appYear = appDate if missing(appYear)

label var appYear "Year in which patent application is filed"

drop appDate foundFiled


* Replace Application Year with Median for Given Grant Year where Missing *

quietly summ grantYear // Gets first and last grantYears into `=r(min)' and `=r(max)', respectively

local year1 = `r(min)' // Should be 1926

local yearN = `r(max)' // Whenever the data ends

forvalue y = `year1'/`yearN'{ 
	
	** Where we Have >66% of Application Years, Replace with Median **
	
	quietly count if grantYear == `y' // Gets number of patents with grantYear y into `=r(N)'
	
	local yTotal = `=r(N)'
	
	quietly count if grantYear == `y' & !missing(appYear) // Gets number of patents with grantYear y *that are not missing appYear* into `=r(N)'
	
	if(`=(`yTotal'*(2/3))'< `=r(N)'){ // Executes if we have at least two-thirds of patents from this year with non-missing values for appYear
	
		quietly summ appYear if grantYear == `y', detail // Gets median application year for non-missing values into `=r(p50)'
	
		replace appYear = `=r(p50)' if missing(appYear) & grantYear == `y'
		
	}
	
	
	** Otherwise, Replace with 2 Years Prior to Grant Year **
	
	else{ 
	
		replace appYear = grantYear - 2 if missing(appYear) & grantYear == `y' // FGLMY don't include *any* 1975 patents in their OCR zip; we just take median to be 1973.
		
	}
		
}


* Merge to Homogenised Patent Data *

merge 1:m patent_id using "$data/017f_patents_homogenised.dta" // Since the using here is at the patent-assignee level, we do a 1:m merge
/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                     1,696,734
        from master                 1,695,922  (_merge==1) -- Patents for which we do not have data on assignees. No assignees means no assignee matching, so we can't use these.
        from using                        812  (_merge==2) -- Patents appearing in PatentsView's assignee data, but not in their central dataset. We can't use these since they have no grantyear. All FGLMY patents in the using appear in their main data.

    Matched                         8,855,016  (_merge==3) -- 8,651,003 patents on which we have data for both assignee name and grant year.
    -----------------------------------------
*/
drop if _merge != 3 // See notes above

drop _merge


* Drop Patents Granted in 2021 *

// Unfortunately, we don't have accounting-side dynamic name matching data for 2021

drop if grantYear == 2021


* Rename, Relabel Variables to be Patent-side Specific * // Since we're going to be merging this to the accounting data, we need to be specific about which variables refer to what portion of the source data

rename source_uid patentSource_uid

rename orig_name patentName

rename data_source patentData_source

label var patentData_source "Source of patent data: 0 = FGLMY, 1 = PatentsView"

rename fglmy_reparsed patentSide_FGLMYreparsed
rename fglmy_to_pview_auto patentSide_FtoPauto
rename fglmy_to_pview_manual patentSide_FtoPmanual
rename substring_match patentSide_substringMatch
rename jv_remap patentSide_JVremap
rename subsidiary_manual patentSide_subsManual
rename subsidiary_auto patentSide_subsAuto


* Export *

order patent_id grantYear appYear patentSource_uid patentName patentSide_FGLMYreparsed patentSide_FtoPauto patentSide_FtoPmanual patentSide_substringMatch patentSide_JVremap patentSide_subsManual patentSide_subsAuto patentData_source clean_name

compress

save "$data/019e_patentsHomogenised_wDates.dta", replace





********************************************************************************
************************** GET CLEANED DYNAMIC NAMES ***************************
********************************************************************************

* Import Dynamic Names Mapping *

use "$data/019a_dynamicNames.dta", clear


* Clean Name *

rename name orig_name // For the cleaning algorithm

do "$code/500_nameCleaning.do" // Run name cleaning

rename orig_name name // Reverting back

rename clean_name_6 clean_name // Final clean name

label var clean_name "Name as cleaned by Dyèvre-Seager algorithm"

drop clean_name_1 clean_name_2 clean_name_3 clean_name_4 clean_name_5 // No longer needed


* Drop Names Only Valid after End of 2020 *

drop if yofd(name_linkDay1) > 2020


* Export *

order gvkey wb_date1 wb_dateN name clean_name name_linkDay1 name_linkDayN name_source

compress

save "$data/019e_dynamicNamesClean.dta", replace





********************************************************************************
************* RETAIN CLEANED DYNAMIC NAMES THAT MAP TO PATENT DATA *************
********************************************************************************

* Import Homogenised Patent Data *

use "$data/017f_patents_homogenised.dta", clear


* Keep Only Clean Names, Reduce to Clean Name Level *

keep clean_name

duplicates drop


* Merge to Cleaned Dynamic Names Dataset *

merge 1:m clean_name using "$data/019e_dynamicNamesClean.dta"
/*

    Result                      Number of obs
    -----------------------------------------
    Not matched                       669,767
        from master                   621,816  (_merge==1) -- Clean names that feature in our patent dataset, but not our listed firms dataset
        from using                     47,951  (_merge==2) -- Clean names that feature in our listed firms dataset, but not our patent dataset

    Matched                            14,668  (_merge==3) -- Clean names that feature in the intersection of the patent dataset and the listed firms dataset
    -----------------------------------------

*/
keep if _merge == 3 // To minimise the extent to which we must attend to duplicates, we retain only clean names from the accounting data that can actually be matched to patents.

drop _merge


* Export *

order gvkey wb_date1 wb_dateN name clean_name name_linkDay1 name_linkDayN name_source

compress

save "$data/019e_dynamicNamesClean_matched.dta", replace