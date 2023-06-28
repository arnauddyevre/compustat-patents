/*

Oliver Seager
o.j.seager@lse.ac.uk
SE 17


Created: 20/05/2023
Last Modified: 20/05/2023


The purpose of this script is to process into .dta format the private subsidiaries matched to gvkeys both through general research and through reference to Lev and Mandelker (1972)


Infiles:
- effectiveAcq_listedPrivate.csv (A list of listed-acquires-private "effective acquisitions", with gvkey of the acquiring firm, name of the acquired firm, and year of acquisition. Constructed through general research and through reference to Lev and Mandelker (1972))


Outfiles:
- 018b_genResearch_subsName_gvkey.dta (A mapping of the names of private subsidiaries to their ultimate owner gvkeys for a specified period, as constructed from general research and reference to Lev and Mandelker (1972))


Called .do Files:
None


External Packages:
None


*/

********************************************************************************
***************** GET LIST OF PRIVATE-LISTED M&A EVENTS TO .dta ****************
********************************************************************************

* Import List of Listed-Private Ownership with First Year *

import delimited "$orig/Ollie's M&A File/effectiveAcq_listedPrivate.csv", clear varnames(1) stringcols(1)


* Rename, Label Variables *

rename gvkey_primary gvkey 

label var gvkey "Ultimate owner of subsidiary"

rename name_secondary subs_name

label var subs_name "Name of subsidiary"

label var year "Year in which gvkey's ownership of subsidiary commences"

rename source name_source

label var name_source "Source of name"


* Abbreviate Name Source * // To save characters with which the variable is stored

replace name_source = "Gen. Research" if name_source == "General Research"

replace name_source = "LM 1972" if name_source == "Lev and Mandelker (1972)"


* Get Years Beginning and Ending Ownership *

rename year year1

bysort subs_name (year1): gen yearN = year1[_n+1] - 1 // We simply take the year before ownership changes as the final year

replace yearN = 2020 if missing(yearN) // ...or just 2020

label var yearN "Year in which gvkey_primary's ownership of name_secondary concludes"


* Order, Compress, Export *

order gvkey subs_name year1 yearN name_source

compress

save "$data/018b_genResearch_subsName_gvkey.dta", replace