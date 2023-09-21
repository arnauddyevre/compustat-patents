/*

Oliver Seager
o.j.seager@lse.ac.uk
SE 17


Created: 20/03/2023
Last Modified: 04/04/2023


The purpose of this script is to get M&A and subsidiary data from SDC Platinum


Infiles:
- SDCplatinum8520_MandA.dta (All SDC Platinum data for M&A that become effective during the 1985-2020 period.)
- 019b_cstatCUSIPs.dta (A mapping of Compustat gvkeys to their 9- and 6-character CUSIPs, excluding ETFs and similar entities)


Outfiles:
- 019c_SDCplatinum8520_MandAtrimmed.dta (SDC Platinum data for complete acquisitions and mergers that become effective during the 1985-2020 period)
- 019c_SDCplatinumListedListedAuto.csv (An automatically generated file of listed-listed M&A activity as inferred from SDC Platinum data, merged to gvkeys via 6-character CUSIPs)


Called .do Files:
- 500_nameCleaning.do (The centralised name cleaning algorithm)


External Packages:
- unique by Tony Brady


*/

********************************************************************************
************************** PROCESS SDC PLATINUM DATA ***************************
********************************************************************************

// ABS take care of SDC Platinum for *certain firms* for the 1985-2015 period, but a slight majority are not considered in their sample.

* Import Original SDC Platinum Data *

use "$orig/SDC Platinum/SDCplatinum8520_MandA.dta", clear


* Get Lower Case Variable Names *

quietly ds // Gets variables into `r(varlist)'

foreach var in `r(varlist)'{
	
	rename `var' `=lower("`var'")' // Renames variable with its lowercase equivalent
	
}


* Retain Only M&A that Become Effective During 1985-2020 *

keep if yofd(dateeff) >= 1985 & yofd(dateeff) <= 2020 // Note that this drops missing values for dateeff, which indicate that the M or A was announced but never completed


* Drop Internal Transactions *

drop if aup == tup // We don't care about these


* Keep Only Total Acquisitions and Mergers *

keep if form == "Acq. Rem. Int." | form == "Acq. of Assets" | form == "Acquisition" | form == "Buyback" | form == "Merger" // We restrict our attention to acquisitions and mergers concerning whole companies, rather than partial ownership


* Export *

compress

save "$data/019c_SDCplatinum8520_MandAtrimmed.dta", replace





********************************************************************************
************************* MERGE SDC PLATINUM TO GVKEYS *************************
********************************************************************************

* Import SDC Platinum Data *

use "$data/019c_SDCplatinum8520_MandAtrimmed.dta", clear


* Drop Extraneous Variables *

drop dateann form tupnames tup entval eqval netass tass // Not needed - Note especially we don't actually care about the target's ultimate parent.

duplicates drop // Some duplicates are created by the above


* Merge Target CUSIP to Compustat *

rename master_cusip cusip6 // To facilitate the merge

joinby cusip6 using "$data/019b_cstatCUSIPs.dta" // If the acquired firm isn't in Compustat, we can't use it's acquisition as listed-listed M&A activity
/*
Appending unmatched(both), we obtain...

                       _merge |      Freq.     Percent        Cum.
------------------------------+-----------------------------------
          only in master data |    572,235       91.02       91.02 -- the M&A activity from SDC Platinum where the target doesn't feature in Compustat
           only in using data |     33,460        5.32       96.34 -- The gvkey-name pairs where the gvkey isn't ever a target in SDC Platinum
both in master and using data |     22,986        3.66      100.00 -- That which merges
------------------------------+-----------------------------------
                        Total |    628,681      100.00


*/
rename cusip6 master_cusip


* Drop Merges where the CRSP/Compustat Name is Extemporaneous to the Merge *

drop if (name_source == "CRSP" & (name_linkDay1 > dateeff | name_linkDayN < dateeff)) | (name_source == "Compustat" & (wb_date1 > dateeff | wb_dateN < dateeff)) // If the acquired firm isn't in Compustat *at the time of acquisition*, we don't use it's acquisition as listed-listed M&A activity


* Rename, Relabel Compustat Variables to be Target Specific *

foreach var in gvkey wb_date1 wb_dateN name name_clean name_source name_linkDay1 name_linkDayN cusip9{
	
	rename `var' tma_`var'
	
	local var_label: variable label tma_`var'
	
	label var tma_`var' "Target: `var_label'"
	
}


* Merge Acquiror Ultimate Parent CUSIP to Compustat *

rename aup cusip6 // To facilitate the merge

joinby cusip6 using "$data/019b_cstatCUSIPs.dta", unmatched(master) // We keep those from the master (M&A events where the target is in Compustat) even if the acquiror's ultimate parent doesn't feature in Compustat - its subsidiary might
/*
If we run with unmatched(both), we obtain...


                       _merge |      Freq.     Percent        Cum.
------------------------------+-----------------------------------
          only in master data |      1,486        2.69        2.69 -- Strictly: M&A events where the target is in Compustat and the acquiror's ultimate parent isn't.
           only in using data |     52,867       95.71       98.40 -- Strictly: gvkey-name pairs for gvkeys who are not ultimate parents to acquirors of Compustat firms
both in master and using data |        883        1.60      100.00 -- Everyone who merges
------------------------------+-----------------------------------
                        Total |     55,236      100.00

*/
rename cusip6 aup


* Flag Merges where the Compustat/CRSP Name is Extemporaneous to the Merge *

// We don't *drop* the M&A event as the acquiror itself (rather than the ultimate parent) might be listed in Compustat - think of how many firms are owned by shell holding companies that aren't securitised.

gen extemp_flag = 0 if _merge == 3

replace extemp_flag = 1 if _merge == 3 & ((name_source == "CRSP" & (name_linkDay1 > dateeff | name_linkDayN < dateeff)) | (name_source == "Compustat" & (wb_date1 > dateeff | wb_dateN < dateeff)))

label var extemp_flag "CRSP/Compustat name mapping is extemporaneous to the M&A event"

drop _merge // No longer needed


* Move Values of Ultimate Parent Variables to Missing where CRSP/Compustat Name is Extemporaneous *

foreach var in gvkey name name_clean name_source cusip9{ // String Variables
	
	replace `var' = "" if extemp_flag == 1
	
}

foreach var in wb_date1 wb_dateN name_linkDay1 name_linkDayN{ // Numeric Variables
	
	replace `var' = . if extemp_flag == 1
	
}

drop extemp_flag // No longer needed


* Rename, Relabel Compustat Variables to be Acquiror Ultimate Parent Specific *

foreach var in gvkey wb_date1 wb_dateN name name_clean name_source name_linkDay1 name_linkDayN cusip9{
	
	rename `var' aup_`var'
	
	local var_label: variable label aup_`var'
	
	label var aup_`var' "AUP: `var_label'"
	
}


* Merge Acquiror CUSIP to Compustat *

rename acusip cusip6 // To facilitate the merge

joinby cusip6 using "$data/019b_cstatCUSIPs.dta", unmatched(master) // We keep those from the master (M&A events where the target is in Compustat) even if the acquiror's ultimate parent doesn't feature in Compustat - its subsidiary might.
/*
If we run with unmatched(both), we obtain...
						
                       _merge |      Freq.     Percent        Cum.
------------------------------+-----------------------------------
          only in master data |      1,635        2.91        2.91 -- Strictly: M&A events where the target is in Compustat and the immediate acquiror isn't.
           only in using data |     52,948       94.15       97.06 -- Strictly: gvkey-name pairs for gvkeys who are not immediate acquirors of Compustat firms 
both in master and using data |      1,655        2.94      100.00 -- That which merges
------------------------------+-----------------------------------
                        Total |     56,238      100.00

*/
rename cusip6 acusip


* Flag Merges where the CRSP Name is Extemporaneous to the Merge *

// We don't *drop* the M&A event as the acquiror's parent (rather than the immediate acquiror) might be listed in Compustat.

gen extemp_flag = 0 if _merge == 3

replace extemp_flag = 1 if _merge == 3 & ((name_source == "CRSP" & (name_linkDay1 > dateeff | name_linkDayN < dateeff)) | (name_source == "Compustat" & (wb_date1 > dateeff | wb_dateN < dateeff)))

label var extemp_flag "CRSP/Compustat name mapping is extemporaneous to the M&A event"

drop _merge // No longer needed



* Move Values of Acquiror Variables to Missing where CRSP/Compustat Name is Extemporaneous *

foreach var in gvkey name name_clean name_source cusip9{ // String Variables
	
	replace `var' = "" if extemp_flag == 1
	
}

foreach var in wb_date1 wb_dateN name_linkDay1 name_linkDayN{ // Numeric Variables
	
	replace `var' = . if extemp_flag == 1
	
}

drop extemp_flag // No longer needed


* Rename, Relabel Compustat Variables to be Acquiror Specific *

foreach var in gvkey wb_date1 wb_dateN name name_clean name_source name_linkDay1 name_linkDayN cusip9{
	
	rename `var' ama_`var'
	
	local var_label: variable label ama_`var'
	
	label var ama_`var' "Acquiror: `var_label'"
	
}


* Drop Observations where Both Acquiror and Acquiror Ultimate Parent Name Mappings were Extemporaneous to M&A Event *

drop if missing(aup_gvkey) & missing(ama_gvkey)


* Drop Observations with gvkeyless Parents If Immediate Acquiror Has at Least One Parent with gvkey *

quietly unique aup_gvkey if !missing(aup_gvkey), by(acusip dateeff) gen(nr_gParents)

bysort acusip dateeff (nr_gParents): replace nr_gParents = nr_gParents[1]

label var nr_gParents "Number of immediate acquiror's parents with gvkeys at time of M&A event"

drop if missing(aup_gvkey) & nr_gParents > 0

drop nr_gParents // No longer needed


* Manually Resolve M&A Events Mapping to Multiple Acquiror Parents with gvkeys *

drop if acusip == "254687" & aup_gvkey == "126814" & dateeff == mdy(11, 18, 1999) // Disney's acquisition mapping to the short-lived Disney Internet Group subsidiary

drop if acusip == "023608" & aup_gvkey == "154353" & dateeff == mdy(10, 1, 2004) // Ameren's acquisition of Illinois Power mapped to their energy generation subsidiary

drop if acusip == "023608" & aup_gvkey == "154353" & dateeff == mdy(1, 31, 2003) // Ameren's acquisition of CILCORP mapped to their energy generation subsidiary


* Get Canonical Acquiror Information *

// We set this to the acquiror's ultimate parent where information on them is present, and to the immediate acquiror where it isn't

gen acq_gvkey = aup_gvkey if !missing(aup_gvkey)
replace acq_gvkey = ama_gvkey if missing(aup_gvkey)

label var acq_gvkey "Acquiror: Compustat unique firm identifier"

gen acq_name = aup_name if !missing(aup_gvkey)
replace acq_name = ama_name if missing(aup_gvkey)

label var acq_name "Acquiror: Company name"

gen acq_name_clean = aup_name_clean if !missing(aup_gvkey)
replace acq_name_clean = ama_name_clean if missing(aup_gvkey)

label var acq_name_clean "Acquiror: Algorithmically cleaned version of variable 'name'"

gen acq_sdcName = aupnames if !missing(aup_gvkey)
replace acq_sdcName = amanames if missing(aup_gvkey)

label var acq_sdcName "Acquiror: Name as appears in SDC Platinum"

gen acq_cusip = aup if !missing(aup_gvkey)
replace acq_cusip = acusip if missing(aup_gvkey)

label var acq_cusip "Acquiror: CUSIP as appears in SDC Platinum"


* Drop Extraneous Variables, Drop Duplicate *

drop tma_wb_date1 tma_wb_dateN tma_name_source tma_name_linkDay1 tma_name_linkDayN tma_cusip9 aup_gvkey aup_wb_date1 aup_wb_dateN aup_name aup_name_clean aup_name_source aup_name_linkDay1 aup_name_linkDayN aup_cusip9 ama_gvkey ama_wb_date1 ama_wb_dateN ama_name ama_name_clean ama_name_source ama_name_linkDay1 ama_name_linkDayN ama_cusip9 aupnames amanames aup acusip // No longer needed

duplicates drop // Generating a canon for the acquiror should create a fair few duplicates


* Drop Earlier M&A Event Where M&A Event has Two "Date Effective" Values *

// There's no more than a few days between the alternative effective dates

drop if tma_gvkey == "002599" & acq_gvkey == "003650" & dateeff == mdy(12, 5, 1986)

drop if tma_gvkey == "015065" & acq_gvkey == "028169" & dateeff == mdy(11, 15, 1995)


* Clean Target Name *

gen orig_name = upper(tmanames) // For the name cleaning algorithm

do "$code/500_nameCleaning.do" // Run the algorithm

rename clean_name_6 tmanames_clean

label var tmanames_clean "Algorithmically cleaned target name as appears in SDC Platinum"

drop orig_name clean_name_1 clean_name_2 clean_name_3 clean_name_4 clean_name_5 // Not needed


* Clean Acquiror Name *

gen orig_name = upper(acq_sdcName) // For the name cleaning algorithm

do "$code/500_nameCleaning.do" // Run the algorithm

rename clean_name_6 acq_sdcName_clean

label var acq_sdcName_clean "Algorithmically cleaned acquiror name as appears in SDC Platinum"

drop orig_name clean_name_1 clean_name_2 clean_name_3 clean_name_4 clean_name_5 // Not needed

order master_cusip tmanames tmanames_clean acq_cusip acq_sdcName acq_sdcName_clean dateeff tma_gvkey tma_name tma_name_clean acq_gvkey acq_name acq_name_clean // Seems more sensible


* Get Jaro Similarity Between Clean Compustat/CRSP and SDC Platinum Target Clean Names *

jarowinkler acq_sdcName_clean acq_name_clean, pwinkler(0) gen(acq_JaroSim)

label var acq_JaroSim "Jaro similarity between Compustat and SDC Platinum acquiror name"


* Get Jaro Similarity Between Clean Compustat/CRSP and SDC Platinum Acquiror Clean Names *

jarowinkler tmanames_clean tma_name_clean, pwinkler(0) gen(tma_JaroSim)

label var tma_JaroSim "Jaro similarity between Compustat and SDC Platinum target name"


* Retain Only Most Similar Pairs of Names in Terms of Jaro Similarity *

gen jaroProd = acq_JaroSim*tma_JaroSim

label var jaroProd "Product of Jaro similarities between clean names either side of M&A event"

bysort tma_gvkey acq_gvkey (jaroProd): gen to_drop = (_n < _N)

drop if to_drop == 1 // Doing this outside the bysort prevents messy output

drop to_drop


* Drop Erroneous M&A Events *

// Merging via 6-digit CUSIPs is horrendous. Basically half of the companies don't match up.

drop if master_cusip == "40399H" // Drinks manufacturer and a toymaker
drop if master_cusip == "09799X" // PR firm and an aerospace manufacturer
drop if master_cusip == "28199A" // Education provider and a power company
drop if master_cusip == "85799F" // Possibly just a subsidiary of the company in Compustat
drop if master_cusip == "05491N" // Possibly just a subsidiary of the company in Compustat

drop if master_cusip == "05490U" // Company doing tool rental and a financial services company
drop if master_cusip == "48599X" // Loungewear and Gas & Electric
drop if master_cusip == "40199Y" // Can't trace one of these, but they have a similar spelling
drop if master_cusip == "87299X" // Construction communications and an insurer
drop if master_cusip == "90399Y" // Telecoms and steel

drop if master_cusip == "87265Y" // Possibly just a subsidiary of the company in Compustat
drop if master_cusip == "91705J" // Plastics processor and broadcaster
drop if master_cusip == "23254K" // Energy and synthetic human tissue production
drop if master_cusip == "40699Z" // Human resources and an investment bank
drop if master_cusip == "29364N" // Banking and energy

drop if master_cusip == "32072L" // Banking and lithium mining
drop if master_cusip == "83851M" // Online gaming and petrol retail
drop if master_cusip == "65445T" // Online news and metals
drop if master_cusip == "98399Z" // Management software and broadcasting
drop if master_cusip == "13199K" // Spanish securities broker and power generation

drop if master_cusip == "695172" // Subsidiary of Compustat firm
drop if master_cusip == "97815W" // Banking and golf
drop if master_cusip == "14199R" // Heart surgery instruments and CO2 recycling technologies
drop if master_cusip == "67001V" // Oil drilling and oncological diagnostic tools
drop if master_cusip == "74993W" // Gas measurement and marketing

drop if master_cusip == "70285H" // Pasta and branding
drop if master_cusip == "78646R" // I'm giving up pointing out the differences now because that's taking too long
drop if master_cusip == "90699Z"
drop if master_cusip == "73930R"
drop if master_cusip == "02155X"

drop if master_cusip == "46099X"
drop if master_cusip == "03937C"
drop if master_cusip == "00439T"
drop if master_cusip == "96810C"
drop if master_cusip == "09059L"

drop if master_cusip == "13126R"
drop if master_cusip == "73108L"
drop if master_cusip == "00499Y"
drop if master_cusip == "71648P"
drop if master_cusip == "88583P"

drop if master_cusip == "58462L"
drop if master_cusip == "68752M"
drop if master_cusip == "09629F"
drop if master_cusip == "74257P"
drop if master_cusip == "86768C"

drop if master_cusip == "12532H"
drop if master_cusip == "45899F"
drop if master_cusip == "74531E"
drop if master_cusip == "500902" // Covered in manual changes
drop if master_cusip == "43114K"

drop if master_cusip == "87901J"
drop if master_cusip == "459759"
drop if master_cusip == "236273"
drop if master_cusip == "002078"
drop if master_cusip == "208368"

drop if master_cusip == "00831X"
drop if master_cusip == "857323"

drop if acq_cusip == "461449"
drop if acq_cusip == "478160"
drop if acq_cusip == "037612"

/*
// To attain the above, we review every transaction where the Jaro product is less than one, inspecting each side of the transactions separately, using the below code...

sort tma_JaroSim 
list master_cusip tmanames tmanames_clean tma_gvkey tma_name tma_name_clean dateeff tma_JaroSim if tma_JaroSim < 1

// ...then we delete all the master cusips as above and run the below...

sort acq_JaroSim 
list acq_cusip acq_sdcName acq_sdcName_clean acq_gvkey acq_name acq_name_clean dateeff acq_JaroSim if acq_JaroSim < 1

...and then verify the perfect matches by running...

sort tma_JaroSim 
list master_cusip tmanames tmanames_clean tma_gvkey tma_name tma_name_clean dateeff tma_JaroSim

...and...
sort acq_JaroSim 
list acq_cusip acq_sdcName acq_sdcName_clean acq_gvkey acq_name acq_name_clean dateeff acq_JaroSim
*/


* Drop Extraneous Variables *

// ...we now restructure the data to our standard variable structure: gvkey_primary-gvkey_secondary-year-source-type

keep dateeff tma_gvkey acq_gvkey


* Get Year of Merger/Acquisition *

gen year = yofd(dateeff)

label var year "Year effective"

drop dateeff // We try to keep it to years rather than days.


* Rename, Reorder Variables to Our Standard M&A Format *

rename tma_gvkey gvkey_secondary

rename acq_gvkey gvkey_primary

order gvkey_primary gvkey_secondary year


* Drop Firms That Appear to Acquire Themselves (via Distinct CUSIPs) *

drop if gvkey_primary == gvkey_secondary


* Get Source, Type Variables *

gen source = "SDC Platinum - Automated"

label var source "Source of M&A event data"

gen type = "Merger or Acquisition"

label var type "Type of M&A event"


* Export to .csv *

export delimited using "$data/019c_SDCplatinumListedListedAuto.csv", replace // We just copy and paste this into the centralised M&A file