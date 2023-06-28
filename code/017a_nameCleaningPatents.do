/*

Oliver Seager
o.j.seager@lse.ac.uk
SE 17


Created: 14/09/2022
Last Modified: 14/09/2022


Here we simply clean all firm names associated with patents (from both the FGLMY and PatentsView data) using our centralised cleaning algorithm 500_nameCleaning.do.


Infiles:
- uspto.govt.reliance.metadata.dta (Patent data from Fleming, Greene, Li, Marx and Yao (2019), 1926-2017)
- patent.dta (PatentsView's largest patent dataset, most pertinently containing the patent's publication number and the publication date.)
- patent_assignee.dta (PatentsView's link between patents and their associated PatentsView assignee_id.)
- assignee.dta (PatentsView's data on assignee information linked to its unique assignee_id)


Outfiles:
- 017a_fglmy_names_1.dta (Observations are all original firm names from the FGLMY dataset with their clean counterparts)
- 017a_pview_names_1.dta (Observations are all original firm names from the PatentsView dataset with their clean counterparts)


Called .do Files:
- 500_nameCleaning.do (The centralised name cleaning algorithm)


External Packages:
None

*/

********************************************************************************
***************************** CLEANING FGLMY NAMES *****************************
********************************************************************************
  
* Import FGLMY Data *

use "$data/Fleming/uspto.govt.reliance.metadata.dta", clear


* Drop Observations with Empty Assignee *

drop if assignee == "" // Obviously, we can't clean an empty name


* Get an "Original Name" Variable that is upper case *

// The name cleaning algorithm works with upper case strings only. The assignee variable acts as a unique firm identifier for merging back into the FLGMY data.

gen orig_name = strupper(assignee)


* Reduce to Name Only, Drop Duplicates *

keep orig_name assignee 

duplicates drop // It's worth noting here that orig_name is not necessarily now a unique identifier - assignees Google and GOOGLE will have the same original name GOOGLE.


* Recast Names from strL to str244 *

recast str244 assignee orig_name // No name is longer than 244 characters


* Call Name Cleaning Algorithm *

do "$code/500_nameCleaning.do"


* Drop Unneeded Names *

keep assignee orig_name clean_name_6


* Rename to Align with Rest of Data, Label Variables *

label var assignee "Original all-case name in FGLMY; acts as unique firm identifier"

rename orig_name orig_name_fglmy

label var orig_name_fglmy "Original (but upper-case) firm name in FGLMY data"

rename clean_name_6 clean_name 

label var clean_name "Clean name through which patent-accounting match is first attempted"


* Export *

compress

save "$data/017a_fglmy_names_1.dta", replace





********************************************************************************
************************** CLEANING PATENTSVIEW NAMES **************************
********************************************************************************
  
* Import Patent Data *

use "$data/PatentsView/patent.dta", clear


* Keep Only ID *

keep id // Observations are unique at the ID (USPTO patent number) level


* Merge to Assignee ID Data *

rename id patent_id

merge 1:m patent_id using "$data/PatentsView/patent_assignee.dta", keepusing(assignee_id) 

keep if _merge == 3 // We only want patents for which we have assignee IDs

drop _merge patent_id // No longer needed


* Reduce to Assignee ID Level *

duplicates drop // Reduces to assignee ID level


* Merge Assignee IDs to Names *

rename assignee_id id

merge 1:m id using "$data/PatentsView/assignee.dta", keepusing(type organization)

keep if _merge == 3 // We keep only assignees on which we have name data

drop _merge

drop if missing(organization) // We keep only assignees on which we have name data

keep if type == 2 | type == 12 | type == 3 | type == 13 | missing(type) // Keeps only patents assigned to firms (without or with government interest) 

drop type


* Rename Organization *

rename organization orig_name


* Change all Lower Case Characters to Upper Case *

replace orig_name = strupper(orig_name) // Since the PatentsView unique assignee ID (id) is our firm-level identifier, we needn't retain the lower case original name.


* Drop Duplicates *

duplicates drop // There shouldn't actually be any duplicates here as we reduced to assignee ID level above


* Recast Names from strL to str244 *

recast str244 orig_name // No name is longer than 244 characters


* Call Name Cleaning Algorithm *

do "$code/500_nameCleaning.do"


* Drop Unneeded Names *

keep id orig_name clean_name_6


* Rename to Align with Rest of Data, Label Variables *

rename id assignee_id

label var assignee_id "Unique PatentsView-assigned firm identifier"

rename orig_name orig_name_pview

label var orig_name_pview "Original (but upper-case) firm name in PatentsView data"

rename clean_name_6 clean_name 

label var clean_name "Clean name through which patent-accounting match is first attempted"


* Export *

compress

save "$data/017a_pview_names_1.dta", replace