/*

Oliver Seager
o.j.seager@lse.ac.uk
SE 17


Created: 16/02/2023
Last Modified: 05/03/2023


The purpose of this script is to look for listed-listed mergers and acquisitions using... 

- Arora, Belenzon, and Sheer (2021)'s gvkey-permno_adj mapping. We look into ABS' unique firm identifier, the permno_adj, for this. We establish which permno_adj are mapped to by multiple gvkeys at different periods, and infer gvkey-gvkey acquisitions therefrom
- The official CRSP/Compustat permno-gvkey crosswalk
- 6-character CUSIPs, which flag the *issuer* of a stock (but we do this only manually)


Infiles:
- permno_gvkey.dta (ABS' crosswalk between their identifier - permno_adj - and gvkeys)
- 019a_permno_gvkey.dta (A cleaned mapping of CRSP permnos to Compustat gvkeys)


Outfiles:
- 019b_ABSlistedListedAuto.csv (An automatically generated file of listed-listed M&A activity as inferred from the ABS crosswalk between their unique firm identifier - permno_adj - and gvkeys)
- 019b_CRSPcstatListedListedAuto.csv (An automatically generated file of listed-listed M&A activity as inferred from the CRSP/Compustat crosswalk on WRDS between permnos (CRSP) and gvkeys (Compustat))
- 019b_cstatCUSIPs.dta (A mapping of Compustat gvkeys to their 9- and 6-character CUSIPs, excluding ETFs and similar entities)


Called .do Files:
- 500_nameCleaning.do (The centralised name cleaning algorithm)

External Packages:
- unique by Tony Brady


*/

********************************************************************************
****************** TEASE EFFECTIVE ACQUISITIONS FROM ABS DATA ******************
********************************************************************************

* Import *

use "$data/ABS/permno_gvkey.dta", clear


* Label Variables *

label var gvkey_str "Compustat unique firm identifier"

label var gvkey "Compustat unique firm identifier as numeric"

label var permno_adj "Arora, Belenzon, and Sheer (2021) unique firm identifier"


* Leave gvkey as Listed in Compustat *

drop gvkey // Compustat uses a string format for gvkeys...

rename gvkey_str gvkey // ...and they just use the name 'gvkey'


* Swap Wrong-way-around Year Boundaries * // This thankfully only happens once

gen placeholder1 = .

gen placeholder2 = .

replace placeholder1 = fyearn_adjust if fyear1_adjust > fyearn_adjust

replace placeholder2 = fyear1_adjust if fyear1_adjust > fyearn_adjust

replace fyear1_adjust = placeholder1 if !missing(placeholder1)

replace fyearn_adjust = placeholder2 if !missing(placeholder2)

replace placeholder1 = .

replace placeholder2 = .  

replace placeholder1 = max_y_permno if min_y_permno > max_y_permno

replace placeholder2 = min_y_permno if min_y_permno > max_y_permno

replace min_y_permno = placeholder1 if !missing(placeholder1)

replace max_y_permno = placeholder2 if !missing(placeholder2)

drop placeholder1 placeholder2 // No longer needed


* Get Narrow Boundaries *

gen lbYear = max(min_y_permno, fyear1_adjust)

label var lbYear "First year in which link is valid"

gen ubYear = min(max_y_permno, fyearn_adjust)

label var ubYear "Last year in which link is valid"

drop fyear1_adjust fyearn_adjust min_y_permno max_y_permno // No longer needed


* Get Numbers of permno_adjs-per-gvkey and gvkeys-per-permno_adj *

quietly unique permno_adj, by(gvkey) gen(PperG)

bysort gvkey (PperG): replace PperG = PperG[1]

label var PperG "Number of permno_adj associated with given gvkey"

quietly unique gvkey, by(permno_adj) gen(GperP)

bysort permno_adj (GperP): replace GperP = GperP[1]

label var GperP "Number of gvkey associated with given permno_adj"


* Drop 1:1 permno_adj-gvkey Mappings *

drop if PperG == 1 & GperP == 1 // These don't indicate acquisitions 


* Drop Mappings of Multiple permno_adj to Single gvkey * // These are the minority, and we deal with them manually

drop if PperG > 1

drop PperG GperP


* Automatically Infer gvkey-gvkey Acquisition through permno_adj *

// Note that all these mappings are orderly - each begins after the previous one ends

bysort permno_adj (lbYear): gen prev_gvkey = gvkey[_n-1]

label var prev_gvkey "gvkey most recently previously associated with permno_adj"


* Restructure as Our Listed-Listed Acquisition Format *

drop ubYear permno_adj // No longer needed

rename gvkey gvkey_primary

label var gvkey_primary "Effectively acquiring gvkey"

rename prev_gvkey gvkey_secondary

label var gvkey_secondary "Effectively acquired gvkey"

rename lbYear year

label var year "Year of effective acquisition"

gen source = "ABS - Automated"

label var source "Source of effective acquisition data"

order gvkey_primary gvkey_secondary year source


* Drop Observations that do not Serve as Effective Acquisitions *

drop if missing(gvkey_secondary)


* Export to .csv * // I just manually copy and paste the exported .csv to the standing listed-listed M&A data under .\State and innovation\orig\Ollie's M&A File\M&A.xlsx

export delimited using "$data/019b_ABSlistedListedAuto.csv", replace





********************************************************************************
********** TEASE EFFECTIVE ACQUISITIONS FROM CRSP-COMPUSTAT CROSSWALK **********
********************************************************************************

* Import Cleaned CRSP/Compustat Crosswalk *

use "$data/019a_permno_gvkey.dta", clear


* Merge Selected Names from CRSP *

joinby permno using "$data/019a_crspName_permno.dta", unmatched(both)
/*
                       _merge |      Freq.     Percent        Cum.
------------------------------+-----------------------------------
           only in using data |     10,589       20.74       20.74 -- Observations with permnos that don't map to gvkeys
both in master and using data |     40,477       79.26      100.00 -- All permnos from the crosswalk merge
------------------------------+-----------------------------------
                        Total |     51,066      100.00
*/
drop if _merge == 2 // Not informative if studying Compustat

drop _merge // No longer informative

format %td linkDay1 linkDayN

order permno gvkey linkdt linkenddt cstat_name linkDay1 linkDayN crsp_name multiMapFlag

replace crsp_name = "" if linkDay1 > linkenddt | linkDayN < linkdt // Flag names not relevant for the given permno-gvkey link


* Get Numbers of permnos-per-gvkey and gvkeys-per-permno *

quietly unique permno, by(gvkey) gen(PperG)

bysort gvkey (PperG): replace PperG = PperG[1]

label var PperG "Number of permno associated with given gvkey"

quietly unique gvkey, by(permno) gen(GperP)

bysort permno (GperP): replace GperP = GperP[1]

label var GperP "Number of gvkey associated with given permno"


* Drop gvkeys to which Mapping permnos all Map only to the gvkey *

// ...since these ones tell us nothing.

bysort gvkey: egen gvkeyMax_GperP = max(GperP)

label var gvkeyMax_GperP "Maximal Number of gvkeys associated with a permno mapping to given gvkey"

drop if gvkeyMax_GperP == 1

drop gvkeyMax_GperP


* Keep Only permnos to which Mapping gvkeys All Map Only to the permno *

// ...since here we can infer an automated transfer of ownership. We do the rest manually.

bysort permno: egen permnoMax_PperG = max(PperG)

label var permnoMax_PperG "Maximal Number of permnos associated with a gvkey mapping to given permno"

keep if permnoMax_PperG == 1 // We manual review *everything* for permnoMax_PperG > 1

drop permnoMax_PperG


* Drop Extraneous Variables, Drop Duplicates *

drop linkDay1 linkDayN crsp_name multiMapFlag cstat_name // We only used these variables (all CRSP- or Compustat-name related) for manual review

duplicates drop

drop PperG GperP // Easy to infer now


* Get Previous gvkey Mapping to Each permno, Drop Observations without a Previous gvkey *

// Note that, by construction, no two gvkeys map to a given permno on a given day here

bysort permno (linkdt): gen prev_gvkey = gvkey[_n-1]

label var prev_gvkey "Previous gvkey mapping to permno"

drop if missing(prev_gvkey)


* Get the Year of Effective Acquisition *

// Until perhaps a later form of this dataset, we're doing things in calendar years

gen year = yofd(linkdt)

label var year "Year of effective acquisition"


* Drop Extraneous Variables *

drop permno linkdt linkenddt // No longer needed


* Restructure as Our Listed-Listed Acquisition Format *

rename gvkey gvkey_primary

label var gvkey_primary "Effectively acquiring gvkey"

rename prev_gvkey gvkey_secondary

label var gvkey_secondary "Effectively acquired gvkey"

gen source = "CRSP/Compustat - Automated"

label var source "Source of effective acquisition data"

order gvkey_primary gvkey_secondary year source


* Export to .csv * // Again, we just manually copy and paste the exported .csv to the standing listed-listed M&A data under .\State and innovation\orig\Ollie's M&A File\M&A.xlsx

export delimited using "$data/019b_CRSPcstatListedListedAuto.csv", replace





********************************************************************************
*********************** GET COMPUSTAT 6-CHARACTER CUSIPS ***********************
********************************************************************************

* Import Compustat *

use "$orig/Compustat/cstat_1950_2022.dta", clear


* Drop Extraneous Variables *

keep gvkey cusip sic


* Rename, Label Variables *

label var gvkey "Compustat unique firm identifier"

rename cusip cusip9

label var cusip9 "9-character CUSIP (identifies stock)"

label var sic "Standard Industry Classification code"


* Reduce to gvkey-cusip Level *

// The mapping of gvkeys to *9-character* cusips in Compustat is gratefully 1:1. 20 gvkeys do not map to a cusip.

duplicates drop


* Drop Observations Missing CUSIPs *

drop if missing(cusip9) // The data we're trying to generate here is CUSIP-based, so no CUSIP means not useful


* Drop Observations that are "Holding and Other Investment Offices" or "Publicly Traded Finance Services Companies" *

// These are mostly just ETFs, of which several can come from the same issuer. They don't really tell us anything about ownership

drop if strpos(sic, "67") == 1 | sic == "6199" // Drops any firm with a SIC of the form 67xx or 6199

drop sic // No longer needed


* Get 6-character CUSIPs *

gen cusip6 = substr(cusip9, 1, 6) // 6-character CUSIPs are literally just the first 6 characters of a 9-character CUSIP

label var cusip6 "6-character CUSIP (identifies issuer)"


* Merge to Dynamic Name Mapping *

merge 1:m gvkey using "$data/019a_dynamicNames.dta"
/*

    Result                      Number of obs
    -----------------------------------------
    Not matched                        10,182
        from master                         0  (_merge==1)
        from using                     10,182  (_merge==2) -- All the ETF-like firms and firms missing CUSIPs in Compustat

    Matched                            53,491  (_merge==3)
    -----------------------------------------

*/
drop if _merge == 2 // We don't want these (ETF-like listings) or can't use them (no CUSIP in Compustat)

drop _merge // No longer needed


* Run Names Through Cleaning Algorithm *

rename name orig_name // For the cleaning algorithm

do "$code/500_nameCleaning.do" // Run name cleaning

rename orig_name name // The original name

rename clean_name_6 name_clean // The cleaned name

label var name_clean "Algorithmically cleaned version of variable 'name'"

drop clean_name_1 clean_name_2 clean_name_3 clean_name_4 clean_name_5 // No longer needed


* Export *

order gvkey wb_date1 wb_dateN name name_clean name_source name_linkDay1 name_linkDayN cusip9 cusip6

compress

save "$data/019b_cstatCUSIPs.dta", replace




/*
********************************************************************************
*** INFER LISTING SWITCHES/ACQUISITIONS FROM 6-DIGIT CUSIPS (NO DATA OUTPUT) ***
********************************************************************************

* Import gvkey-to-CUSIP Mapping *

use "$data/019b_cstatCUSIPs.dta", clear


* Drop Observations with 6-character CUSIPs that only Map to one gvkey *

quietly unique gvkey, by(cusip6) gen(nr_gvkeys)

bysort cusip6 (nr_gvkeys): replace nr_gvkeys = nr_gvkeys[1]

label var nr_gvkeys "Number of gvkeys associated with 6-character CUSIP"

drop if nr_gvkeys == 1



// At this point, we manually review observations where the 6-digit CUSIP maps to two or more gvkeys, since these are *occasionally* more complicated. We use the below code...

preserve
	sort cusip6 wb_dateN
	order cusip6
	keep if nr_gvkeys >= 2
	list
restore

*/