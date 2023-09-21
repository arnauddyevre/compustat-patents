/*

Oliver Seager
o.j.seager@lse.ac.uk
SE 17


Created: 17/08/2023
Last Modified: 21/09/2023


The purpose of this script is to generate two more researcher friendly datasets, viz....
	1) A version of the static match where gvkeyUO is missing when the gvkeyUO is not active in Compustat
	2) A version of the dynamic reassignment data at the gvkeyFR-gvkey-ownership_period level

Infiles:
- cstat_1950_2022.dta (A complete Compustat Annual Fundamentals dataset from 1950-2022, with company name, CUSIP, SIC, country codes for incorporation and location, stock exchange codes, common shares traded, # employees, nominal sales, nominal research and development expenditure)
- 020a_whoPatentsWhat_applicants_skinny.dta (A mapping of patents to the ultimate owner gvkey at the time the patent is applied for, at the patent-gvkey_uo-clean_name level)
- 020b_dynamicReassignment.dta (A list of listed-listed and listed-private "effective acquisition" M&A events in terms of our reassignment-friendly gvkeyFRs)
- 019a_cstatPresence.dta (Each gvkey in Compustat with their first and last years present in the dataset)


Outfiles:
- 020c_allGvkeyFyears.dta (A list of all gvkey-fyears that feature in Compustat for 1950-2020)
- 020c_patentsResearcherFriendly.dta (All patents in our database that are attributable to a gvkey either at the time of patenting (3,184,278 patents) and/or for later attribution to a gvkey's patenting history (additional 458,337 patents))
- static.csv (For publication; All patents in our database that are attributable to a gvkey either at the time of patenting (3,184,278 patents) and/or for later attribution to a gvkey's patenting history (additional 458,337 patents). Identical to 020c_patentsResearcherFriendly.dta.)
- 020c_gvkeyFR_to_gvkey.dta (Maps all gvkeyFRs present in our data to Compustat gvkeys)
- dynamic.csv (For publication; maps all gvkeyFRs present in our data to Compustat gvkeys. Identical to 020c_gvkeyFR_to_gvkey.dta.)


Called .do Files:
None


External Packages:
None


*/

********************************************************************************
********************* GET ALL COMPUSTAT GVKEY-FISCAL_YEARS *********************
********************************************************************************

* Import Compustat *

use "$orig/Compustat/cstat_1950_2022.dta", clear


* Drop Extraneous Variables *

keep gvkey fyear


* Drop Duplicates *

duplicates drop


* Drop post-2020 Observations and Missing Observations *

drop if fyear > 2020 | missing(fyear)


* Export *

compress

save "$data/020c_allGvkeyFyears.dta", replace





********************************************************************************
************** REWORK STATIC MATCH TO BE MORE RESEARCHER FRIENDLY **************
********************************************************************************

* Import Static Match (Assignees Only) *

use "$data/020a_whoPatentsWhat_applicants_skinny.dta", clear


* Drop Unmatched Patents *

drop if missing(gvkeyUO) & missing(gvkeyFR)


* Move gvkey_uo to Missing where Not Active in Compustat *

rename gvkeyUO gvkey // Facilitates merge to Compustat

rename appYear fyear // Facilitates merge to Compustat

merge m:1 gvkey fyear using "$data/020c_allGvkeyFyears.dta"
/*

    Result                      Number of obs
    -----------------------------------------
    Not matched                       912,872
        from master                   459,746  (_merge==1) -- Patents for whom the gvkeyUO is not active in Compustat at the time of application 
        from using                    453,126  (_merge==2) -- gvkey-years that do not ultimately own any patents applied for in the given year

    Matched                         3,196,480  (_merge==3) -- Patents that match to gvkeyUOs that are active in Compustat at the time of application
    -----------------------------------------
*/
drop if _merge == 2 // Not needed

rename gvkey gvkeyUO

rename fyear appYear

replace gvkeyUO = "" if _merge == 1

label var gvkeyUO "Ultimate owner of patenting entity at time of application"

label var gvkeyFR "gvkey-like identifier used for patent ownership reassignment"

label var cnLink_y1 "First year of link between gvkeyUO (where applicable), gvkeyFR, and clean_name"

label var cnLink_yN "Last year of link between gvkeyUO (where applicable), gvkeyFR, and clean_name"

drop _merge // No longer needed


* Reorder Variables *

order patent_id appYear gvkeyUO gvkeyFR clean_name cnLink_y1 cnLink_yN privateSubsidiary grantYear


* Export *

label data "All patents matched to gvkeys in Dyèvre and Seager (2023) by application date"

compress

save "$data/020c_patentsResearcherFriendly.dta", replace


* Export as .csv *

export delimited "$data/staticResearcherFriendly.csv", replace





********************************************************************************
******************** CREATE GVKEYFR -TO- GVKEY-YEAR DATASET ********************
********************************************************************************

* Import Dynamic Reassignment Data *

use "$data/020b_dynamicReassignment.dta", clear


* Drop Extraneous Variables *

drop gvkey_primary gvkey_secondary source type


* Rename Variables *

rename gvkeyUO gvkey

rename year year1


* Get Period for which gvkeyUO Ultimately Owns gvkeyFR, re-Label Variables *

bysort gvkeyFR (year): gen yearN = year1[_n+1] - 1

replace yearN = 2020 if missing(yearN) // We censor our data at 2020

label var yearN "Last year for which gvkey is ultimate owner of patents attributed to gvkeyFR"

label var year1 "First year for which gvkey is ultimate owner of patents attributed to gvkeyFR"

label var gvkey "Ultimate owner of patents attributed to gvkeyFR for given period"

label var gvkeyFR "gvkey-like identifier to which patents are attributed"


* Add Self-Ownership Observations (prior to any Effective Acquisition Events) for all gvkeyFRs that are themselves gvkeys *

bysort gvkeyFR: egen firstTransactionYear = min(year1) // All gvkeyFRs of length 6 are true gvkeys

label var firstTransactionYear "Year of first effective acquisition concerning gvkeyFR"

expand 2 if length(gvkeyFR) == 6 & year1 == firstTransactionYear, gen(newObs)

label var newObs "Observation intended to give self-ownership of gvkeyFR prior to any EA events"

replace yearN = year1 - 1 if newObs == 1

replace year1 = 1900 if newObs == 1 // We impose an arbitrarily early starting year for where a gvkey owns itself

drop firstTransactionYear newObs


* Append non-reassigned gvkeyFRs from Patenting Dataset *

append using "$data/020a_whoPatentsWhat_applicants_skinny.dta", keep(gvkeyFR) gen(gvkeyFR_appended)

label var gvkeyFR_appended "gvkeyFR sourced from patent dataset"

drop if missing(gvkeyFR) // We draw non-reassigned gvkeyFRs from our patent dataset, so we drop the observations corresponding to unmatched patents

duplicates drop // We get a lot of duplicates from the patent dataset, unsurprisingly, since we only keep the gvkeyFR from this data


* Drop Unappended gvkeyFRs who do not Patent *

bysort gvkeyFR: egen gvkeyFR_patents = max(gvkeyFR_appended)

label var gvkeyFR_patents "At least one patent attributable to gvkeyFR"

drop if gvkeyFR_patents == 0

drop gvkeyFR_patents // No longer needed


* Drop Appended Observations for gvkeyFRs Appearing in the Original Data *

bysort gvkeyFR: egen gvkeyFR_appendedOnly = min(gvkeyFR_appended)

label var gvkeyFR_appendedOnly "gvkeyFR not subject to any dynamic reassignment"

drop if gvkeyFR_appended == 1 & gvkeyFR_appendedOnly == 0

drop gvkeyFR_appended gvkeyFR_appendedOnly // No longer needed


* Get Arbitrarily Long Ownership Periods for Appended gvkeyFRs *

replace gvkey = gvkeyFR if missing(gvkey)

replace year1 = 1900 if missing(year1)

replace yearN = 2020 if missing(yearN)


* Merge to Presence in Compustat of Ultimate Owner *

merge m:1 gvkey using "$data/019a_cstatPresence.dta"
/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                        31,227
        from master                         0  (_merge==1) -- All from the master merge.
        from using                     31,227  (_merge==2) -- gvkeys in Compustat that do not, at any point, own patents

    Matched                            11,946  (_merge==3) -- gvkeys that at some point own patents.
    -----------------------------------------
*/
drop if _merge == 2 // Not relevant to our data

drop _merge // No longer needed


* Drop Extemporaneous Ownership *

drop if yearN < yPresent1 | year1 > yPresentN


* Redraw Boundaries to Correspond to Time Patent-owning gvkey is Present in Compustat *

replace year1 = yPresent1 if yPresent1 > year1

replace yearN = yPresentN if yPresentN < yearN

drop yPresent1 yPresentN // No longer needed


* Smooth Over Surplus Observations * // We have, for example, that A owns B from 1960-1969 as one observation and then from 1970-1974 as another. Here, we reduce that to a single 1960-1974 observation.

bysort gvkeyFR (year1): gen ownership_run = 1 if _n == 1

bysort gvkeyFR (year1): replace ownership_run = ownership_run[_n-1] + (gvkey != gvkey[_n-1]) if _n > 1

label var ownership_run "Uniquely identifies, within gvkeyFR, continuous ownership spell by a gvkey"

bysort gvkeyFR ownership_run (year1): replace year1 = year1[1]

bysort gvkeyFR ownership_run (yearN): replace yearN = yearN[_N]

drop ownership_run // No longer needed

duplicates drop // Gets rid of surplus observations


* Compress, Export *

label data "Data for reassigning patent ownership via gvkeyFR per Dyèvre and Seager (2023)"

compress

save "$data/020c_gvkeyFR_to_gvkey.dta", replace


* Export as .csv *

export delimited "$data/dynamicResearcherFriendly.csv", replace