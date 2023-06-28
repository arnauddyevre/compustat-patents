/*

Oliver Seager
o.j.seager@lse.ac.uk
SE 17


Created: 20/01/2023
Last Modified: 07/02/2023


For their patenter_name-ultimate_owner mapping, ABS provide data in (almost) the patenter_name-gvkey-link_year1-link_yearN level. We want it at the patenter_name-gvkey-link_year level, with one observation for each year the link is valid. Because of the structure of the ABS data, though, it won't be quite as easy as it sounds.


Infiles:
- DISCERN_Panal_Data_1980_2015.dta (The full Compustat-based panel of firms constructed and used by Arora, Belenzon, and Sheer (2018a))
- DISCERN_SUB_name_list.dta (The full list of subsidiaries found by ABS, in their preferred structural format)
- permno_gvkey.dta (ABS' crosswalk between their identifier - permno_adj - and gvkeys)


Outfiles:
- 018a_permnoAdjYear_names.dta (The name attached to the permno_adj in each year in ABS' panel)
- 018a_abs_subsName_permnoAdj_year.dta (All subsidiaries found by ABS for the period 1980-2015, attached to the relevant permno_adj)
- 018a_ABSsubsName_gvkey_year.dta (All subsidiaries sourced from ABS, at the subsidiary_name-gvkey-year level. Note that duplicates at the subsidiary_name-year level are *jointly owned* by 2 gvkeys.)


Called .do Files:
None


External Packages:
None


*/

********************************************************************************
**************** GET PRIMARY NAMES ATTACHED TO PERMNO_ADJ-YEAR *****************
********************************************************************************

// We use these entirely for reference.

* Import ABS' Compustat-based Panel *

use "$data/ABS/DISCERN_Panal_Data_1980_2015.dta", clear


* Drop Extraneous Variables *

keep permno_adj conm year // This is all we need

rename conm permno_adj_name // As to not confuse it with other Compustat-sourced names we may merge to


* Export *

label data "" // Remove the ABS labels

compress

save "$data/018a_permnoAdjYear_names.dta", replace



********************************************************************************
***************** GET SUBSIDIARY_ORIG_NAME-PERMNO_ADJ MAPPING ******************
********************************************************************************

* Import ABS Subsidiary Data *

use "$data/ABS/DISCERN_SUB_name_list.dta", clear


* Lengthen from id_name-sample Level to id_name-sample-permno_adj-stint Level * // The id_name-sample is the subsidiary's ID within the ABS data. The permno_adj is the ultimate owner (a listed firm). This will give us multiple observations for a given id_name-sample-permno_adj pair if the permno_adj owns the id_name-sample in two discontinuous stints.

reshape long fyear nyear permno_adj name_acq, i(id_name sample)

drop _j // _j has no meaning

drop if missing(permno_adj) // These are just surplus observations for each id_name


* Clarify Labels *

label var fyear "First year permno_adj owns name_std"
label var nyear "Last year permno_adj owns name_std"


* Reverse Years if First Year of Link After Last Year of Link *

gen fyear_ph = fyear // Placeholder

gen nyear_ph = nyear //

replace fyear = nyear_ph if nyear_ph < fyear_ph

replace nyear = fyear_ph if nyear_ph < fyear_ph

drop nyear_ph fyear_ph // No longer needed


* Get Variable for Each Year the Link is Valid *

gen link_length = nyear - fyear + 1

label var link_length "The number of years for which the id_name-permno_adj link is valid"

quietly summ link_length // Gets maximum link length into `=r(max)'

local loop_end = `=r(max)' - 1 // We treat the first year of the link as year 0, so the last year is link_length - 1

forvalues i = 0/`loop_end'{
	
	gen year`i' = fyear + `i' if fyear + `i' <= nyear // Populates year`i'. Suppose fyear = 1985 and nyear = 1987. Then, year0 = 1985, year1 = 1986, year2 = 1987, and year3, year4, year5, etc. are all missing.
	
}

drop link_length nyear fyear // No longer needed


* Reshape Long to name_std-permno_adj-year Level *

gen obs_nr = _n // Facilitates the reshape

reshape long year, i(obs_nr)

drop if missing(year) // This is just an extraneous year for each id_name-sample-name_std-permno_adj combination

drop obs_nr _j // These don't carry any functional meaning


* Drop Extraneous Variables, Duplicates Created Thereby *

// These pertain to the peculiarities of ABS' matching procedure, which I don't think we necessarily need right now. What we do need is their subsidiary data.

drop id_name sample matched_pat

duplicates drop


* Attach Name to permno_adj-year Pair *

merge m:1 permno_adj year using "$data/018a_permnoAdjYear_names.dta"

bysort permno_adj name_std year (name_acq): replace permno_adj_name = name_acq[_N] if _merge == 1 // Replace any empty names with an arbitrary one from the original subsidiary dataset. Again, the owner's name is just for reference.

drop if _merge == 2 // We don't want permno_adj that don't merge

drop _merge name_acq // No longer needed

duplicates drop // Duplicates created by name_acq. We now have data at the name_std-permno_adj-year level.


* Export *

label data "" // Remove the ABS labels

compress

save "$data/018a_abs_subsName_permnoAdj_year.dta", replace





********************************************************************************
******************** GET SUBSIDIARY_ORIG_NAME-GVKEY MAPPING ********************
********************************************************************************

* Import Panel Data for year-permno_adj -to- gvkey Crosswalk *

use "$data/ABS/DISCERN_Panal_Data_1980_2015.dta", clear


* Keep Only Relevant Variables *

keep permno_adj year gvkey_str // Compustat uses gvkey_str


* Drop if gvkey_str is Missing *

drop if missing(gvkey_str) // We can't use an observation without a gvkey_str to any valuable end here


* Merge to Subsidiary_Orig_Name -to- permno_adj Match *

merge 1:m permno_adj year using "$data/018a_abs_subsName_permnoAdj_year.dta" // Makes sense that there are a lot of unmerged firms from the master. We deal with unmerged firms from the using below.


* Export Merged Data *

// Below, we try again to merge some of the observations from the using. First, we export everything that is good to go.

preserve

keep if _merge == 3

drop permno_adj permno_adj_name _merge // No longer needed

rename gvkey_str gvkey // Per Compustat

save "$data/018a_tempMergedSubs.dta", replace

restore


* Retain Subsidiary-Years Unmerged to gvkeys *

keep if _merge == 2

drop _merge permno_adj_name gvkey_str // Either not needed or empty


* Attempt to Merge Unmerged Subsidiary-Years to gvkeys Using ABS' Crosswalk Document *

joinby permno_adj using "$data/ABS/permno_gvkey.dta", unmatched(both) // We *have* to do a joinby here - the using data is wide on dates and in a minority of cases a single permno_adj maps to multiple gvkeys

tabulate _merge // All from master merge, which is nice.

drop if _merge == 2 // permno_adj-gvkey mappings that aren't relevant for our subsidiaries

drop _merge // No longer needed - all merged.


* Get Conservative Start/End Dates for Each Link *

// ABS aren't explicit on what the year1 and yearn variables mean, so we draw conservative boundaries here.

egen year1_cons = rowmax(fyear1_adjust min_y_permno)

label var year1_cons "Maximum of fyear1_adjust, min_y_permno"

egen yearn_cons = rowmin(fyearn_adjust max_y_permno)

label var yearn_cons "Minimum of fyearn_adjust, max_y_permno"


* Drop Extemporaneous Mappings *

// We drop if the year is before the start of the permno_adj-gvkey link or after the end of the permno_adj-gvkey link

drop if year <= year1_cons | year >= yearn_cons


* Drop Extraneous Variables *

keep name_std year gvkey_str


* Rename gvkey to Align with Compustat *

rename gvkey_str gvkey


* Append Subsidiaries Merged to gvkeys via the ABS Panel Data *

append using "$data/018a_tempMergedSubs.dta"


* Compress, Export *

label data "" // Remove the ABS labels

compress

save "$data/018a_ABSsubsName_gvkey_year.dta", replace


* Delete Temporary File Containing Subsidiaries Merged to gvkeys via the ABS Panel Data *

erase "$data/018a_tempMergedSubs.dta"