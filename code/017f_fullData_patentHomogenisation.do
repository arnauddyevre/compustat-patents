/*

Oliver Seager
o.j.seager@lse.ac.uk
SE 17


Created: 14/09/2022
Last Modified: 27/06/2023


Here we simply take the final versions of patent-clean_name linkages produced in the previous script and use them to make one long patent dataset.


Infiles:
- 017e_fglmy_names_5.dta (Observations are all original firm names from the FGLMY dataset with their clean counterparts *following* the manual review of joint ventures and subsidiaries)
- uspto.govt.reliance.metadata.dta (Patent data from Fleming, Greene, Li, Marx and Yao (2019), 1926-2017)
- 017e_pview_names_5.dta (Observations are all original firm names from the PatentsView dataset with their clean counterparts *following* the manual review of joint ventures and subsidiaries)
- patent_assignee.dta (PatentsView's link between patents and their associated PatentsView assignee_id.)


Outfiles:
- 017f_patents_homogenised.dta (Observations are patents along with their associated original name, associated clean name, data source indicator, and indicators for the methods used to alter the associated clean name.)


Called .do Files:
None


External Packages:
None

*/


* Import FGLMY Names *

use "$data/017e_fglmy_names_5.dta", clear


* Merge to FGMLY Patent Data *

merge 1:m assignee using "$data/Fleming/uspto.govt.reliance.metadata.dta", keepusing(patno grantyear)

drop if _merge != 3 | grantyear > 1975 // These patents are either unusable or unnecessary

drop _merge grantyear


* Rename, Relabel Variables for Consistency *

rename orig_name_fglmy orig_name

label var orig_name "Original (but upper-case) name associated with patent in source data"

rename patno patent_id

label var patent_id "USPTO patent number"

rename assignee source_uid

label var source_uid "Unique firm ID in source data (assignee in FGLMY, assignee_id in PatentsView)"


* Generate Data Source Variable *

gen data_source = 0

label var data_source "0 = FGLMY; 1 = PatentsView"


* Order and Export Temporarily *

order patent_id source_uid orig_name data_source clean_name fglmy_reparsed fglmy_to_pview_auto fglmy_to_pview_manual substring_match jv_remap subsidiary_manual subsidiary_auto

compress

save "$data/temp.dta", replace


* Import PatentsView Names *

use "$data/017e_pview_names_5.dta", clear


* Merge to PatentsView Patent Data *

merge 1:m assignee_id using "$data/PatentsView/patent_assignee.dta", keepusing(patent_id)

drop if _merge != 3 // These patents are unusable

drop _merge // No longer needed

duplicates drop // These come from multiple location_ids listed for the same assignee


* Rename, Relabel Variables for Consistency *

rename orig_name_pview orig_name

label var orig_name "Original (but upper-case) name associated with patent in source data"

label var patent_id "USPTO patent number"

rename assignee source_uid

label var source_uid "Unique firm ID in source data (assignee in FGLMY, assignee_id in PatentsView)"


* Generate Data Source Variable *

gen data_source = 1

label var data_source "0 = FGLMY; 1 = PatentsView"


* Append Fleming Patents *

append using "$data/temp.dta"


* Order and Export *

order patent_id source_uid orig_name data_source clean_name fglmy_reparsed fglmy_to_pview_auto fglmy_to_pview_manual substring_match jv_remap subsidiary_manual subsidiary_auto

compress

save "$data/017f_patents_homogenised.dta", replace