/*

Oliver Seager
o.j.seager@lse.ac.uk
SE 17


Created: 11/04/2023
Last Modified: 23/06/2023


The purpose of this script is to map name-years to their "ultimate owner" gvkeys, which assists in the centralisation of the knowledge base of a corporate entity at a given time under its highest-level listed company in Compustat.


Infiles:
- 019e_dynamicNamesClean_matched.dta (A dynamic mapping of clean names [that also feature in our patent dataset] to gvkeys)
- 019d_whoOwnsWhomAndWhen_gvkeys.dta (A list of child-ultimate_parent relationships between gvkeys, at the gvkey-gvkey level)
- 019a_cstatPresence.dta (Each gvkey in Compustat with their first and last years present in the dataset)
- 019d_chainsOfOwnership.dta (A list of all chains of ownership between gvkeys, with years of validity and an indicator on later divorce from parent for each constituent member)


Outfiles:
- 019f_cstatPresenceByUltimateOwner.dta (Inclusive *only* of gvkeys associated with clean names that also feature in our patent data, gvkey in Compustat with their first and last years present in the dataset by ultimate owner gvkeys)
- 019f_whoOwnsWhomAndWhen_nameUOs.dta.dta (A mapping of clean names to ultimate parent gvkeys, with the original names that produced them and the gvkeys they are mapped through, at the clean_name-gvkey level)
- 019f_whoOwnsWhomAndWhen_ReassignmentFriendly.dta (A mapping of clean names to ultimate parent gvkeys, but with a "for reassignment" gvkey that allows the transfer of ownership of patents away from the ultimate owner)


Called .do Files:
None


External Packages:
None


*/

********************************************************************************
********** GET COMPUSTAT PRESENCE OF EACH GVKEY BY ULTIMATE OWNERSHIP **********
********************************************************************************

* Import Cleaned and Matched Dynamic Names *

use "$data/019e_dynamicNamesClean_matched.dta", clear


* Reduce to gvkey Level *

keep gvkey

duplicates drop


* 1:m Merge to All Ultimate Owner gvkeys *

merge 1:m gvkey using "$data/019d_whoOwnsWhomAndWhen_gvkeys.dta"
/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                        31,537
        from master                         0  (_merge==1)
        from using                     31,537  (_merge==2) -- Recall that we're only using gvkeys that are associated with clean names that feature in our patent dataset. These are all observations for gvkeys that don't meet this criterion.

    Matched                            12,197  (_merge==3) -- Everything from the master merges.
    -----------------------------------------
*/
drop if _merge == 2 // Not needed. See above

drop _merge // No longer informative


* Merge Ultimate Owner gvkeys to their Active Years in Compustat *

rename gvkey PH // We need this variable name for the merge

rename gvkey_uo gvkey // Facilitates merge

merge m:1 gvkey using "$data/019a_cstatPresence.dta"
/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                        29,950
        from master                         0  (_merge==1)
        from using                     29,950  (_merge==2) -- Again, we're only using gvkeys that are associated with clean names that feature in our patent dataset. These are all observations for gvkeys that don't meet this criterion.

    Matched                            12,197  (_merge==3) -- Everything from the master, again, merges
    -----------------------------------------
*/
drop if _merge == 2 // Not needed. See above

drop _merge // No longer informative

rename gvkey gvkey_uo // Return to original names

rename PH gvkey


* Get Last Year of Presence for gvkey or Any Owner Thereof *

bysort gvkey: egen gvkey_lastYear = max(yPresentN)

label var gvkey_lastYear "Last year (calendar or fiscal) gvkey or owner thereof is present in Compustat"


* Drop Extraneous Variables *

drop gvkey_uo year1 yearN yPresent1 yPresentN // No longer needed

duplicates drop // Created by varied ownership of gvkeys


* Export *

compress

save "$data/019f_cstatPresenceByUltimateOwner.dta", replace





********************************************************************************
******* GET AT-THE-TIME OWNERSHIP OF CLEAN NAMES BY ULTIMATE OWNER GVKEYS ******
********************************************************************************

/* 
Essentially what we do here is push the association between a clean name and its ultimate owner gvkeys forward as far as possible. 
Suppose, for example... 
- The clean name "ALPHACORP" is associated with gvkey 1 for its entire tenure in Compustat, from 1950-1959. 
- gvkey 1 is then effectively acquired by gvkey 2 in 1960. 
- gvkey 2 runs in Compustat from 1950-1989. 
- However, an unrelated company, also with the clean name "ALPHACORP", lists as gvkey 3 in Compustat for 1970-1979.

In this case we want...
- "ALPHACORP" to map to gvkey 1 for 1950-1959
- "ALPHACORP" to map to gvkey 2 for 1960-1969
- "ALPHACORP" to map to gvkey 3 for 1970-1979
- "ALPHACORP" to be retired from 1980 onwards
*/

* Import Cleaned and Matched Names *

use "$data/019e_dynamicNamesClean_matched.dta", clear


* Get First Year of Association for Each Clean Name *

bysort gvkey clean_name: egen gvkeyCNyear1 = min(yofd(name_linkDay1))

label var gvkeyCNyear1 "First year clean name is (immediately) associated with gvkey"


* Reduce to gvkey x Clean Name Level *

keep gvkey clean_name gvkeyCNyear1 

duplicates drop


* Merge to gvkey Final Year of Presence in Compustat by Ownership *

merge m:1 gvkey using "$data/019f_cstatPresenceByUltimateOwner.dta"
/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                             0
    Matched                            12,291  (_merge==3) -- All merge by construction
    -----------------------------------------
*/
drop _merge // Not informative


* Expand to gvkey x Clean Name x Year Level *

expand (gvkey_lastYear - gvkeyCNyear1 + 1)

bysort gvkey clean_name gvkey_lastYear gvkeyCNyear1: gen year = gvkeyCNyear1 - 1 + _n

label var year "Year in which clean_name is feasibly associated with gvkey"


* Manual Dropping of Links (Erroneous Matches) *

drop if clean_name == "ASA" // Neither of these firms correctly match to patents
drop if clean_name == "CHILTON" // This is also incorrectly matching
drop if clean_name == "MDC" // Neither of these match
drop if clean_name == "PARTECH" // Neither of these are the correct Partech
drop if clean_name == "PREMIER" // Neither of these are the correct Premier
drop if clean_name == "PUBLICSVC" // Unclear which public service company files a single patent in 1931, but this creates the need for a resolution. We drop this for want of a better solution.


* Manual Dropping of Links (Resolution of Duplicates) *

// We've looked in the patent database to verify what name should link to what gvkey *as far as matching patents is concerned*. Sometimes one name maps to gvkeys, so we either adjust our M&A database or, as below, look into the original name of the patenter on both the acounting and patent side to decide which gvkey's name to drop from the data and when.

drop if gvkey == "010934" & clean_name == "AMERNCAPITAL"
drop if gvkey == "032855" & clean_name == "AVAYA"
drop if gvkey == "021060" & clean_name == "BANKERS"
drop if (gvkey == "123394" | gvkey == "028387") & clean_name == "CARLISLE"
drop if gvkey == "016775" & clean_name == "CITIZENS"

drop if gvkey == "002537" & clean_name == "CNET"
drop if gvkey == "161072" & clean_name == "COMSTOCK"
drop if gvkey == "003581" & clean_name == "CRAWFORD"
drop if gvkey == "062364" & clean_name == "COOPER"
drop if gvkey == "174094" & clean_name == "EXCELTECH"

drop if gvkey == "023864" & clean_name == "EXTERRAN"
drop if gvkey == "023821" & clean_name == "GANNETT"
drop if gvkey == "005403" & clean_name == "HEI"
drop if gvkey == "039676" & clean_name == "IHS"
drop if gvkey == "003044" & clean_name == "IMPERIALGP"

drop if gvkey == "030098" & clean_name == "INGERSOLLRAND"
drop if gvkey == "140758" & clean_name == "IPEC"
drop if gvkey == "007699" & clean_name == "NAC"
drop if (gvkey == "008173" | gvkey == "014057") & clean_name == "ORANGE"
drop if gvkey == "008488" & clean_name == "PERKINELMER"

drop if gvkey == "014380" & clean_name == "PIONEER"
drop if gvkey == "013342" & clean_name == "RLI"
drop if gvkey == "009542" & clean_name == "SEACO"
drop if gvkey == "010001" & clean_name == "STANDARDOIL" // We drop Sohio here - a choice has to made
drop if gvkey == "024783" & clean_name == "TETRATECH"

drop if gvkey == "010302" & clean_name == "TSC"
drop if gvkey == "014271" & clean_name == "UNICO"
drop if gvkey == "010872" & clean_name == "UNION"
drop if gvkey == "011858" & clean_name == "UST"
drop if gvkey == "001382" & clean_name == "USWEST"

drop if gvkey == "063912" & clean_name == "VITECH"
drop if gvkey == "011226" & clean_name == "VULCAN"
drop if (gvkey == "011505" | gvkey == "014821") & clean_name == "WILLIAMS"
drop if gvkey == "001067" & clean_name == "ATI" & year <= 1976
drop if gvkey == "001254" & clean_name == "ALEXANDERANDBALDWIN" & year >= 2011

drop if gvkey == "001995" & clean_name == "BALTIMOREGASANDELEC" & year == 1999
drop if gvkey == "002338" & clean_name == "BOWATER" & year >= 1983
drop if gvkey == "012791" & clean_name == "BROADCASTINT" & year <= 1994
drop if gvkey == "002812" & clean_name == "CASTLEANDCOOKE" & year == 1991
drop if gvkey == "065006" & clean_name == "CALDIVEINT" & year == 2006

drop if gvkey == "003255" & clean_name == "COMMONWEALTHEDISON" & year == 1994
drop if gvkey == "121819" & clean_name == "DIADEXUS" & year <= 2004
drop if gvkey == "009177" & clean_name == "ENDEVCO" & year <= 2003
drop if gvkey == "060874" & clean_name == "ENRON" & year <= 1985
drop if gvkey == "007745" & clean_name == "NATLSTEEL" & year == 1983

drop if gvkey == "026061" & clean_name == "IACINTERACTIVECORP" & year >= 2018
drop if gvkey == "010484" & clean_name == "UNITEDAIRLINES" & year < 2010
drop if gvkey == "017269" & clean_name == "USBANCORP" & year == 2001
drop if gvkey == "005342" & clean_name == "VIAD" & year >= 2003


* Drop Years After Gaps *

// The above manual resolution code was written with respect to the years of association strictly implied by the data. We extend this to, say, all years *after* 1983 for gvkey 007745

bysort gvkey clean_name gvkeyCNyear1 gvkey_lastYear (year): gen postGap = 0 if _n == 1

bysort gvkey clean_name gvkeyCNyear1 gvkey_lastYear (year): replace postGap = (year == year[_n-1] + 2) if _n > 1

bysort gvkey clean_name gvkeyCNyear1 gvkey_lastYear (year): replace postGap = 1 if postGap[_n-1] == 1

label var postGap "gvkey x clean_name x year requires dropping following manual resolution"

drop if postGap == 1 

drop postGap


* Get gvkey x clean_name "Runs" *

drop gvkeyCNyear1 gvkey_lastYear // No longer needed

bysort gvkey clean_name (year): gen gvkeyCNrun = 1 if _n == 1

bysort gvkey clean_name (year): replace gvkeyCNrun = gvkeyCNrun[_n-1] + (year > year[_n-1] + 1) if _n > 1

label var gvkeyCNrun "Run of consecutive-years association with clean_name, ID within gvkey-clean_name" // These are, thankfully, all just 1


* Reduce to gvkey x Clean Name x gvkeyCNrun Level *

bysort gvkey clean_name gvkeyCNrun: egen gvkeyCNyear1 = min(year)

label var gvkeyCNyear1 "First year clean_name associated with gvkey"

bysort gvkey clean_name gvkeyCNrun: egen gvkeyCNyearN = max(year)

label var gvkeyCNyearN "Last year clean_name *feasibly* associated with gvkey"

drop year // Only variable not fixed within gvkey x Clean Name x gvkeyCNrun

duplicates drop


* Drop Extraneous Variables *

drop gvkeyCNrun


* Joinby to Ultimate Owner gvkeys *

joinby gvkey using "$data/019d_whoOwnsWhomAndWhen_gvkeys.dta", unmatched(both)
/*
                       _merge |      Freq.     Percent        Cum.
------------------------------+-----------------------------------
           only in using data |     31,581       70.10       70.10 -- The ownership of gvkeys not associated with any clean names that feature in the patent data
both in master and using data |     13,469       29.90      100.00 -- All data from the master merge
------------------------------+-----------------------------------
                        Total |     45,050      100.00
*/
drop if _merge == 2

drop _merge


* Drop Extemporaneous Ultimate Owner Data *

drop if year1 > gvkeyCNyearN // M&A event takes place after both parties delist or name manually unlinked from gvkey

drop if yearN < gvkeyCNyear1 // Ownership ends before association with clean name begins


* Get Feasibility Boundaries of Association Between Clean Name and Ultimate Owner gvkey via Immediate Owner gvkey *

gen gvkey_uoCNyear1 = max(year1, gvkeyCNyear1)

label var gvkey_uoCNyear1 "First year of association between clean name and gvkey_uo via gvkey"

gen gvkey_uoCNyearN = min(yearN, gvkeyCNyearN)

label var gvkey_uoCNyearN "Last year of *feasible* association between clean name and gvkey_uo via gvkey"


* Expand to gvkey_uo x clean_name x Feasible Year Level *

keep gvkey_uo clean_name gvkey_uoCNyear1 gvkey_uoCNyearN // At this point we aren't bothered about which immediate owner gvkey the clean name links to the ultimate owner gvkey through

duplicates drop

expand (gvkey_uoCNyearN - gvkey_uoCNyear1 + 1)

bysort gvkey_uo clean_name gvkey_uoCNyearN gvkey_uoCNyear1: gen year = gvkey_uoCNyear1 - 1 + _n

label var year "Year of feasible association between gvkey_uo and clean name"

drop gvkey_uoCNyearN gvkey_uoCNyear1

duplicates drop


* Get Run of Feasible Ownership for Each Ultimate Owner gvkey x Clean Name Pair *

bysort gvkey_uo clean_name (year): gen gvkey_uoCNyear1ofRun = year if _n == 1

bysort gvkey_uo clean_name (year): replace gvkey_uoCNyear1ofRun = max(gvkey_uoCNyear1ofRun[_n-1]*(year <= year[_n-1] + 1), year*(year > year[_n-1] + 1)) if _n > 1

label var gvkey_uoCNyear1ofRun "First year of consecutive-years clean_name-gvkey_uo association"


* Assign Each Clean Name x Year to the Ultimate Owner Gvkey with the Most Recently Commenced Run of Feasible Ownership *

bysort clean_name year (gvkey_uoCNyear1ofRun): drop if gvkey_uoCNyear1ofRun < gvkey_uoCNyear1ofRun[_N] // Observations are now unique at the clean_name-year level


* Drop Another Round of Post-Gap Years within the Same "Ownership Run" *

// For example, VIACOM is associated with gvkey_uo 013714 for 1987-2005, and then with gvkey_uo 165675 for 2006-2018. In 2018 165675 delists. Thus, we don't want VIACOM to be associated with 013714 for 2019-2020 unless this is through genuine ownership (whereby we would have gvkey_uoCNyear1ofRun == 2019)

bysort clean_name gvkey_uo gvkey_uoCNyear1ofRun (year): gen postGap = 0 if _n == 1

bysort clean_name gvkey_uo gvkey_uoCNyear1ofRun (year): replace postGap = (year > year[_n-1] + 1) if _n > 1

bysort clean_name gvkey_uo gvkey_uoCNyear1ofRun (year): replace postGap = 1 if postGap[_n-1] == 1

label var postGap "gvkey_uo x clean_name x year requires dropping"

drop if postGap == 1 

drop postGap


* Reduce to gvkey_uo x Clean Name x Ownership Run Level *

bysort clean_name gvkey_uo gvkey_uoCNyear1ofRun: egen cnLink_y1 = min(year)

label var cnLink_y1 "First year of link between gvkey_uo and clean name"

bysort clean_name gvkey_uo gvkey_uoCNyear1ofRun: egen cnLink_yN = max(year)

label var cnLink_yN "Last year of link between gvkey_uo and clean name"

drop year gvkey_uoCNyear1ofRun // No longer needed

duplicates drop


* Joinby to All gvkeys Owned (Including Self) by gvkey_uo *

joinby gvkey_uo using "$data/019d_whoOwnsWhomAndWhen_gvkeys.dta", unmatched(both)
/*
                       _merge |      Freq.     Percent        Cum.
------------------------------+-----------------------------------
           only in using data |     31,179       65.26       65.26 -- Ownership of gvkeys not associated with clean names that feature in our patent data.
both in master and using data |     16,597       34.74      100.00 -- Everything from the master merges.
------------------------------+-----------------------------------
                        Total |     47,776      100.00

*/
drop if _merge == 2 // See above

drop _merge


* Drop gvkey-gvkey_uo Links That Start After the Clean Name Link *

drop if year1 > cnLink_yN


* Joinby to the Relevant gvkey-clean_name Pairs *

joinby gvkey clean_name using "$data/019e_dynamicNamesClean_matched.dta", unmatched(both)
/*
                       _merge |      Freq.     Percent        Cum.
------------------------------+-----------------------------------
          only in master data |      3,153       16.38       16.38 -- gvkeys that are owned by the gvkey_uo at the relevant time, but are not associated with the given clean_name
           only in using data |         67        0.35       16.72 -- Those links that were manually dropped above
both in master and using data |     16,034       83.28      100.00 -- Note that all 12,793 clean_name-gvkey_uo-cnLink_y1-cnLink_yN groupings from the master merge at least once
------------------------------+-----------------------------------
                        Total |     19,254      100.00
*/
keep if _merge == 3 // To reiterate, we don't lost any of the 12,793 clean_name-gvkey_uo-cnLink_y1-cnLink_yN groupings from the master here

drop _merge // No longer needed


* Drop if The Clean Name is Not Associated with the gvkey Until After the Gvkey's Ownership *

drop if yofd(name_linkDay1) > cnLink_yN // Again, we still have all 12,793 clean_name-gvkey_uo-cnLink_y1-cnLink_yN groupings after this


* Drop Extraneous Variables *

drop year1 yearN wb_date1 wb_dateN

duplicates drop // Created by gvkey_uos that own a gvkey twice


* Get Years of Links Between name and gvkey *

gen name_year1 = yofd(name_linkDay1)

label var name_year1 "First year 'name' strictly links to gvkey"

gen name_yearN = yofd(name_linkDayN)

label var name_yearN "Last year 'name' strictly links to gvkey"

drop name_linkDay1 name_linkDayN


* Reshape to clean_name-gvkey_uo-cnLink_y1-cnLink_yN Level *

bysort clean_name gvkey_uo cnLink_y1 cnLink_yN (name_year1 gvkey): gen _j = _n

label var _j "Reshape facilitator"

quietly summ _j // Gets the future width of the dataset into `=r(max)'

local width = `=r(max)'

reshape wide gvkey name name_year1 name_yearN name_source, i(clean_name gvkey_uo cnLink_y1 cnLink_yN) j(_j)

forvalues i = 1/`width'{
	
	label var gvkey`i' "gvkey through which name`i' maps to gvkey_uo, producing the clean name link"
	
	label var name`i' "Name #`i' producing link between gvkey_uo and clean_name"
	
	rename name_year1`i' name`i'_year1
	
	label var name`i'_year1 "First year name`i' strictly links to gvkey`i'"
	
	rename name_yearN`i' name`i'_yearN
	
	label var name`i'_yearN "Last year name`i' strictly links to gvkey`i'"
	
	rename name_source`i' name`i'_source
	
	label var name`i'_source "Source of data linking name`i' to gvkey`i'"
	
}


* Push Clean Name Ownership Back by Up to 54 Years *

// This allows a firm active in Compustat in 1950 to claim as part of its patent stock a patent granted in 1926 that took 30 years from application to patent.

bysort clean_name (cnLink_y1): replace cnLink_y1 = cnLink_y1 - 54 if _n == 1

bysort clean_name (cnLink_y1): replace cnLink_y1 = max(cnLink_y1 - 54, cnLink_yN[_n-1] + 1) if _n > 1


* Export *

compress

save "$data/019f_whoOwnsWhomAndWhen_nameUOs.dta", replace





********************************************************************************
********************* GET REASSIGNABLE OWNERSHIP OF NAMES **********************
********************************************************************************

// Suppose a patent is applied for under the name "ALPHACORP" in 1982, the trading name of gvkey 51. Suppose that in 1982 gvkey 51 is owned by gvkey 62, but in 1985 gvkey 62 sells it to gvkey 73. We then want, for 1985, the patent to be part of gvkey 73's patent stock but not gvkey 62. We achieve this by using our gvkeyFR variable.

* Import Who Owns Whom and When Ultimate Owner Data *

use "$data/019f_whoOwnsWhomAndWhen_nameUOs.dta", clear


* Flag Whether Clean Name Mapped to gvkey Through Single Subsidiary *

gen singleSubs = ((gvkey1 == gvkey2 | missing(gvkey2)) & (gvkey1 == gvkey3 | missing(gvkey3)) & (gvkey1 == gvkey4 | missing(gvkey4)) & (gvkey1 == gvkey5 | missing(gvkey5)) & (gvkey1 == gvkey6 | missing(gvkey6)) & (gvkey1 == gvkey7 | missing(gvkey7)))

label var singleSubs "Clean name mapped to gvkey_uo via single subsidiary gvkey (possibly self)"


* Get Single Subsidiary Variable *

gen gvkey_secondary = gvkey1 if singleSubs == 1

label var gvkey_secondary "Sole subsidiary (possibly self) mapping clean_name to gvkey_uo"


* Merge to Later Divorced Data *

rename gvkey_uo gvkey_primary

joinby gvkey_primary gvkey_secondary using "$data/019d_chainsOfOwnership.dta", unmatched(both)
/*
                       _merge |      Freq.     Percent        Cum.
------------------------------+-----------------------------------
          only in master data |        519        1.14        1.14 -- Every observation where the clean_name maps to gvkey_uo through multiple subsidiary gvkeys
           only in using data |     32,560       71.79       72.94 -- Chains of ownership that don't concern any clean_names that feature in our patent data
both in master and using data |     12,274       27.06      100.00 -- Every observation with singleSubs == 1
------------------------------+-----------------------------------
                        Total |     45,353      100.00
*/
drop if _merge == 2 // Not needed

drop _merge // Can be inferred from singleSubs

rename gvkey_primary gvkey_uo


* Initiate gvkeyFR Variable *

gen gvkeyFR = gvkey_uo if singleSubs == 0 | ((gvkS_laterDivorced == 0 | missing(gvkS_laterDivorced)) & (gvkT1_laterDivorced == 0 | missing(gvkT1_laterDivorced)) & (gvkT2_laterDivorced == 0 | missing(gvkT2_laterDivorced)) & (gvkT3_laterDivorced == 0 | missing(gvkT3_laterDivorced))) // If no subsidiaries are later divorced, or multiple subsidiaries map the same clean name to gvkey_uo, we use this as the gvkey for reassignment

label var gvkeyFR "gvkey used for patent reassignment"


* Replace gvkeyFR with Lowest Tier Later-divorced gvkey Where Appropriate *

replace gvkeyFR = gvkeyIntTier1 if gvkT1_laterDivorced == 1

replace gvkeyFR = gvkeyIntTier2 if gvkT2_laterDivorced == 1

replace gvkeyFR = gvkeyIntTier3 if gvkT3_laterDivorced == 1

replace gvkeyFR = gvkey_secondary if gvkS_laterDivorced == 1

drop gvkS_laterDivorced gvkT1_laterDivorced gvkT2_laterDivorced gvkT3_laterDivorced year1 yearN 


* Re-name, Re-label, Re-order Variables *

rename gvkey_secondary gvkeyCNoriginator

label var cnLink_y1 "First year of link between gvkey_uo, gvkeyFR, and clean_name"

label var cnLink_yN "Last year of link between gvkey_uo, gvkeyFR, and clean_name"

label var gvkeyIntTier1 "Great-grandparent of gvkeyCNoriginator, ultimately owned by gvkey_uo"

label var gvkeyIntTier2 "Grandparent of gvkeyCNoriginator, ultimately owned by gvkey_uo"

label var gvkeyIntTier3 "Parent of gvkeyCNoriginator, ultimately owned by gvkey_uo"

order clean_name gvkey_uo gvkeyFR cnLink_y1 cnLink_yN gvkey1 name1 name1_source name1_year1 name1_yearN gvkey2 name2 name2_source name2_year1 name2_yearN gvkey3 name3 name3_source name3_year1 name3_yearN gvkey4 name4 name4_source name4_year1 name4_yearN gvkey5 name5 name5_source name5_year1 name5_yearN gvkey6 name6 name6_source name6_year1 name6_yearN gvkey7 name7 name7_source name7_year1 name7_yearN singleSubs gvkeyIntTier1 gvkeyIntTier2 gvkeyIntTier3 gvkeyCNoriginator


* Change gvkeyFR for Firms Later Subject to Reverse Spin-Off *

replace gvkeyFR = "005342A" if gvkey_uo == "005342" & (clean_name == "GREYHOUND" | clean_name == "VIAD") // Viad/Moneygram
replace cnLink_yN = 2002 if gvkey_uo == "005342" & (clean_name == "GREYHOUND" | clean_name == "VIAD")

set obs `=(_N + 1)' // Because Greyhound is an old name of 005342, we need a new observation for it. This isn't required for any other reverse spin-offs
replace clean_name = "GREYHOUND" if _n == _N 
replace cnLink_y1 = 2003 if _n == _N
replace cnLink_yN = 2020 if _n == _N
replace gvkey_uo = "160785" if _n == _N
replace gvkeyFR = "160785" if _n == _N
replace name1 = "GREYHOUND CORP" if _n == _N
replace name1_source = "Manual" if _n == _N

replace gvkeyFR = "005776A" if gvkey_uo == "005776" & clean_name == "HUMANA" // Humana/Galen Healthcare

replace gvkeyFR = "026061A" if gvkey_uo == "026061" & clean_name == "HSN" // HSN/US Networks

replace gvkeyFR = "026061B" if gvkey_uo == "026061" & clean_name == "IACINTERACTIVECORP" //IAC Interactive/Match Group

replace gvkeyFR = "007536A" if gvkey_uo == "007536" & clean_name == "MONSANTO" // Monsanto/Pharmacia
drop if gvkey_uo == "008530" & clean_name == "MONSANTO"
replace cnLink_yN = 2015 if clean_name == "MONSANTO" & gvkey_uo == "140760"

replace gvkeyFR = "001254A" if gvkey_uo == "001254" & clean_name == "ALEXANDERANDBALDWIN" // Alexander & Baldwin/Matson

replace gvkeyFR = "002812A" if gvkey_uo == "002812" & clean_name == "CASTLEANDCOOKE" // Castle & Cooke/Dole Food


* Compress, Export *

compress

save "$data/019f_whoOwnsWhomAndWhen_ReassignmentFriendly.dta", replace