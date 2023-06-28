/*

Oliver Seager
o.j.seager@lse.ac.uk
SE 17


Created: 04/04/2023
Last Modified: 15/05/2023


The purpose of this script is to map gvkey-years to their "ultimate owner" gvkeys, which assists in the centralisation of the knowledge base of a corporate entity at a given time under its highest-level listed company in Compustat.


Infiles:
- effectiveAcq_listedListed.csv (A list of listed-acquires-private "effective acquisitions", with gvkey of the acquiring firm, gvkey of the acquired firm, year of acquisition, and type of transaction. Constructed from several sources.)
- cstat_1950_2022.dta (A complete Compustat Annual Fundamentals dataset from 1950-2022, with company name, CUSIP, SIC, country codes for incorporation and location, stock exchange codes, common shares traded, # employees, nominal sales, nominal research and development expenditure)


Outfiles:
- 019d_listedListed_EA.dta (A list of listed-listed "effective acquisition" M&A events in terms of gvkeys)
- 019d_gvkeyYearGvkey_immediate.dta (A list of *immediate* child-parent relationships between gvkeys, at the gvkey-gvkey-year level)
- 019d_chainsOfOwnership.dta (A list of all chains of ownership between gvkeys, with years of validity and an indicator on later divorce from parent for each constituent member)
- 019d_whoOwnsWhomAndWhen_gvkeys.dta (A list of child-ultimate_parent relationships between gvkeys, at the gvkey-gvkey level)


Called .do Files:
None


External Packages:
None


*/

********************************************************************************
***************** GET LIST OF LISTED-LISTED M&A EVENTS TO .dta *****************
********************************************************************************

* Import List of Listed-Listed "Effective Acquisition" M&A Events *

import delimited "$orig/Ollie's M&A File/effectiveAcq_listedListed.csv", clear varnames(1) stringcols(1 2)


* Drop if Event Occurs after 2020 *

drop if year > 2020


* Label Variables *

label var gvkey_primary "gvkey of effective acquiror"

label var gvkey_secondary "gvkey of effectively acquired firm"

label var year "Year in which effective acquisition takes place"

label var source "Source of data on effective acquisition"

label var type "Type of M&A or accounting event"


* Compress, Export *

sort gvkey_primary gvkey_secondary year

compress

save "$data/019d_listedListed_EA.dta", replace





********************************************************************************
************* GET IMMEDIATE GVKEY-GVKEY LINKS AT GVKEY-YEAR LEVEL **************
********************************************************************************

* Import Listed-Listed "Effective Acquisition" Data *

use "$data/019d_listedListed_EA.dta", clear


* Drop Source, Type *

drop source type // This isn't relevant for the mapping


* Get Length of Link for Each Link *

bysort gvkey_secondary (year): gen linktime = year[_n+1] - year // The number of years for which the link runs; populates where gvkey_primary is not the last gvkey that gvkey_secondary maps to

replace linktime = 2021 - year if missing(linktime) // The number of years for which the link runs; populates where gvkey_primary is the last gvkey that gvkey_secondary maps to

label var linktime "Number of years for which link is valid"


* Expand to gkvey_secondary-year-gvkey_primary Level *

egen link_id = group(gvkey_primary gvkey_secondary year) // We have to add year for the sake of Viacom, which is spun-off from CBS and then reacquired, so there are two periods for which CBS owns Viacom 

label var link_id "Unique identifier of the link between gvkey_primary and gvkey_secondary"

expand linktime // Creates an observation for each year that the link is valid

bysort link_id: replace year = year[_n-1] + 1 if _n > 1 // Re-populates year values to give one observation for each year of the link. Note that initially all observations have the same year value

label var year "Year for which link is valid" // This variable takes on a new meaning now

drop linktime link_id // No longer needed


* Save Immediate Links *

save "$data/019d_gvkeyYearGvkey_immediate.dta", replace


/*
The below code tests for cycles in the immediate links data...

use "$data/019d_gvkeyYearGvkey_immediate.dta", clear
forvalues i = 3/12{
	local iLess2 = `i' - 2
	rename gvkey_secondary gvkey`iLess2'
	rename gvkey_primary gvkey_secondary
	merge m:1 gvkey_secondary year using "$data/019d_gvkeyYearGvkey_immediate.dta", keep(1 3)
	replace gvkey_primary = gvkey_secondary if missing(gvkey_primary)
	drop _merge
}
rename gvkey_primary gvkey12
rename gvkey_secondary gvkey11
order gvkey1 gvkey2 gvkey3 gvkey4 gvkey5 gvkey6 gvkey7 gvkey8 gvkey9 gvkey10 gvkey11 gvkey12
forvalues i = 12(-1)2{
	local iLess1 = `i' - 1
	replace gvkey`i' = "" if gvkey`i' == gvkey`iLess1'
}
list if !missing(gvkey12) // Should list nothing if there are no cycles
*/





********************************************************************************
******************* MAP GVKEY-YEARS TO ULTIMATE OWNER GVKEYS *******************
********************************************************************************

* Import Compustat Data *

use "$orig/Compustat/cstat_1950_2022.dta", clear


* Reduce to gvkey Level *

keep gvkey

duplicates drop


* Create 71 Years for Each gvkey *

expand 71 // We initially want a gvkey-year -to- gvkey mapping to for each of the years 1950-2020

bysort gvkey: gen year = _n + 1949 // Gets years 1950-2020 for each observation

label var year "Year in which mapping is valid"


* Merge to Immediate Links for Parentage *

rename gvkey gvkey_secondary

merge m:1 gvkey_secondary year using "$data/019d_gvkeyYearGvkey_immediate.dta"
/*

    Result                      Number of obs
    -----------------------------------------
    Not matched                     2,931,202
        from master                 2,931,202  (_merge==1) -- The gvkey-years that map to their own gvkey
        from using                          0  (_merge==2) -- Perforce, all gvkey-year to gvkey mappings concern gvkeys that feature in Compustat

    Matched                            36,740  (_merge==3) -- The gvkey-years that feature in our immediate links dataset (includes 289 gvkey-years which map to their own gvkeys)

*/
drop if _merge == 2 // Shouldn't drop anything

replace gvkey_primary = gvkey_secondary if missing(gvkey_primary) // Such that gvkey-years that should map to themselves do map to themselves

drop _merge


* Merge to Immediate Links for Grandparentage  *

rename gvkey_secondary gvkey_tertiary // This is the gvkey which, for each year, we want to map to its ultimate owner 

rename gvkey_primary gvkey_secondary // To facilitate the merge

merge m:1 gvkey_secondary year using "$data/019d_gvkeyYearGvkey_immediate.dta"
/*

    Result                      Number of obs
    -----------------------------------------
    Not matched                     2,997,947
        from master                 2,963,944  (_merge==1) -- The gvkey-years that already map to an ultimate parent (in most cases the gvkey-year maps to its own gvkey)
        from using                     34,003  (_merge==2) -- Every observation from the immediate links that doesn't provide parentage for any parents in our present mapping.

    Matched                             3,998  (_merge==3) -- The gvkey-year to gvkey links that have a superior link in the given year (includes 418 gvkey-years which map to their own gvkeys).
    -----------------------------------------

*/
drop if _merge == 2

replace gvkey_primary = gvkey_secondary if missing(gvkey_primary) // We want to keep only the endpoints of the telescopic mapping, so we make sure these are populated

replace gvkey_secondary = "" if gvkey_primary == gvkey_secondary

drop _merge // No longer neeeded


* Merge to Immediate Links for Great-Grandparentage *

rename gvkey_tertiary gvkey_quaternary // This is the gvkey which, for each year, we want to map to its ultimate owner 
rename gvkey_secondary gvkey_tertiary

rename gvkey_primary gvkey_secondary // To facilitate the merge

merge m:1 gvkey_secondary year using "$data/019d_gvkeyYearGvkey_immediate.dta"
/*

    Result                      Number of obs
    -----------------------------------------
    Not matched                     3,003,201
        from master                 2,967,086  (_merge==1) -- The gvkey-years that already map to an ultimate parent (in most cases the gvkey-year maps to its own gvkey)
        from using                     36,115  (_merge==2) -- Every observation from the immediate links that doesn't provide parentage for any parents in our present mapping.

    Matched                               856  (_merge==3) -- The gvkey-year to gvkey links that still have a superior link in the given year (includes 448 gvkey-years which map to their own gvkeys)
    -----------------------------------------

*/
drop if _merge == 2

replace gvkey_primary = gvkey_secondary if missing(gvkey_primary)

replace gvkey_secondary = "" if gvkey_primary == gvkey_secondary

drop _merge // No longer needed


* Merge to Immediate Links for Great-Great-Grandparentage *

rename gvkey_quaternary gvkey_quinary // This is the gvkey which, for each year, we want to map to its ultimate owner 
rename gvkey_tertiary gvkey_quaternary
rename gvkey_secondary gvkey_tertiary

rename gvkey_primary gvkey_secondary // To facilitate the merge

merge m:1 gvkey_secondary year using "$data/019d_gvkeyYearGvkey_immediate.dta"
/*

    Result                      Number of obs
    -----------------------------------------
    Not matched                     3,003,875
        from master                 2,967,450  (_merge==1) -- The gvkey-years that already map to an ultimate parent (in most cases the gvkey-year maps to its own gvkey)
        from using                     36,425  (_merge==2) -- Every observation from the immediate links that doesn't provide parentage for any parents in our present mapping.

    Matched                               492  (_merge==3) -- The gvkey-year to gvkey links that still have a superior link in the given year (includes 462 gvkey-years which map to their own gvkey)
    -----------------------------------------

*/
drop if _merge == 2

replace gvkey_primary = gvkey_secondary if missing(gvkey_primary)

replace gvkey_secondary = "" if gvkey_primary == gvkey_secondary

drop _merge

// The above is the last set of parentage to distinct gvkeys


* Generate Dataset on Chain of Ownership *

** Preserve **

preserve


	** Rename, Relabel, Reorder Variables **
	
	rename gvkey_secondary gvkeyIntTier1
	
	rename gvkey_tertiary gvkeyIntTier2
	
	rename gvkey_quaternary gvkeyIntTier3
	
	rename gvkey_quinary gvkey_secondary
	
	label var gvkeyIntTier1 "Great-grandparent of gvkey_secondary, ultimately owned by gvkey_primary"
	
	label var gvkeyIntTier2 "Grandparent of gvkey_secondary, ultimately owned by gvkey_primary"
	
	label var gvkeyIntTier3 "Parent of gvkey_secondary, ultimately owned by gvkey_primary"
	
	label var gvkey_primary "Ultimate owner of gvkey_secondary"
	
	label var gvkey_secondary "gvkey ultimately owned by gvkey_primary"
	
	order gvkey_primary gvkey_secondary year gvkeyIntTier1 gvkeyIntTier2 gvkeyIntTier3
	
	
	** Reduce to gvkey_primary x gvkey_secondary x Ownership Run Level **
	
	bysort gvkey_primary gvkey_secondary (year): gen ownership_run = 1 if _n == 1
	
	bysort gvkey_primary gvkey_secondary (year): replace ownership_run = ownership_run[_n-1] + (year != year[_n-1] + 1 | gvkeyIntTier1 != gvkeyIntTier1[_n-1] | gvkeyIntTier2 != gvkeyIntTier2[_n-1] | gvkeyIntTier3 != gvkeyIntTier3[_n-1]) if _n > 1
	
	label var ownership_run "ID for run of continuous ownership, unique within gvkey_primary-gvkey_secondary"
	
	bysort gvkey_primary gvkey_secondary ownership_run: egen year1 = min(year)
	
	label var year1 "First year of continuous ownership of gvkey_secondary by gvkey_primary"
	
	bysort gvkey_primary gvkey_secondary ownership_run: egen yearN = max(year)
	
	label var yearN "Last year of continuous ownership of gvkey_secondary by gvkey_primary"
	
	drop year ownership_run // No longer needed
	
	duplicates drop
	
	
	** Get "Number of Ownership Spells" for gvkey_secondary **
	
	bysort gvkey_secondary: gen nrOwnershipSpells = _N
	
	label var nrOwnershipSpells "Number of different ownership structures of gvkey_secondary"
	
	quietly summ nrOwnershipSpells // Gets maximal number of ownership spells into `=r(max)'
	
	local maxSpell = `=r(max)'
	
	local maxPenultimateSpell = `=r(max)' - 1
	
	drop nrOwnershipSpells // No longer needed
	
	
	** Get "Later Divorced" Variable for gvkey_secondary **
	
	gen gvkey_secondary_ip = gvkey_primary if missing(gvkeyIntTier3)
	
	replace gvkey_secondary_ip = gvkeyIntTier3 if !missing(gvkeyIntTier3)
	
	label var gvkey_secondary_ip "Immediate parent of gvkey_secondary"
	
	gen gvkS_laterDivorced = 0 // Initiate variable
	
	forvalues i = 1/`maxPenultimateSpell'{ // The spell under consideration for the "later divorced variable" is `i'
		
		local iPlusOne = `i' + 1
		
		forvalues j = `iPlusOne'/`maxSpell'{ // All future spells, which must each be considered for the later divorced variable
			
			bysort gvkey_secondary (year1): replace gvkS_laterDivorced = 1 if `i' == _n & `j' <= _N & gvkey_secondary_ip != gvkey_primary[`j'] & gvkey_secondary_ip != gvkeyIntTier1[`j'] & gvkey_secondary_ip != gvkeyIntTier2[`j'] & gvkey_secondary_ip != gvkeyIntTier3[`j'] & gvkey_secondary != gvkey_secondary_ip // If the immediate parent does not feature in the ownership structure in ownership spell `j', then we mark gvkey_secondary as later divorced from its immediate parent
			
		}
		
	}
	
	label var gvkS_laterDivorced "gvkey_secondary later divorced from immediate parent"
	
	drop gvkey_secondary_ip
	
	
	** Get "Later Divorced" Variable for gvkeyIntTier3 **
	
	gen gvkeyIntTier3_ip = gvkey_primary if !missing(gvkeyIntTier3) & missing(gvkeyIntTier2)
	
	replace gvkeyIntTier3_ip = gvkeyIntTier2 if !missing(gvkeyIntTier3) & !missing(gvkeyIntTier2)
	
	label var gvkeyIntTier3_ip "Immediate parent of gvkeyIntTier3"
	
	gen gvkT3_laterDivorced = 0 if !missing(gvkeyIntTier3) & gvkS_laterDivorced == 0 // Initiate variable. If a subsidiary is later divorced this isn't relevant.
	
	forvalues i = 1/`maxPenultimateSpell'{ // The spell under consideration for the "later divorced variable" is `i'
		
		local iPlusOne = `i' + 1
		
		forvalues j = `iPlusOne'/`maxSpell'{ // All future spells, which must each be considered for the later divorced variable
			
			bysort gvkey_secondary (year1): replace gvkT3_laterDivorced = 1 if `i' == _n & `j' <= _N & gvkeyIntTier3_ip != gvkey_primary[`j'] & gvkeyIntTier3_ip != gvkeyIntTier1[`j'] & gvkeyIntTier3_ip != gvkeyIntTier2[`j'] & gvkeyIntTier3_ip != gvkeyIntTier3[`j'] & !missing(gvkeyIntTier3) & gvkS_laterDivorced == 0 // If the immediate parent does not feature in the ownership structure in ownership spell `j', then we mark gvkeyIntTier3 as later divorced from its immediate parent
			
		}
		
	}
	
	label var gvkT3_laterDivorced "gvkeyIntTier3 later divorced from immediate parent"
	
	drop gvkeyIntTier3_ip
	
	
	** Get "Later Divorced" Variable for gvkeyIntTier2 **
	
	gen gvkeyIntTier2_ip = gvkey_primary if !missing(gvkeyIntTier2) & missing(gvkeyIntTier1)
	
	replace gvkeyIntTier2_ip = gvkeyIntTier1 if !missing(gvkeyIntTier2) & !missing(gvkeyIntTier1)
	
	label var gvkeyIntTier2_ip "Immediate parent of gvkeyIntTier2"
	
	gen gvkT2_laterDivorced = 0 if !missing(gvkeyIntTier2) & gvkT3_laterDivorced == 0 & gvkS_laterDivorced == 0  // Initiate variable
	
	forvalues i = 1/`maxPenultimateSpell'{ // The spell under consideration for the "later divorced variable" is `i'
		
		local iPlusOne = `i' + 1
		
		forvalues j = `iPlusOne'/`maxSpell'{ // All future spells, which must each be considered for the later divorced variable
			
			bysort gvkey_secondary (year1): replace gvkT2_laterDivorced = 1 if `i' == _n & `j' <= _N & gvkeyIntTier2_ip != gvkey_primary[`j'] & gvkeyIntTier2_ip != gvkeyIntTier1[`j'] & gvkeyIntTier2_ip != gvkeyIntTier2[`j'] & gvkeyIntTier2_ip != gvkeyIntTier3[`j'] & !missing(gvkeyIntTier2) & gvkT3_laterDivorced == 0  & gvkS_laterDivorced == 0 // If the immediate parent does not feature in the ownership structure in ownership spell `j', then we mark gvkeyIntTier2 as later divorced from its immediate parent
			
		}
		
	}
	
	label var gvkT2_laterDivorced "gvkeyIntTier2 later divorced from immediate parent"
	
	drop gvkeyIntTier2_ip
	
	
	** Get "Later Divorced" Variable for gvkeyIntTier1 **
	
	gen gvkeyIntTier1_ip = gvkey_primary if !missing(gvkeyIntTier1)
	
	label var gvkeyIntTier1_ip "Immediate parent of gvkeyIntTier1"
	
	gen gvkT1_laterDivorced = 0 if !missing(gvkeyIntTier1) & gvkT2_laterDivorced == 0 & gvkT3_laterDivorced == 0 & gvkS_laterDivorced == 0  // Initiate variable
	
	forvalues i = 1/`maxPenultimateSpell'{ // The spell under consideration for the "later divorced variable" is `i'
		
		local iPlusOne = `i' + 1
		
		forvalues j = `iPlusOne'/`maxSpell'{ // All future spells, which must each be considered for the later divorced variable
			
			bysort gvkey_secondary (year1): replace gvkT1_laterDivorced = 1 if `i' == _n & `j' <= _N & gvkeyIntTier1_ip != gvkey_primary[`j'] & gvkeyIntTier1_ip != gvkeyIntTier1[`j'] & gvkeyIntTier1_ip != gvkeyIntTier2[`j'] & gvkeyIntTier1_ip != gvkeyIntTier3[`j'] & !missing(gvkeyIntTier1) & gvkT2_laterDivorced == 0 & gvkT3_laterDivorced == 0 & gvkS_laterDivorced == 0 // If the immediate parent does not feature in the ownership structure in ownership spell `j', then we mark gvkeyIntTier1 as later divorced from its immediate parent
			
		}
		
	}
	
	label var gvkT1_laterDivorced "gvkeyIntTier1 later divorced from immediate parent"
	
	drop gvkeyIntTier1_ip
	
	
	** Order, Compress, Export **
	
	order gvkey_primary gvkey_secondary year1 yearN gvkeyIntTier1 gvkeyIntTier2 gvkeyIntTier3 gvkS_laterDivorced gvkT1_laterDivorced gvkT2_laterDivorced gvkT3_laterDivorced
	
	compress
	
	save "$data/019d_chainsOfOwnership.dta", replace
	
	
** Restore **

restore
	

* Drop Intermediary gvkeys *

drop gvkey_secondary gvkey_tertiary gvkey_quaternary // We no longer need these


* Rename, Relabel Variables *

rename gvkey_quinary gvkey

rename gvkey_primary gvkey_uo

label var gvkey "gvkey which maps to gvkey_uo in given year"

label var gvkey_uo "Ultimate owner of gvkey in given year"


* Establish "Runs of Ownership" *

// Suppose company A is independent from 1970-1979, then owned by company B for 1980-1989, then independent again from 1990-present. If we just take minimum and maximum years for the mappings A-A and A-B, we'll get that A maps to A from 1970 to Present and to B from 1980 to 1989. This is no good. We create an "Ownership Run" variable.

bysort gvkey (year): gen ownership_run = 1 if _n == 1 // Note that gvkey-year uniquely identifies observations, and the data contain no missing values.

bysort gvkey (year): replace ownership_run = ownership_run[_n-1] + (gvkey_uo != gvkey_uo[_n-1]) if _n > 1 // Iteratively populate ownership_run values. For an example of how this works, look at gvkey == "013921".

label var ownership_run "Identifier of the temporal run of ownership of gvkey"


* Reduce to from gvkey-gvkey-year Level to gvkey-gvkey-ownership_run Level *

bysort gvkey ownership_run: egen year1 = min(year)

label var year1 "First year in which gvkey maps to gvkey_uo"

bysort gvkey ownership_run: egen yearN = max(year)

label var yearN "Last year in which gvkey maps to gvkey_uo"

drop year ownership_run // year is the only remaining variable at the gvkey-gvkey-year level. We don't actually need the ownership_run variable

duplicates drop


* Export *

sort gvkey year1

compress

save "$data/019d_whoOwnsWhomAndWhen_gvkeys.dta", replace