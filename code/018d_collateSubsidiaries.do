/*

Oliver Seager
o.j.seager@lse.ac.uk
SE 17


Created: 21/05/2023
Last Modified: 21/05/2023


The purpose of this script is to collate all the subsidiary information we have across (1) Arora, Belenzon, and Sheer (2021); (2) General Research; (3) The WRDS-Corpwatch compilation of subsidiary data from 10-K filings with the SEC


Infiles:
- 018a_ABSsubsName_gvkey_year.dta (All subsidiaries sourced from ABS, at the subsidiary_name-gvkey-year level. Note that duplicates at the subsidiary_name-year level are *jointly owned* by 2 gvkeys.)
- 018b_genResearch_subsName_gvkey.dta (A mapping of the names of private subsidiaries to their ultimate owner gvkeys for a specified period, as constructed from general research and reference to Lev and Mandelker (1972))
- 018c_wrdsSEC_subsName_gvkey.dta (At the gvkey-Subsidiary level, mappings of subsidiaries (by name) to gvkeys from SEC filings, Oct1992-Jul2019. Derived from the compilation of such filings by WRDS, itself built on the CorpWatch API.)


Outfiles:
- 018d_collatedSubsidiaries.dta (All subsidiaries sourced from ABS 2021, general research, LM 1972, and 10-Ks, with their clean names. At the gvkey-clean_name-ownership_period level)


Called .do Files:
- 500_nameCleaning.do (The centralised name cleaning algorithm)


External Packages:
None


*/

********************************************************************************
******************************* COLLATE ALL DATA *******************************
********************************************************************************

* Import ABS Subsidiary Data *

use "$data/018a_ABSsubsName_gvkey_year.dta", clear


* Rename, Relabel Variables *

label var gvkey "Immediate owner of subsidiary"

rename name_std subs_name

label var subs_name "Name of subsidiary"


* Reduce to gvkey-Subsidiary Level *

bysort gvkey subs_name (year): gen ownershipRun = 1 if _n == 1

bysort gvkey subs_name (year): replace ownershipRun = ownershipRun[_n-1] + (year != year[_n-1] + 1) if _n > 1

label var ownershipRun "Identifier of distinct period of ownership of subsidiary by gvkey"

bysort gvkey subs_name ownershipRun (year): gen year1 = year[1]

label var year1 "Year in which gvkey's ownership of subsidiary commences"

bysort gvkey subs_name ownershipRun (year): gen yearN = year[_N]

label var yearN "Year in which gvkey's ownership of subsidiary concludes"

drop year ownershipRun // No longer needed

duplicates drop


* Declare Source of Data *

gen name_source = "ABS 2021"

label var name_source "Source of name"


* Append General Research Data *

append using "$data/018b_genResearch_subsName_gvkey.dta" // This is already in the same desired format


* Append WRDS-Corpwatch SEC 10-K Data *

append using "$data/018c_wrdsSEC_subsName_gvkey.dta"


* Run Names Through Cleaning Algorithm *

gen orig_name = upper(subs_name) // To facilitate the cleaning algorithm

label var orig_name "Subsidiary name, upper case"

do "$code/500_nameCleaning.do"

drop orig_name clean_name_1 clean_name_2 clean_name_3 clean_name_4 clean_name_5 // No longer needed

rename clean_name_6 clean_name

label var clean_name "Name as cleaned by Dyèvre-Seager algorithm"


* Flag Data as Subsidiaries *

gen subsidiary = 1

label var subsidiary "Indicator, name refers to subsidiary of gvkey"


* Censor Observations At 1950/2020 *

replace year1 = 1950 if year1 < 1950

replace yearN = 2020 if yearN > 2020


* Export *

order gvkey subs_name clean_name year1 yearN name_source

compress

save "$data/018d_collatedSubsidiaries.dta", replace