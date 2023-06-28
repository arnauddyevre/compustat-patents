/*

Oliver Seager
o.j.seager@lse.ac.uk
SE 17


Created: 05/05/2023
Last Modified: 28/06/2023


The purpose of this script is to generate a list of "effective acquisition" M&A events in terms of our reassignment-friendly gvkeyFRs


Infiles:
- 019d_listedListed_EA.dta (A list of listed-listed "effective acquisition" M&A events in terms of gvkeys)
- 019d_chainsOfOwnership.dta (A list of all chains of ownership between gvkeys, with years of validity and an indicator on later divorce from parent for each constituent member)
- 019g_whoOwnsWhomAndWhen_privateSubs.dta (A mapping of clean names from private subsidiaries to ultimate parent gvkeys, with a "for reassignment" gvkey that allows the transfer of ownership of patents away from the ultimate owner)


Outfiles:
- 020b_dynamicReassignment_listedListed.dta (A list of listed-listed "effective acquisition" M&A events in terms of our reassignment-friendly gvkeyFRs)
- 020b_dynamicReassignment.dta (A list of listed-listed and listed-private "effective acquisition" M&A events in terms of our reassignment-friendly gvkeyFRs)
- dynamic.csv (For publication; A list of listed-listed and listed-private "effective acquisition" M&A events in terms of our reassignment-friendly gvkeyFRs. Identical to 020b_dynamicReassignment.dta.)


Called .do Files:
None


External Packages:
None


*/

********************************************************************************
************* BUILD DYNAMIC REASSIGNMENT DATA (LISTED-LISTED ONLY) *************
********************************************************************************

* Import Who-owns-Whom In Terms of gvkeys *

use "$data/019d_whoOwnsWhomAndWhen_gvkeys.dta", clear


* Get Previous Owner of gvkey (where applicable) *

bysort gvkey (year1): gen prev_gvkey_uo = gvkey_uo[_n-1]

label var prev_gvkey_uo "Ultimate owner of gvkey in year immediately preceding given year"


* Drop Identical Links * // We need to do this where company A buys company B in year X, and company B lists subsidiary C in year X also. We have two cases of this.

drop if prev_gvkey_uo == gvkey_uo // This only occurs in the case of a repeated link


* Flag Order of Ownership *

// We don't need to reassign these. A gvkey's patents might "reassign" to itself if it is, say, spun-off from an ultimate parent, but this will not be the first observation associated with gvkey

bysort gvkey (year1): gen ownership_order = _n

label var ownership_order "gvkey_uo is the {ownership_order}th owner of gvkey in the sample"


* Drop Extraneous Variables *

drop yearN // We don't need the *last* year that gvkey_uo owns gvkey, only the first


* Rename/Relabel Variables for Dynamic Reassignment Structure *

rename gvkey gvkeyFR

label var gvkeyFR "Effective acquiree of gvkey_uo"

label var gvkey_uo "Effective acquiror of gvkeyFR"

rename year1 year

label var year "Year of effective acquisition of gvkeyFR by gvkey_uo"


* Get Previous Intermediate Owners of gvkey (where applicable) *

rename prev_gvkey_uo gvkey_primary // For the merge to the "chains of ownership" data

rename gvkeyFR gvkey_secondary

joinby gvkey_primary gvkey_secondary using "$data/019d_chainsOfOwnership.dta", unmatched(both)
/*

                       _merge |      Freq.     Percent        Cum.
------------------------------+-----------------------------------
          only in master data |     41,802       48.87       48.87 -- All observations which are the first run of ownership (ownership_order = 1), such that prev_gvkey_uo is missing.
           only in using data |     41,794       48.87       97.74 -- All runs of ownership pertaining to all gvkeys that are only ever owned by themselves *once* (8 firms are owned by themselves in two separate stints)
both in master and using data |      1,957        2.26      100.00 -- All observations that merge, including 25 which are repeated
------------------------------+-----------------------------------
                        Total |     85,531      100.00
*/
drop if _merge == 2 | (_merge == 3 & yearN != year - 1) // _merge == 2 are simply links that do not merge as no transferral is required. The others are just temporally erroneous.

drop _merge year1 yearN gvkS_laterDivorced gvkT1_laterDivorced gvkT2_laterDivorced gvkT3_laterDivorced // All extraneous variables from the merge

rename gvkey_primary prev_gvkey_uo

rename gvkey_secondary gvkeyFR

rename gvkeyIntTier1 prev_gvkeyIntTier1
label var prev_gvkeyIntTier1 "Previous great-grandparent of gvkeyFR, ultimately owned by prev_gvkey_uo"

rename gvkeyIntTier2 prev_gvkeyIntTier2
label var prev_gvkeyIntTier2 "Previous grandparent of gvkeyFR, ultimately owned by prev_gvkey_uo"

rename gvkeyIntTier3 prev_gvkeyIntTier3
label var prev_gvkeyIntTier3 "Previous parent of gvkeyFR, ultimately owned by prev_gvkey_uo"


* Drop Observations Concerning Firms Owning Themselves First *

drop if ownership_order == 1 & gvkey_uo == gvkeyFR // These create no need for "reassignment"

drop ownership_order // No longer needed


* Get Current Intermediate Owners of gvkey *

rename gvkey_uo gvkey_primary 

rename gvkeyFR gvkey_secondary

joinby gvkey_primary gvkey_secondary using "$data/019d_chainsOfOwnership.dta", unmatched(both)
/*
                       _merge |      Freq.     Percent        Cum.
------------------------------+-----------------------------------
           only in using data |     41,785       95.53       95.53 -- The chains of ownership that do not pertain to transactions requiring reassignment
both in master and using data |      1,956        4.47      100.00 -- All from the master merge, including 20 observations that join to multiple observations in the using
------------------------------+-----------------------------------
                        Total |     43,741      100.00
*/
drop if _merge == 2 | (_merge == 3 & year1 != year) // _merge == 2 are simply links that do not merge as no transferral is required. The others are just temporally erroneous.

drop _merge year1 yearN gvkS_laterDivorced gvkT1_laterDivorced gvkT2_laterDivorced gvkT3_laterDivorced // All extraneous variables from the merge

rename gvkey_primary gvkey_uo

rename gvkey_secondary gvkeyFR


* Get Highest-Ranking Surviving Firm in Structure Change *

gen hrsf = gvkeyFR

replace hrsf = prev_gvkeyIntTier3 if !missing(prev_gvkeyIntTier3) & (prev_gvkeyIntTier3 == gvkey_uo | prev_gvkeyIntTier3 == gvkeyIntTier1 | prev_gvkeyIntTier3 == gvkeyIntTier2 | prev_gvkeyIntTier3 == gvkeyIntTier3)

replace hrsf = prev_gvkeyIntTier2 if !missing(prev_gvkeyIntTier2) & (prev_gvkeyIntTier2 == gvkey_uo | prev_gvkeyIntTier2 == gvkeyIntTier1 | prev_gvkeyIntTier2 == gvkeyIntTier2 | prev_gvkeyIntTier2 == gvkeyIntTier3)

replace hrsf = prev_gvkeyIntTier1 if !missing(prev_gvkeyIntTier1) & (prev_gvkeyIntTier1 == gvkey_uo | prev_gvkeyIntTier1 == gvkeyIntTier1 | prev_gvkeyIntTier1 == gvkeyIntTier2 | prev_gvkeyIntTier1 == gvkeyIntTier3)

replace hrsf = prev_gvkey_uo if !missing(prev_gvkey_uo) & (prev_gvkey_uo == gvkey_uo | prev_gvkey_uo == gvkeyIntTier1 | prev_gvkey_uo == gvkeyIntTier2 | prev_gvkey_uo == gvkeyIntTier3)

label var hrsf "Highest-ranking surviving firm in structure change"


* Get Lowest-Ranking New Firm in Structure Change *

gen lrnf = "" // We initiate this as empty

replace lrnf = gvkey_uo if !missing(gvkey_uo) & gvkey_uo != prev_gvkey_uo & gvkey_uo != prev_gvkeyIntTier1 & gvkey_uo != prev_gvkeyIntTier2 & gvkey_uo != prev_gvkeyIntTier3 & gvkey_uo != gvkeyFR

replace lrnf = gvkeyIntTier1 if !missing(gvkeyIntTier1) & gvkeyIntTier1 != prev_gvkey_uo & gvkeyIntTier1 != prev_gvkeyIntTier1 & gvkeyIntTier1 != prev_gvkeyIntTier2 & gvkeyIntTier1 != prev_gvkeyIntTier3

replace lrnf = gvkeyIntTier2 if !missing(gvkeyIntTier2) & gvkeyIntTier2 != prev_gvkey_uo & gvkeyIntTier2 != prev_gvkeyIntTier1 & gvkeyIntTier2 != prev_gvkeyIntTier2 & gvkeyIntTier2 != prev_gvkeyIntTier3

replace lrnf = gvkeyIntTier3 if !missing(gvkeyIntTier3) & gvkeyIntTier3 != prev_gvkey_uo & gvkeyIntTier3 != prev_gvkeyIntTier1 & gvkeyIntTier3 != prev_gvkeyIntTier2 & gvkeyIntTier3 != prev_gvkeyIntTier3

label var lrnf "Lowest-ranking new firm in structure change"


* Merge to Effective Acquisition Data for Transaction Source and Type *

gen gvkey_primary = lrnf if !missing(lrnf)

replace gvkey_primary = hrsf if missing(lrnf) // If there are no new firms, we have that the highest-ranking surviving firm effectively acquires itself

label var gvkey_primary "Effectively acquiring firm in transaction causing reassignment"

gen gvkey_secondary = hrsf

label var gvkey_secondary "Effectively acquired firm in transaction causing reassignment"

merge m:1 gvkey_primary gvkey_secondary year using "$data/019d_listedListed_EA.dta" // m:1 as one transaction can cause many reassignments
/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                             2
        from master                         0  (_merge==1)
        from using                          2  (_merge==2) -- Two observations in which the acquirers are themselves acquired in the same year.

    Matched                             1,936  (_merge==3) -- Everything from the using merges.
    -----------------------------------------
*/
drop if _merge == 2

drop _merge


* Update Type of Transaction to Reflect Indirect Reassignments *

replace type = type + " (of gvkeyFR parent)" if hrsf != gvkeyFR

replace type = type + " (by gvkey_uo child)" if lrnf != gvkey_uo & !missing(lrnf)

label var type "Type of M&A or accounting event"


* Drop Extraneous Variables *

drop prev_gvkey_uo prev_gvkeyIntTier1 prev_gvkeyIntTier2 prev_gvkeyIntTier3 gvkeyIntTier1 gvkeyIntTier2 gvkeyIntTier3 hrsf lrnf


* Insert Observations Concerning Reverse Spin-Off Firms *

insobs 14

replace gvkey_uo = "005342" if _n == _N - 13
replace gvkeyFR = "005342A" if _n == _N - 13
replace year = 1950 if _n == _N - 13
replace gvkey_primary = "005342" if _n == _N - 13
replace gvkey_secondary = "005342A" if _n == _N - 13
replace source = "General Research" if _n == _N - 13
replace type = "Dummy Subsidiary Listing" if _n == _N - 13

replace gvkey_uo = "160785" if _n == _N - 12
replace gvkeyFR = "005342A" if _n == _N - 12
replace year = 2003 if _n == _N - 12
replace gvkey_primary = "160785" if _n == _N - 12
replace gvkey_secondary = "005342A" if _n == _N - 12
replace source = "General Research" if _n == _N - 12
replace type = "Reverse Spin-Off" if _n == _N - 12

replace gvkey_uo = "140760" if _n == _N - 11
replace gvkeyFR = "007536A" if _n == _N - 11
replace year = 1998 if _n == _N - 11
replace gvkey_primary = "140760" if _n == _N - 11
replace gvkey_secondary = "007536A" if _n == _N - 11
replace source = "General Research" if _n == _N - 11
replace type = "Reverse Spin-Off" if _n == _N - 11

replace gvkey_uo = "005776" if _n == _N - 10
replace gvkeyFR = "005776A" if _n == _N - 10
replace year = 1967 if _n == _N - 10
replace gvkey_primary = "005776" if _n == _N - 10
replace gvkey_secondary = "005776A" if _n == _N - 10
replace source = "General Research" if _n == _N - 10
replace type = "Dummy Subsidiary Listing" if _n == _N - 10

replace gvkey_uo = "027914" if _n == _N - 9
replace gvkeyFR = "005776A" if _n == _N - 9
replace year = 1993 if _n == _N - 9
replace gvkey_primary = "027914" if _n == _N - 9
replace gvkey_secondary = "005776A" if _n == _N - 9
replace source = "General Research" if _n == _N - 9
replace type = "Reverse Spin-Off" if _n == _N - 9

replace gvkey_uo = "026061" if _n == _N - 8
replace gvkeyFR = "026061A" if _n == _N - 8
replace year = 1963 if _n == _N - 8
replace gvkey_primary = "026061" if _n == _N - 8
replace gvkey_secondary = "026061A" if _n == _N - 8
replace source = "General Research" if _n == _N - 8
replace type = "Dummy Subsidiary Listing" if _n == _N - 8

replace gvkey_uo = "180402" if _n == _N - 7
replace gvkeyFR = "026061A" if _n == _N - 7
replace year = 2007 if _n == _N - 7
replace gvkey_primary = "180402" if _n == _N - 7
replace gvkey_secondary = "026061A" if _n == _N - 7
replace source = "General Research" if _n == _N - 7
replace type = "Reverse Spin-Off" if _n == _N - 7

replace gvkey_uo = "026061" if _n == _N - 6
replace gvkeyFR = "026061B" if _n == _N - 6
replace year = 1963 if _n == _N - 6
replace gvkey_primary = "026061" if _n == _N - 6
replace gvkey_secondary = "026061B" if _n == _N - 6
replace source = "General Research" if _n == _N - 6
replace type = "Dummy Subsidiary Listing" if _n == _N - 6

replace gvkey_uo = "036691" if _n == _N - 5
replace gvkeyFR = "026061B" if _n == _N - 5
replace year = 2018 if _n == _N - 5
replace gvkey_primary = "036691" if _n == _N - 5
replace gvkey_secondary = "026061B" if _n == _N - 5
replace source = "General Research" if _n == _N - 5
replace type = "Reverse Spin-Off" if _n == _N - 5

replace gvkey_uo = "007536" if _n == _N - 4
replace gvkeyFR = "007536A" if _n == _N - 4
replace year = 1950 if _n == _N - 4
replace gvkey_primary = "007536" if _n == _N - 4
replace gvkey_secondary = "007536A" if _n == _N - 4
replace source = "General Research" if _n == _N - 4
replace type = "Dummy Subsidiary Listing" if _n == _N - 4

replace gvkey_uo = "001254" if _n == _N - 3
replace gvkeyFR = "001254A" if _n == _N - 3
replace year = 1962 if _n == _N - 3
replace gvkey_primary = "001254" if _n == _N - 3
replace gvkey_secondary = "001254A" if _n == _N - 3
replace source = "General Research" if _n == _N - 3
replace type = "Dummy Subsidiary Listing" if _n == _N - 3

replace gvkey_uo = "011756" if _n == _N - 2
replace gvkeyFR = "001254A" if _n == _N - 2
replace year = 2011 if _n == _N - 2
replace gvkey_primary = "011756" if _n == _N - 2
replace gvkey_secondary = "001254A" if _n == _N - 2
replace source = "General Research" if _n == _N - 2
replace type = "Reverse Spin-Off" if _n == _N - 2

replace gvkey_uo = "002812" if _n == _N - 1
replace gvkeyFR = "002812A" if _n == _N - 1
replace year = 1960 if _n == _N - 1
replace gvkey_primary = "002812" if _n == _N - 1
replace gvkey_secondary = "002812A" if _n == _N - 1
replace source = "General Research" if _n == _N - 1
replace type = "Dummy Subsidiary Listing" if _n == _N - 1

replace gvkey_uo = "061780" if _n == _N
replace gvkeyFR = "002812A" if _n == _N
replace year = 1991 if _n == _N
replace gvkey_primary = "061780" if _n == _N
replace gvkey_secondary = "002812A" if _n == _N
replace source = "General Research" if _n == _N
replace type = "Reverse Spin-Off" if _n == _N


* Export *

compress

save "$data/020b_dynamicReassignment_listedListed.dta", replace





********************************************************************************
*********************** BUILD DYNAMIC REASSIGNMENT DATA ************************
********************************************************************************

* Import the Who-owns-Whom-and-When Data for Private Subsidiaries *

use "$data/019g_whoOwnsWhomAndWhen_privateSubs.dta", clear


* Drop Extraneous Variables *

drop privateSubsidiary cnLink_yN gvkey1 name1 name1_year1 name1_yearN name1_source gvkey2 name2 name2_year1 name2_yearN name2_source gvkey3 name3 name3_year1 name3_yearN name3_source singlePublicSubs gvkeyIntTier1 gvkeyIntTier2 gvkeyIntTier3 gvkeyCNoriginator


* Keep Only Subsidiaries in Need of Reassignment *

bysort clean_name: egen needsReassignment = max(substr(gvkeyFR, 1, 1) == "S") // Subsidiaries later divorced from their parents

label var needsReassignment "Patents patented under clean name need later reassignment"

keep if needsReassignment == 1

drop needsReassignment // No longer needed


* Drop Observations Preceding the gvkeyFR that is Private Subsidiary specific *

local whileSwitch = 1 // We run an iterative while loop

while(`whileSwitch' == 1){
	
	bysort clean_name (cnLink_y1): drop if _n == 1 & substr(gvkeyFR, 1, 1) != "S"
	
	if(`=r(N_drop)' == 0){
		
		local whileSwitch = 0 // Exit the loop
		
	}
	
}


* Get the Subsidiary gvkeyFR into All Observations *

bysort clean_name (cnLink_y1): egen subsGvkeyFRpos = max(_n*(substr(gvkeyFR, 1, 1) == "S"))

label var subsGvkeyFRpos "Position within clean_name of gvkeyFR specific to subsidiary"

bysort clean_name (cnLink_y1): gen subsGvkeyFR = gvkeyFR[subsGvkeyFRpos]

label var subsGvkeyFR "gvkeyFR associated with clean_name that is specific to subsidiary"

drop subsGvkeyFRpos gvkeyFR clean_name // No longer needed


* Rename, Reorder Variables in Line with Dynamic Reassignment Data *

rename subsGvkeyFR gvkeyFR

label var gvkeyFR "Effective acquiree of gvkey_uo"

label var gvkey_uo "Effective acquiror of gvkeyFR"

rename cnLink_y1 year

label var year "Year of effective acquisition of gvkeyFR by gvkey_uo"

order gvkeyFR gvkey_uo year


* Generate Additional Dynamic Reassignment Variables *

gen gvkey_primary = gvkey_uo // For private subsidiaries, this is always the gvkey_uo

label var gvkey_primary "Effectively acquiring firm in transaction causing reassignment" 

gen gvkey_secondary = gvkeyFR // For private subsidiaries, this is always the gvkeyFR

label var gvkey_secondary "Effectively acquired firm in transaction causing reassignment"

gen source = "Private subsidiaries"

label var source "Source of data on effective acquisition"

gen type = "Unknown" // We'll update these later.

label var type "Type of M&A or accounting event"


* Append the Listed-Listed Dynamic Reassignment Data *

append using "$data/020b_dynamicReassignment_listedListed.dta"


* Compress, Export *

compress

save "$data/020b_dynamicReassignment.dta", replace


* For Publication, Export Skinny Version as .csv *

export delimited "$data/dynamic.csv", replace