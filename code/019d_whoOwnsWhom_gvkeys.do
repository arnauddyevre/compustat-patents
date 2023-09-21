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

import delimited "$orig/Ollie's M&A File/effectiveAcq_listedListed_final.csv", clear varnames(1) stringcols(1 2)


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


/*
use "$data/019e_dynamicNamesClean_matched.dta", clear
keep gvkey
duplicates drop
rename gvkey gvkey_secondary
merge 1:m gvkey_secondary using "$data/019d_chainsOfOwnership.dta", keep(1 3)
drop _merge
keep gvkey_secondary gvkey_primary gvkeyIntTier1 gvkeyIntTier2 gvkeyIntTier3
rename gvkey_secondary gvkey0
rename gvkey_primary gvkey1
rename gvkeyIntTier1 gvkey2
rename gvkeyIntTier2 gvkey3
rename gvkeyIntTier3 gvkey4
gen _i = _n
reshape long gvkey, i(_i)
drop _i _j
drop if missing(gvkey)
duplicates drop
append using "$data/019d_listedListed_EA.dta", gen(ao)
replace gvkey = gvkey_primary if missing(gvkey)
bysort gvkey: egen dog = min(ao)
gen gpR = 1 - dog if ao == 1
replace gvkey = "" if ao == 1
drop dog
replace gvkey = gvkey_secondary if missing(gvkey)
bysort gvkey: egen dog = min(ao)
gen gsR = 1 - dog if ao == 1
replace gvkey = "" if ao == 1
drop dog
keep if ao == 1 & (gsR == 1 | gpR == 1)

drop gvkey ao gpR gsR

duplicates drop

replace source = "ABS" if source == "ABS - Automated" | source == "ABS - Manual"
replace source = "6-character CUSIP" if source == "6-character CUSIP - Manual"
replace source = "CRSP/Compustat" if source == "CRSP/Compustat - Automated" | source == "CRSP/Compustat - Manual"
replace source = "Clean Name Duplicates" if source == "Clean Name Duplicates - Manual"
replace source = "SDC Platinum" if source == "SDC Platinum - Automated" | source == "SDC Platinum - Manual"
replace source = "Subsidiary Data" if source == "Subsidiary Data - Automated" | source == "Subsidiary Data - Manual"

export delimited "$orig/Ollie's M&A File/effectiveAcq_listedListed_final.csv", replace

insobs 39

replace year = 2008 if _n == _N - 38
replace gvkey_primary = "184899" if _n == _N - 38
replace gvkey_secondary = "012796A" if _n == _N - 38
replace source = "General Research" if _n == _N - 38
replace type = "Reverse Spin-Off" if _n == _N - 38
replace year = 1950 if _n == _N - 37
replace gvkey_primary = "012796" if _n == _N - 37
replace gvkey_secondary = "012796A" if _n == _N - 37
replace source = "General Research" if _n == _N - 37
replace type = "Dummy Subsidiary Listing" if _n == _N - 37
replace year = 2012 if _n == _N - 38
replace year = 2002 if _n == _N - 36
replace gvkey_primary = "156819" if _n == _N - 36
replace gvkey_secondary = "008818A" if _n == _N - 36
replace source = "General Research" if _n == _N - 36
replace type = "Reverse Spin-Off" if _n == _N - 36
replace year = 1950 if _n == _N - 35
replace gvkey_primary = "008818" if _n == _N - 35
replace gvkey_secondary = "008818A" if _n == _N - 35
replace source = "General Research" if _n == _N - 35
replace type = "Dummy Subsidiary Listing" if _n == _N - 35
replace gvkey_primary = "171187" if _n == _N - 34
replace gvkey_secondary = "179605A" if _n == _N - 34
replace source = "General Research" if _n == _N - 34
replace type = "Reverse Spin-Off" if _n == _N - 34
replace year = 1950 if _n == _N - 33
replace gvkey_primary = "179605" if _n == _N - 33
replace gvkey_secondary = "179605A" if _n == _N - 33
replace source = "General Research" if _n == _N - 33
replace type = "Dummy Subsidiary Listing" if _n == _N - 33
replace year = 2012 if _n == _N - 32
replace gvkey_primary = "135990" if _n == _N - 32
replace gvkey_secondary = "140033" if _n == _N - 32
replace source = "General Research" if _n == _N - 32
replace type = "Reverse Spin-Off" if _n == _N - 32
replace year = 2010 if _n == _N - 31
replace gvkey_primary = "140033" if _n == _N - 31
replace gvkey_secondary = "140977" if _n == _N - 31
replace source = "General Research" if _n == _N - 31
replace type = "Reverse Spin-Off" if _n == _N - 31
replace year = 1950 if _n == _N - 30
replace gvkey_primary = "005742" if _n == _N - 30
replace gvkey_secondary = "005742A" if _n == _N - 30
replace source = "General Research" if _n == _N - 30
replace type = "Dummy Subsidiary Listing" if _n == _N - 30
replace year = 2003 if _n == _N - 29
replace gvkey_primary = "140977" if _n == _N - 29
replace gvkey_secondary = "005742A" if _n == _N - 29
replace source = "General Research" if _n == _N - 29
replace type = "Reverse Spin-Off" if _n == _N - 29
replace year = 1950 if _n == _N - 28
replace gvkey_primary = "003243" if _n == _N - 28
replace gvkey_secondary = "003243A" if _n == _N - 28
replace source = "General Research" if _n == _N - 28
replace type = "Dummy Subsidiary Listing" if _n == _N - 28
replace year = 2001 if _n == _N - 27
replace gvkey_primary = "062689" if _n == _N - 27
replace gvkey_secondary = "003243A" if _n == _N - 27
replace source = "General Research" if _n == _N - 27
replace type = "Reverse Spin-Off" if _n == _N - 27
replace year = 1950 if _n == _N - 26
replace gvkey_primary = "011218" if _n == _N - 26
replace gvkey_secondary = "011218A" if _n == _N - 26
replace source = "General Research" if _n == _N - 26
replace type = "Dummy Subsidiary Listing" if _n == _N - 26
replace year = 1994 if _n == _N - 25
replace gvkey_primary = "061402" if _n == _N - 25
replace gvkey_secondary = "011218A" if _n == _N - 25
replace source = "General Research" if _n == _N - 25
replace type = "Reverse Spin-Off" if _n == _N - 25
replace year = 1950 if _n == _N - 24
replace gvkey_primary = "009728" if _n == _N - 24
replace gvkey_secondary = "009728A" if _n == _N - 24
replace source = "General Research" if _n == _N - 24
replace type = "Dummy Subsidiary Listing" if _n == _N - 24
replace year = 2018 if _n == _N - 23
replace gvkey_primary = "032014" if _n == _N - 23
replace gvkey_secondary = "009728A" if _n == _N - 23
replace source = "General Research" if _n == _N - 23
replace type = "Reverse Spin-Off" if _n == _N - 23
replace year = 1950 if _n == _N - 22
replace gvkey_primary = "024937" if _n == _N - 22
replace gvkey_secondary = "024937A" if _n == _N - 22
replace source = "General Research" if _n == _N - 22
replace type = "Dummy Subsidiary Listing" if _n == _N - 22
replace year = 2012 if _n == _N - 21
replace gvkey_primary = "122916" if _n == _N - 21
replace gvkey_secondary = "024937A" if _n == _N - 21
replace source = "General Research" if _n == _N - 21
replace type = "Reverse Spin-Off" if _n == _N - 21
replace year = 1950 if _n == _N - 20
replace gvkey_primary = "005639" if _n == _N - 20
replace gvkey_secondary = "005639A" if _n == _N - 20
replace source = "General Research" if _n == _N - 20
replace type = "Dummy Subsidiary Listing" if _n == _N - 20
replace year = 2005 if _n == _N - 19
replace gvkey_primary = "179657" if _n == _N - 19
replace gvkey_secondary = "005639A" if _n == _N - 19
replace source = "General Research" if _n == _N - 19
replace type = "Reverse Spin-Off" if _n == _N - 19
replace year = 1950 if _n == _N - 18
replace gvkey_primary = "004988" if _n == _N - 18
replace gvkey_secondary = "004988A" if _n == _N - 18
replace source = "General Research" if _n == _N - 18
replace type = "Dummy Subsidiary Listing" if _n == _N - 18
replace year = 2015 if _n == _N - 17
replace gvkey_primary = "019574" if _n == _N - 17
replace gvkey_secondary = "004988A" if _n == _N - 17
replace source = "General Research" if _n == _N - 17
replace type = "Reverse Spin-Off" if _n == _N - 17
replace year = 1950 if _n == _N - 16
replace gvkey_primary = "007745" if _n == _N - 16
replace gvkey_secondary = "007745A" if _n == _N - 16
replace source = "General Research" if _n == _N - 16
replace type = "Dummy Subsidiary Listing" if _n == _N - 16
replace year = 1983 if _n == _N - 15
replace gvkey_primary = "013351" if _n == _N - 15
replace gvkey_secondary = "007745A" if _n == _N - 15
replace source = "General Research" if _n == _N - 15
replace type = "Reverse Spin-Off" if _n == _N - 15
replace year = 1950 if _n == _N - 14
replace gvkey_primary = "005342" if _n == _N - 14
replace gvkey_secondary = "005342A" if _n == _N - 14
replace source = "General Research" if _n == _N - 14
replace type = "Dummy Subsidiary Listing" if _n == _N - 14
replace year = 2003 if _n == _N - 13
replace gvkey_primary = "160785" if _n == _N - 13
replace gvkey_secondary = "005342A" if _n == _N - 13
replace source = "General Research" if _n == _N - 13
replace type = "Reverse Spin-Off" if _n == _N - 13
replace year = 2016 if _n == _N - 12
replace gvkey_primary = "100080" if _n == _N - 12
replace gvkey_secondary = "140760" if _n == _N - 12
replace source = "General Research" if _n == _N - 12
replace type = "Merger or Acquisition" if _n == _N - 12
replace year = 1998 if _n == _N - 11
replace gvkey_primary = "140760" if _n == _N - 11
replace gvkey_secondary = "007536A" if _n == _N - 11
replace source = "General Research" if _n == _N - 11
replace type = "Reverse Spin-Off" if _n == _N - 11
replace year = 1967 if _n == _N - 10
replace gvkey_primary = "005776" if _n == _N - 10
replace gvkey_secondary = "005776A" if _n == _N - 10
replace source = "General Research" if _n == _N - 10
replace type = "Dummy Subsidiary Listing" if _n == _N - 10
replace year = 1993 if _n == _N - 9
replace gvkey_primary = "027914" if _n == _N - 9
replace gvkey_secondary = "005776A" if _n == _N - 9
replace source = "General Research" if _n == _N - 9
replace type = "Reverse Spin-Off" if _n == _N - 9
replace year = 1963 if _n == _N - 8
replace gvkey_primary = "026061" if _n == _N - 8
replace gvkey_secondary = "026061A" if _n == _N - 8
replace source = "General Research" if _n == _N - 8
replace type = "Dummy Subsidiary Listing" if _n == _N - 8
replace year = 2007 if _n == _N - 7
replace gvkey_primary = "180402" if _n == _N - 7
replace gvkey_secondary = "026061A" if _n == _N - 7
replace source = "General Research" if _n == _N - 7
replace type = "Reverse Spin-Off" if _n == _N - 7
replace year = 1963 if _n == _N - 6
replace gvkey_primary = "026061" if _n == _N - 6
replace gvkey_secondary = "026061B" if _n == _N - 6
replace source = "General Research" if _n == _N - 6
replace type = "Dummy Subsidiary Listing" if _n == _N - 6
replace year = 2018 if _n == _N - 5
replace gvkey_primary = "036691" if _n == _N - 5
replace gvkey_secondary = "026061B" if _n == _N - 5
replace source = "General Research" if _n == _N - 5
replace type = "Reverse Spin-Off" if _n == _N - 5
replace year = 1950 if _n == _N - 4
replace gvkey_primary = "007536" if _n == _N - 4
replace gvkey_secondary = "007536A" if _n == _N - 4
replace source = "General Research" if _n == _N - 4
replace type = "Dummy Subsidiary Listing" if _n == _N - 4
replace year = 1962 if _n == _N - 3
replace gvkey_primary = "001254" if _n == _N - 3
replace gvkey_secondary = "001254A" if _n == _N - 3
replace source = "General Research" if _n == _N - 3
replace type = "Dummy Subsidiary Listing" if _n == _N - 3
replace year = 2011 if _n == _N - 2
replace gvkey_primary = "011756" if _n == _N - 2
replace gvkey_secondary = "001254A" if _n == _N - 2
replace source = "General Research" if _n == _N - 2
replace type = "Reverse Spin-Off" if _n == _N - 2
replace year = 1960 if _n == _N - 1
replace gvkey_primary = "002812" if _n == _N - 1
replace gvkey_secondary = "002812A" if _n == _N - 1
replace source = "General Research" if _n == _N - 1
replace type = "Dummy Subsidiary Listing" if _n == _N - 1
replace year = 1991 if _n == _N
replace gvkey_primary = "061780" if _n == _N
replace gvkey_secondary = "002812A" if _n == _N
replace source = "General Research" if _n == _N
replace type = "Reverse Spin-Off" if _n == _N

replace year = 1950 if type == "Dummy Subsidiary Listing"

drop if strpos(gvkey_secondary, "A") == 0 & strpos(gvkey_secondary, "B") == 0 & type == "Reverse Spin-Off"

duplicates drop

compress
save "$data/019X_EAfinal.dta", replace
*/





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
    Not matched                     2,930,373
        from master                 2,930,373  (_merge==1) -- The gvkey-years that map to their own gvkey
        from using                          0  (_merge==2) -- Perforce, all gvkey-year to gvkey mappings concern gvkeys that feature in Compustat

    Matched                            37,569  (_merge==3) -- The gvkey-years that feature in our immediate links dataset (includes 168 gvkey-years which map to their own gvkeys)

*/
drop if _merge == 2 // Shouldn't drop anything

rename gvkey_primary gvkey_1

rename gvkey_secondary gvkey_2

replace gvkey_1 = gvkey_2 if missing(gvkey_1) // Such that gvkey-years that should map to themselves do map to themselves

drop _merge // No longer needed


* Merge Iteratively to Levels Above Parentage *

local generationCounter = 2 // Counts the number of generations in the dataset

while(1){ // We continue, break out of this loop
	
	** Merge to Immediate Links for Another Generation **
	
	rename gvkey_1 gvkey_secondary // Facilitates the merge
	
	merge m:1 gvkey_secondary year using "$data/019d_gvkeyYearGvkey_immediate.dta"
	
	drop if _merge == 2 // Every observation from the immediate links that doesn't provide parentage for any top-level gvkey in our present mapping.
	
	
	** Verify Whether to End Loop **
	
	quietly count if _merge == 3 & gvkey_primary != gvkey_secondary // Will be zero if we're now just merging self-parentage, which means we need to break out of the loop
	
	
	** End Loop When Necessary **
	
	if(`=r(N)' == 0){
		
		drop gvkey_primary _merge // Not informative or not necessary
		
		rename gvkey_secondary gvkey_1 // To reflect the proper placement of this gvkey in the corporate heirarchy
		
		continue, break
		
	}
	
	drop _merge // No longer needed
	
	
	** Retain Endpoints, Drop One Party in Self-Linkages **
	
	replace gvkey_primary = gvkey_secondary if missing(gvkey_primary) // We want to keep only the endpoints of the telescopic mapping, so we make sure these are populated

	replace gvkey_secondary = "" if gvkey_primary == gvkey_secondary
	
	
	** Increase Number of Generations **
	
	local generationCounter = `generationCounter' + 1
	
	
	** Rename gvkeys to Reflect New Heirarchy **
	
	forvalues i = `generationCounter'(-1)3{
		
		local iLessOne = `i' - 1
		
		rename gvkey_`iLessOne' gvkey_`i'
		
	}
	
	rename gvkey_secondary gvkey_2
	
	rename gvkey_primary gvkey_1
	
}


* Generate Dataset on Chain of Ownership *

** Preserve **

preserve


	** Rename, Relabel, Reorder Variables **
	
	rename gvkey_1 gvkey_primary // The gvkey at the top of the corporate heirarchy
	
	rename gvkey_`generationCounter' gvkey_secondary // The gvkey at the bottom of the corporate heirarchy
	
	label var gvkey_primary "Ultimate owner of gvkey_secondary"
	
	label var gvkey_secondary "gvkey ultimately owned by gvkey_primary"
	
	local loopCounter = 0
	
	local orderString = "gvkey_primary gvkey_secondary year" // For iteratively updating and then ordering the variables
	
	forvalues i = `=(`generationCounter'-1)'(-1)2{
		
		local loopCounter = `loopCounter' + 1 // Used to name the variables
		
		local iLessOne = `i' - 1 // Also used to name the variables
		
		rename gvkey_`i' gvkeyIntTier`iLessOne'
		
		if(`loopCounter' == 1){
		
			label var gvkeyIntTier`iLessOne' "Intermediary gvkey 1 generation above gvkey_secondary"
			
		}
		
		else{
			
			label var gvkeyIntTier`iLessOne' "Intermediary gvkey `loopCounter' generations above gvkey_secondary"
			
		}
		
		local orderString = "`orderString' gvkeyIntTier`loopCounter'"
		
	}
	
	order `orderString'
	
	
	** Reduce to gvkey_primary x gvkey_secondary x Ownership Run Level **
	
	bysort gvkey_primary gvkey_secondary (year): gen ownership_run = 1 if _n == 1
	
	local ownershipChangeCondition = "year != year[_n-1] + 1"
	
	quietly ds gvkeyIntTier* // Gets all the intermediate tier variables into `=r(varlist)'
	
	foreach V in `=r(varlist)'{ // Loop through all the intermediate tiers
		
		local ownershipChangeCondition = "`ownershipChangeCondition' | `V' != `V'[_n-1]"
		
	}
	
	bysort gvkey_primary gvkey_secondary (year): replace ownership_run = ownership_run[_n-1] + (`ownershipChangeCondition') if _n > 1
	
	label var ownership_run "ID for run of given corp. structure, unique within gvkey_primary-gvkey_secondary"
	
	bysort gvkey_primary gvkey_secondary ownership_run: egen year1 = min(year)
	
	label var year1 "First year of continuous run of given corporate structure"
	
	bysort gvkey_primary gvkey_secondary ownership_run: egen yearN = max(year)
	
	label var yearN "Last year of continuous run of given corporate structure"
	
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
	
	gen gvkey_secondary_ip = gvkey_primary if missing(gvkeyIntTier`=(`generationCounter'-2)')
	
	replace gvkey_secondary_ip = gvkeyIntTier`=(`generationCounter'-2)' if !missing(gvkeyIntTier`=(`generationCounter'-2)')
	
	label var gvkey_secondary_ip "Immediate parent of gvkey_secondary"
	
	gen gvkS_laterDivorced = 0 // Initiate variable
	
	local replaceCodeCondition = "gvkey_secondary != gvkey_secondary_ip" // Used for the "Later Divorced" variable
	
	forvalues m = 1/`=(`generationCounter'-2)'{ // Within this loop we just write some code for the conditions for which we replace gvkS_laterDivorced with 1
		
		local replaceCodeCondition = "`replaceCodeCondition' & gvkey_secondary_ip != comparison_gvkeyIntTier`m'"
		
	}
	
	forvalues i = 1/`=(`maxSpell' - 1)'{ // The spell under consideration for the "later divorced variable" is `i'
		
		local iPlusOne = `i' + 1
		
		forvalues j = `iPlusOne'/`maxSpell'{ // All future spells, which must each be considered for the later divorced variable
		
			forvalues k = 1/`=(`generationCounter'-2)'{ // We use this loop to create variables for intermediary gvkeys from the future spell (j) under consideration
				
				bysort gvkey_secondary (year1): gen comparison_gvkeyIntTier`k' = gvkeyIntTier`k'[`j']
				
				label var comparison_gvkeyIntTier`k' "gvkey `=(`generationCounter' - 1 - `k')' level(s) above gvkey_secondary, `j' spells in the future"
				
			}
			
			bysort gvkey_secondary (year1): replace gvkS_laterDivorced = 1 if `i' == _n & `j' <= _N & gvkey_secondary_ip != gvkey_primary[`j'] & `replaceCodeCondition' // If the immediate parent does not feature in the ownership structure in ownership spell `j', then we mark gvkey_secondary as later divorced from its immediate parent
			
			drop comparison_gvkeyIntTier* // Drop all "comparison of future intermediary gvkeys" variables for the next iteration
			
		}
		
	}
	
	label var gvkS_laterDivorced "gvkey_secondary later divorced from immediate parent"
	
	drop gvkey_secondary_ip
	
	
	** Get "Later Divorced" Variable for Intermediary gvkeys **
	
	forvalues i = `=(`generationCounter'-2)'(-1)1{

		*** Generate Immediate Parent Variable ***
		
		if(`i' > 1){
		
			gen gvkeyIntTier`i'_ip = gvkey_primary if !missing(gvkeyIntTier`i') & missing(gvkeyIntTier`=(`i'-1)')
			
			replace gvkeyIntTier`i'_ip = gvkeyIntTier`=(`i'-1)' if !missing(gvkeyIntTier`i') & !missing(gvkeyIntTier`=(`i'-1)')
			
		}
		
		else{
			
			gen gvkeyIntTier`i'_ip = gvkey_primary if !missing(gvkeyIntTier`i')
			
		}
		
		label var gvkeyIntTier`i'_ip "Immediate parent of gvkeyIntTier`i'"
		
		
		*** Initiate Later Divorced Variable ***

		local ildCondition = "gvkS_laterDivorced == 0" // Condition used to initiate "Later Divorced" varaible
		
		if(`i' < `generationCounter' - 2){ // Appends Booleans to the condition used to initiate the "Later Divorced" variable
			
			forvalues j = `=(`generationCounter' - 2)'(-1)`=(`i' + 1)'{
				
				local ildCondition = "gvkT`j'_laterDivorced == 0 & `ildCondition'"
				
			}
			
		}
		
		gen gvkT`i'_laterDivorced = 0 if !missing(gvkeyIntTier`i') & `ildCondition'
		
		
		*** Replace Later Divorced Variable Where Appropriate ***

		local replaceCodeCondition = "gvkeyIntTier`i'_ip != comparison_gvkeyIntTier1" // Used for the "Later Divorced" variable
		
		if(`generationCounter' > 3){
		
			forvalues p = 2/`=(`generationCounter'-2)'{ // Within this loop we just write some code for the conditions for which we replace gvkS_laterDivorced with 1
				
				local replaceCodeCondition = "`replaceCodeCondition' & gvkeyIntTier`i'_ip != comparison_gvkeyIntTier`p'"
				
			}
			
		}
		
		forvalues k = 1/`=(`maxSpell' - 1)'{ // The spell under consideration for the "later divorced variable" is `i'
			
			local kPlusOne = `k' + 1
			
			forvalues m = `kPlusOne'/`maxSpell'{ // All future spells, which must each be considered for the later divorced variable
				
				forvalues p = 1/`=(`generationCounter'-2)'{ // We use this loop to create variables for intermediary gvkeys from the future spell (m) under consideration
					
					bysort gvkey_secondary (year1): gen comparison_gvkeyIntTier`p' = gvkeyIntTier`p'[`m']
					
					label var comparison_gvkeyIntTier`p' "gvkey `=(`generationCounter' - 1 - `p')' level(s) above gvkey_secondary, `m' spells in the future"
					
				}
				
				bysort gvkey_secondary (year1): replace gvkT`i'_laterDivorced = 1 if `k' == _n & `m' <= _N & gvkeyIntTier`i'_ip != gvkey_primary[`m'] & `replaceCodeCondition' & !missing(gvkT`i'_laterDivorced) // If the immediate parent does not feature in the ownership structure in ownership spell `m', then we mark gvkey_secondary as later divorced from its immediate parent
				
				drop comparison_gvkeyIntTier* // Drop all "comparison of future intermediary gvkeys" variables for the next iteration
				
			}
			
		}
		
		
		*** Label Variable ***
		
		label var gvkT`i'_laterDivorced "gvkeyIntTier`i' later divorced from immediate parent"
		
		
		*** Drop Immediate Parent Variable ***
		
		drop gvkeyIntTier`i'_ip // No longer needed
		
	}
	
	
	** Order Variables **
	
	local orderString = "" // Used to re-order the variables
	
	forvalues i = 1/`=(`generationCounter'-2)'{
		
		local orderString = "`orderString' gvkT`i'_laterDivorced"
		
	}
	
	order gvkey_primary gvkey_secondary year1 yearN gvkeyIntTier* gvkS_laterDivorced `orderString'
	
	
	** Compress, Export **
	
	compress
	
	save "$data/019d_chainsOfOwnership.dta", replace
	
	
** Restore **

restore


* Drop Intermediary gvkeys *

keep gvkey_1 gvkey_`generationCounter' year // This is all we need at this point


* Rename, Relabel Variables *

rename gvkey_`generationCounter' gvkey

rename gvkey_1 gvkeyUO

label var gvkey "gvkey which maps to gvkeyUO in given year"

label var gvkeyUO "Ultimate owner of gvkey in given year"


* Establish "Runs of Ownership" *

// Suppose company A is independent from 1970-1979, then owned by company B for 1980-1989, then independent again from 1990-present. If we just take minimum and maximum years for the mappings A-A and A-B, we'll get that A maps to A from 1970 to Present and to B from 1980 to 1989. This is no good. We create an "Ownership Run" variable.

bysort gvkey (year): gen ownership_run = 1 if _n == 1 // Note that gvkey-year uniquely identifies observations, and the data contain no missing values.

bysort gvkey (year): replace ownership_run = ownership_run[_n-1] + (gvkeyUO != gvkeyUO[_n-1]) if _n > 1 // Iteratively populate ownership_run values. For an example of how this works, look at gvkey == "013921".

label var ownership_run "Identifier of the temporal run of ownership of gvkey"


* Reduce to from gvkey-gvkey-year Level to gvkey-gvkey-ownership_run Level *

bysort gvkey ownership_run: egen year1 = min(year)

label var year1 "First year in which gvkey maps to gvkeyUO"

bysort gvkey ownership_run: egen yearN = max(year)

label var yearN "Last year in which gvkey maps to gvkeyUO"

drop year ownership_run // year is the only remaining variable at the gvkey-gvkey-year level. We don't actually need the ownership_run variable

duplicates drop


* Export *

sort gvkey year1

compress

save "$data/019d_whoOwnsWhomAndWhen_gvkeys.dta", replace