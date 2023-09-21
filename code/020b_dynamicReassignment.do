/*

Oliver Seager
o.j.seager@lse.ac.uk
SE 17


Created: 05/05/2023
Last Modified: 21/09/2023


The purpose of this script is to generate a list of "effective acquisition" M&A events in terms of our reassignment-friendly gvkeyFRs


Infiles:
- 019d_listedListed_EA.dta (A list of listed-listed "effective acquisition" M&A events in terms of gvkeys)
- 019d_chainsOfOwnership.dta (A list of all chains of ownership between gvkeys, with years of validity and an indicator on later divorce from parent for each constituent member)
- 019g_whoOwnsWhomAndWhen_privateSubs.dta (A mapping of clean names from private subsidiaries to ultimate parent gvkeys, with a "for reassignment" gvkey that allows the transfer of ownership of patents away from the ultimate owner)


Outfiles:
- 020b_dynamicReassignment_listedListed.dta (A list of listed-listed "effective acquisition" M&A events in terms of our reassignment-friendly gvkeyFRs)
- 020b_dynamicReassignment.dta (A list of listed-listed and listed-private "effective acquisition" M&A events in terms of our reassignment-friendly gvkeyFRs)


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

bysort gvkey (year1): gen prev_gvkeyUO = gvkeyUO[_n-1]

label var prev_gvkeyUO "Ultimate owner of gvkey in year immediately preceding given year"


* Drop Identical Links * // We need to do this where company A buys company B in year X, and company B lists subsidiary C in year X also. We have zero cases of this.

drop if prev_gvkeyUO == gvkeyUO // This only occurs in the case of a repeated link


* Flag Order of Ownership *

// We don't need to reassign these. A gvkey's patents might "reassign" to itself if it is, say, spun-off from an ultimate parent, but this will not be the first observation associated with gvkey

bysort gvkey (year1): gen ownership_order = _n

label var ownership_order "gvkeyUO is the {ownership_order}th owner of gvkey in the sample"


* Drop Extraneous Variables *

drop yearN // We don't need the *last* year that gvkeyUO owns gvkey, only the first


* Rename/Relabel Variables for Dynamic Reassignment Structure *

rename gvkey gvkeyFR

label var gvkeyFR "Effective acquiree of gvkeyUO"

label var gvkeyUO "Effective acquiror of gvkeyFR"

rename year1 year

label var year "Year of effective acquisition of gvkeyFR by gvkeyUO"


* Get Previous Intermediate Owners of gvkey (where applicable) *

rename prev_gvkeyUO gvkey_primary // For the merge to the "chains of ownership" data

rename gvkeyFR gvkey_secondary

joinby gvkey_primary gvkey_secondary using "$data/019d_chainsOfOwnership.dta", unmatched(both)
/*
                       _merge |      Freq.     Percent        Cum.
------------------------------+-----------------------------------
          only in master data |     41,802       48.79       48.79 -- All observations which are the first run of ownership (ownership_order = 1), such that prev_gvkeyUO is missing.
           only in using data |     41,787       48.77       97.56 -- All runs of ownership pertaining to all gvkeys that are only ever owned by themselves *once* (8 firms are owned by themselves in two separate stints)
both in master and using data |      2,091        2.44      100.00 -- All observations that merge, including 25 which are repeated
------------------------------+-----------------------------------
                        Total |     85,680      100.00
*/
drop if _merge == 2 | (_merge == 3 & yearN != year - 1) // _merge == 2 are simply links that do not merge as no transferral is required. The others are just temporally erroneous.

drop _merge year1 yearN gvkS_laterDivorced gvkT?_laterDivorced // All extraneous variables from the merge

rename gvkey_primary prev_gvkeyUO

rename gvkey_secondary gvkeyFR

quietly ds // Gets all variables into `=r(varlist)'

local loopCounter = 0 // We use this for labelling intermediary gvkeys in gvkeyFR's *previous* corporate structure

foreach V in `=r(varlist)'{
	
	if(strpos("`V'", "gvkeyIntTier") > 0){
		
		rename `V' prev_`V'
		
		local oldLabel: variable label prev_`V'
		
		label var prev_`V' "Previous I`=substr("`oldLabel'", 2, .)'"
		
	}
	
}


* Drop Observations Concerning Firms Owning Themselves First *

drop if ownership_order == 1 & gvkeyUO == gvkeyFR // These create no need for "reassignment"

drop ownership_order // No longer needed


* Get Current Intermediate Owners of gvkey *

rename gvkeyUO gvkey_primary 

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

drop _merge year1 yearN gvkS_laterDivorced gvkT?_laterDivorced // All extraneous variables from the merge

rename gvkey_primary gvkeyUO

rename gvkey_secondary gvkeyFR


* Get Highest-Ranking Surviving Firm in Structure Change *

gen hrsf = gvkeyFR

quietly ds prev_gvkeyIntTier* // Gets all variables beginning with prev_gvkeyIntTier into `=r(varlist)'

local loopLength = 0 // We use this for counting the number of intermediary tiers in the dataset

foreach V in `=r(varlist)'{
	
	local loopLength = `loopLength' + 1
	
}

forvalues i = `loopLength'(-1)1{ // Loop in reverse order (upwards) through the previous intermediary tiers 
	
	local replaceCondition = "!missing(prev_gvkeyIntTier`i') & (prev_gvkeyIntTier`i' == gvkeyUO"
	
	forvalues j = 1/`loopLength'{ // Loop downwards through the current intermediary tiers
		
		local replaceCondition = "`replaceCondition' | prev_gvkeyIntTier`i' == gvkeyIntTier`j'"
		
	}
	
	local replaceCondition = "`replaceCondition')"
	
	replace hrsf = prev_gvkeyIntTier`i' if `replaceCondition'
	
}

local replaceCondition = "!missing(prev_gvkeyUO) & (prev_gvkeyUO == gvkeyUO"

forvalues k = 1/`loopLength'{ // Loop downwards through the current intermediary tiers
	
	local replaceCondition = "`replaceCondition' | prev_gvkeyUO == gvkeyIntTier`k'"
	
}

local replaceCondition = "`replaceCondition')"

replace hrsf = prev_gvkeyUO if `replaceCondition'

label var hrsf "Highest-ranking surviving firm in structure change"


* Get Lowest-Ranking New Firm in Structure Change *

gen lrnf = "" // We initiate this as empty

local replaceCondition = "!missing(gvkeyUO) & gvkeyUO != prev_gvkeyUO"

forvalues i = 1/`loopLength'{ // Loop downwards through the intermediary tiers
	
	local replaceCondition = "`replaceCondition' & gvkeyUO != prev_gvkeyIntTier`i'"
	
}

replace lrnf = gvkeyUO if `replaceCondition'

forvalues j = 1/`loopLength'{ // Loop in order (downwards) through the current intermediary tiers 
	
	local replaceCondition = "!missing(gvkeyIntTier`j') & gvkeyIntTier`j' != prev_gvkeyUO"
	
	forvalues k = 1/`loopLength'{ // Loop upwards through the previous intermediary tiers
		
		local replaceCondition = "`replaceCondition' & gvkeyIntTier`j' != prev_gvkeyIntTier`k'"
		
	}
	
	replace lrnf = gvkeyIntTier`j' if `replaceCondition'
	
}

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
        from using                          2  (_merge==2) -- Observations in which the effective acquirers are themselves effectively acquired in the same year.

    Matched                             1,936  (_merge==3) -- Everything from the using merges.
    -----------------------------------------
*/
drop if _merge == 2

drop _merge


* Drop Extraneous Variables *

drop prev_gvkeyUO prev_gvkeyIntTier? gvkeyIntTier? hrsf lrnf


* Insert Observations Concerning Reverse Spin-Off Firms *

insobs 39

replace gvkeyUO = "184899" if _n == _N - 38
replace gvkeyFR = "012796A" if _n == _N - 38
replace year = 2008 if _n == _N - 38
replace gvkey_primary = "184899" if _n == _N - 38
replace gvkey_secondary = "012796A" if _n == _N - 38
replace source = "General Research" if _n == _N - 38
replace type = "Reverse Spin-Off" if _n == _N - 38

replace gvkeyUO = "012796" if _n == _N - 37
replace gvkeyFR = "012796A" if _n == _N - 37
replace year = 1950 if _n == _N - 37
replace gvkey_primary = "012796" if _n == _N - 37
replace gvkey_secondary = "012796A" if _n == _N - 37
replace source = "General Research" if _n == _N - 37
replace type = "Dummy Subsidiary Listing" if _n == _N - 37

replace gvkeyUO = "156819" if _n == _N - 36
replace gvkeyFR = "008818A" if _n == _N - 36
replace year = 2002 if _n == _N - 36
replace gvkey_primary = "156819" if _n == _N - 36
replace gvkey_secondary = "008818A" if _n == _N - 36
replace source = "General Research" if _n == _N - 36
replace type = "Reverse Spin-Off" if _n == _N - 36

replace gvkeyUO = "008818" if _n == _N - 35
replace gvkeyFR = "008818A" if _n == _N - 35
replace year = 1950 if _n == _N - 35
replace gvkey_primary = "008818" if _n == _N - 35
replace gvkey_secondary = "008818A" if _n == _N - 35
replace source = "General Research" if _n == _N - 35
replace type = "Dummy Subsidiary Listing" if _n == _N - 35

replace gvkeyUO = "171187" if _n == _N - 34
replace gvkeyFR = "179605A" if _n == _N - 34
replace year = 2012 if _n == _N - 34
replace gvkey_primary = "171187" if _n == _N - 34
replace gvkey_secondary = "179605A" if _n == _N - 34
replace source = "General Research" if _n == _N - 34
replace type = "Reverse Spin-Off" if _n == _N - 34

replace gvkeyUO = "179605" if _n == _N - 33
replace gvkeyFR = "179605A" if _n == _N - 33
replace year = 1950 if _n == _N - 33
replace gvkey_primary = "179605" if _n == _N - 33
replace gvkey_secondary = "179605A" if _n == _N - 33
replace source = "General Research" if _n == _N - 33
replace type = "Dummy Subsidiary Listing" if _n == _N - 33

replace gvkeyUO = "135990" if _n == _N - 32
replace gvkeyFR = "005742A" if _n == _N - 32
replace year = 2012 if _n == _N - 32
replace gvkey_primary = "135990" if _n == _N - 32
replace gvkey_secondary = "140033" if _n == _N - 32
replace source = "General Research" if _n == _N - 32
replace type = "Reverse Spin-Off" if _n == _N - 32

replace gvkeyUO = "140033" if _n == _N - 31
replace gvkeyFR = "005742A" if _n == _N - 31
replace year = 2010 if _n == _N - 31
replace gvkey_primary = "140033" if _n == _N - 31
replace gvkey_secondary = "140977" if _n == _N - 31
replace source = "General Research" if _n == _N - 31
replace type = "Reverse Spin-Off" if _n == _N - 31

replace gvkeyUO = "005742" if _n == _N - 30
replace gvkeyFR = "005742A" if _n == _N - 30
replace year = 1950 if _n == _N - 30
replace gvkey_primary = "005742" if _n == _N - 30
replace gvkey_secondary = "005742A" if _n == _N - 30
replace source = "General Research" if _n == _N - 30
replace type = "Dummy Subsidiary Listing" if _n == _N - 30

replace gvkeyUO = "140977" if _n == _N - 29
replace gvkeyFR = "005742A" if _n == _N - 29
replace year = 2003 if _n == _N - 29
replace gvkey_primary = "140977" if _n == _N - 29
replace gvkey_secondary = "005742A" if _n == _N - 29
replace source = "General Research" if _n == _N - 29
replace type = "Reverse Spin-Off" if _n == _N - 29

replace gvkeyUO = "003243" if _n == _N - 28
replace gvkeyFR = "003243A" if _n == _N - 28
replace year = 1950 if _n == _N - 28
replace gvkey_primary = "003243" if _n == _N - 28
replace gvkey_secondary = "003243A" if _n == _N - 28
replace source = "General Research" if _n == _N - 28
replace type = "Dummy Subsidiary Listing" if _n == _N - 28

replace gvkeyUO = "062689" if _n == _N - 27
replace gvkeyFR = "003243A" if _n == _N - 27
replace year = 2001 if _n == _N - 27
replace gvkey_primary = "062689" if _n == _N - 27
replace gvkey_secondary = "003243A" if _n == _N - 27
replace source = "General Research" if _n == _N - 27
replace type = "Reverse Spin-Off" if _n == _N - 27

replace gvkeyUO = "011218" if _n == _N - 26
replace gvkeyFR = "011218A" if _n == _N - 26
replace year = 1950 if _n == _N - 26
replace gvkey_primary = "011218" if _n == _N - 26
replace gvkey_secondary = "011218A" if _n == _N - 26
replace source = "General Research" if _n == _N - 26
replace type = "Dummy Subsidiary Listing" if _n == _N - 26

replace gvkeyUO = "061402" if _n == _N - 25
replace gvkeyFR = "011218A" if _n == _N - 25
replace year = 1994 if _n == _N - 25
replace gvkey_primary = "061402" if _n == _N - 25
replace gvkey_secondary = "011218A" if _n == _N - 25
replace source = "General Research" if _n == _N - 25
replace type = "Reverse Spin-Off" if _n == _N - 25

replace gvkeyUO = "009728" if _n == _N - 24
replace gvkeyFR = "009728A" if _n == _N - 24
replace year = 1950 if _n == _N - 24
replace gvkey_primary = "009728" if _n == _N - 24
replace gvkey_secondary = "009728A" if _n == _N - 24
replace source = "General Research" if _n == _N - 24
replace type = "Dummy Subsidiary Listing" if _n == _N - 24

replace gvkeyUO = "032014" if _n == _N - 23
replace gvkeyFR = "009728A" if _n == _N - 23
replace year = 2018 if _n == _N - 23
replace gvkey_primary = "032014" if _n == _N - 23
replace gvkey_secondary = "009728A" if _n == _N - 23
replace source = "General Research" if _n == _N - 23
replace type = "Reverse Spin-Off" if _n == _N - 23

replace gvkeyUO = "024937" if _n == _N - 22
replace gvkeyFR = "024937A" if _n == _N - 22
replace year = 1950 if _n == _N - 22
replace gvkey_primary = "024937" if _n == _N - 22
replace gvkey_secondary = "024937A" if _n == _N - 22
replace source = "General Research" if _n == _N - 22
replace type = "Dummy Subsidiary Listing" if _n == _N - 22

replace gvkeyUO = "122916" if _n == _N - 21
replace gvkeyFR = "024937A" if _n == _N - 21
replace year = 2012 if _n == _N - 21
replace gvkey_primary = "122916" if _n == _N - 21
replace gvkey_secondary = "024937A" if _n == _N - 21
replace source = "General Research" if _n == _N - 21
replace type = "Reverse Spin-Off" if _n == _N - 21

replace gvkeyUO = "005639" if _n == _N - 20
replace gvkeyFR = "005639A" if _n == _N - 20
replace year = 1950 if _n == _N - 20
replace gvkey_primary = "005639" if _n == _N - 20
replace gvkey_secondary = "005639A" if _n == _N - 20
replace source = "General Research" if _n == _N - 20
replace type = "Dummy Subsidiary Listing" if _n == _N - 20

replace gvkeyUO = "179657" if _n == _N - 19
replace gvkeyFR = "005639A" if _n == _N - 19
replace year = 2005 if _n == _N - 19
replace gvkey_primary = "179657" if _n == _N - 19
replace gvkey_secondary = "005639A" if _n == _N - 19
replace source = "General Research" if _n == _N - 19
replace type = "Reverse Spin-Off" if _n == _N - 19

replace gvkeyUO = "004988" if _n == _N - 18
replace gvkeyFR = "004988A" if _n == _N - 18
replace year = 1950 if _n == _N - 18
replace gvkey_primary = "004988" if _n == _N - 18
replace gvkey_secondary = "004988A" if _n == _N - 18
replace source = "General Research" if _n == _N - 18
replace type = "Dummy Subsidiary Listing" if _n == _N - 18

replace gvkeyUO = "019574" if _n == _N - 17
replace gvkeyFR = "004988A" if _n == _N - 17
replace year = 2015 if _n == _N - 17
replace gvkey_primary = "019574" if _n == _N - 17
replace gvkey_secondary = "004988A" if _n == _N - 17
replace source = "General Research" if _n == _N - 17
replace type = "Reverse Spin-Off" if _n == _N - 17

replace gvkeyUO = "007745" if _n == _N - 16
replace gvkeyFR = "007745A" if _n == _N - 16
replace year = 1950 if _n == _N - 16
replace gvkey_primary = "007745" if _n == _N - 16
replace gvkey_secondary = "007745A" if _n == _N - 16
replace source = "General Research" if _n == _N - 16
replace type = "Dummy Subsidiary Listing" if _n == _N - 16

replace gvkeyUO = "013351" if _n == _N - 15
replace gvkeyFR = "007745A" if _n == _N - 15
replace year = 1983 if _n == _N - 15
replace gvkey_primary = "013351" if _n == _N - 15
replace gvkey_secondary = "007745A" if _n == _N - 15
replace source = "General Research" if _n == _N - 15
replace type = "Reverse Spin-Off" if _n == _N - 15

replace gvkeyUO = "005342" if _n == _N - 14
replace gvkeyFR = "005342A" if _n == _N - 14
replace year = 1950 if _n == _N - 14
replace gvkey_primary = "005342" if _n == _N - 14
replace gvkey_secondary = "005342A" if _n == _N - 14
replace source = "General Research" if _n == _N - 14
replace type = "Dummy Subsidiary Listing" if _n == _N - 14

replace gvkeyUO = "160785" if _n == _N - 13
replace gvkeyFR = "005342A" if _n == _N - 13
replace year = 2003 if _n == _N - 13
replace gvkey_primary = "160785" if _n == _N - 13
replace gvkey_secondary = "005342A" if _n == _N - 13
replace source = "General Research" if _n == _N - 13
replace type = "Reverse Spin-Off" if _n == _N - 13

replace gvkeyUO = "100080" if _n == _N - 12
replace gvkeyFR = "007536A" if _n == _N - 12
replace year = 2016 if _n == _N - 12
replace gvkey_primary = "100080" if _n == _N - 12
replace gvkey_secondary = "140760" if _n == _N - 12
replace source = "General Research" if _n == _N - 12
replace type = "Merger or Acquisition" if _n == _N - 12

replace gvkeyUO = "140760" if _n == _N - 11
replace gvkeyFR = "007536A" if _n == _N - 11
replace year = 1998 if _n == _N - 11
replace gvkey_primary = "140760" if _n == _N - 11
replace gvkey_secondary = "007536A" if _n == _N - 11
replace source = "General Research" if _n == _N - 11
replace type = "Reverse Spin-Off" if _n == _N - 11

replace gvkeyUO = "005776" if _n == _N - 10
replace gvkeyFR = "005776A" if _n == _N - 10
replace year = 1967 if _n == _N - 10
replace gvkey_primary = "005776" if _n == _N - 10
replace gvkey_secondary = "005776A" if _n == _N - 10
replace source = "General Research" if _n == _N - 10
replace type = "Dummy Subsidiary Listing" if _n == _N - 10

replace gvkeyUO = "027914" if _n == _N - 9
replace gvkeyFR = "005776A" if _n == _N - 9
replace year = 1993 if _n == _N - 9
replace gvkey_primary = "027914" if _n == _N - 9
replace gvkey_secondary = "005776A" if _n == _N - 9
replace source = "General Research" if _n == _N - 9
replace type = "Reverse Spin-Off" if _n == _N - 9

replace gvkeyUO = "026061" if _n == _N - 8
replace gvkeyFR = "026061A" if _n == _N - 8
replace year = 1963 if _n == _N - 8
replace gvkey_primary = "026061" if _n == _N - 8
replace gvkey_secondary = "026061A" if _n == _N - 8
replace source = "General Research" if _n == _N - 8
replace type = "Dummy Subsidiary Listing" if _n == _N - 8

replace gvkeyUO = "180402" if _n == _N - 7
replace gvkeyFR = "026061A" if _n == _N - 7
replace year = 2007 if _n == _N - 7
replace gvkey_primary = "180402" if _n == _N - 7
replace gvkey_secondary = "026061A" if _n == _N - 7
replace source = "General Research" if _n == _N - 7
replace type = "Reverse Spin-Off" if _n == _N - 7

replace gvkeyUO = "026061" if _n == _N - 6
replace gvkeyFR = "026061B" if _n == _N - 6
replace year = 1963 if _n == _N - 6
replace gvkey_primary = "026061" if _n == _N - 6
replace gvkey_secondary = "026061B" if _n == _N - 6
replace source = "General Research" if _n == _N - 6
replace type = "Dummy Subsidiary Listing" if _n == _N - 6

replace gvkeyUO = "036691" if _n == _N - 5
replace gvkeyFR = "026061B" if _n == _N - 5
replace year = 2018 if _n == _N - 5
replace gvkey_primary = "036691" if _n == _N - 5
replace gvkey_secondary = "026061B" if _n == _N - 5
replace source = "General Research" if _n == _N - 5
replace type = "Reverse Spin-Off" if _n == _N - 5

replace gvkeyUO = "007536" if _n == _N - 4
replace gvkeyFR = "007536A" if _n == _N - 4
replace year = 1950 if _n == _N - 4
replace gvkey_primary = "007536" if _n == _N - 4
replace gvkey_secondary = "007536A" if _n == _N - 4
replace source = "General Research" if _n == _N - 4
replace type = "Dummy Subsidiary Listing" if _n == _N - 4

replace gvkeyUO = "001254" if _n == _N - 3
replace gvkeyFR = "001254A" if _n == _N - 3
replace year = 1962 if _n == _N - 3
replace gvkey_primary = "001254" if _n == _N - 3
replace gvkey_secondary = "001254A" if _n == _N - 3
replace source = "General Research" if _n == _N - 3
replace type = "Dummy Subsidiary Listing" if _n == _N - 3

replace gvkeyUO = "011756" if _n == _N - 2
replace gvkeyFR = "001254A" if _n == _N - 2
replace year = 2011 if _n == _N - 2
replace gvkey_primary = "011756" if _n == _N - 2
replace gvkey_secondary = "001254A" if _n == _N - 2
replace source = "General Research" if _n == _N - 2
replace type = "Reverse Spin-Off" if _n == _N - 2

replace gvkeyUO = "002812" if _n == _N - 1
replace gvkeyFR = "002812A" if _n == _N - 1
replace year = 1960 if _n == _N - 1
replace gvkey_primary = "002812" if _n == _N - 1
replace gvkey_secondary = "002812A" if _n == _N - 1
replace source = "General Research" if _n == _N - 1
replace type = "Dummy Subsidiary Listing" if _n == _N - 1

replace gvkeyUO = "061780" if _n == _N
replace gvkeyFR = "002812A" if _n == _N
replace year = 1991 if _n == _N
replace gvkey_primary = "061780" if _n == _N
replace gvkey_secondary = "002812A" if _n == _N
replace source = "General Research" if _n == _N
replace type = "Reverse Spin-Off" if _n == _N


* Export *

compress

save "$data/020b_dynamicReassignment_listedListed.dta", replace


/*
Format for a reverse spin-off...

replace gvkeyUO = "" if _n == _N - xxx
replace gvkeyFR = "" if _n == _N - xxx
replace year =  if _n == _N - xxx
replace gvkey_primary = "" if _n == _N - xxx
replace gvkey_secondary = "" if _n == _N - xxx
replace source = "General Research" if _n == _N - xxx
replace type = "Dummy Subsidiary Listing" if _n == _N - xxx

replace gvkeyUO = "" if _n == _N - yyy
replace gvkeyFR = "" if _n == _N - yyy
replace year =  if _n == _N - yyy
replace gvkey_primary = "" if _n == _N - yyy
replace gvkey_secondary = "" if _n == _N - yyy
replace source = "General Research" if _n == _N - yyy
replace type = "Reverse Spin-Off" if _n == _N - yyy

*/





********************************************************************************
*********************** BUILD DYNAMIC REASSIGNMENT DATA ************************
********************************************************************************

* Import the Who-owns-Whom-and-When Data for Private Subsidiaries *

use "$data/019f_whoOwnsWhomAndWhen_privateSubs.dta", clear


* Drop Extraneous Variables *

drop privateSubsidiary cnLink_yN gvkey1 name1 name1_year1 name1_yearN name1_source gvkey2 name2 name2_year1 name2_yearN name2_source gvkey3 name3 name3_year1 name3_yearN name3_source singlePublicSubs gvkeyIntTier? gvkeyCNoriginator


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

label var gvkeyFR "Effective acquiree of gvkeyUO"

label var gvkeyUO "Effective acquiror of gvkeyFR"

rename cnLink_y1 year

label var year "Year of effective acquisition of gvkeyFR by gvkeyUO"

order gvkeyFR gvkeyUO year


* Generate Additional Dynamic Reassignment Variables *

gen gvkey_primary = gvkeyUO // For private subsidiaries, this is always the gvkeyUO

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