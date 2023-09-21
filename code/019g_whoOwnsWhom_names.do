/*

Oliver Seager
o.j.seager@lse.ac.uk
SE 17


Created: 11/04/2023
Last Modified: 13/07/2023


The purpose of this script is to map name-years to their "ultimate owner" gvkeys, which assists in the centralisation of the knowledge base of a corporate entity at a given time under its highest-level listed company in Compustat.


Infiles:
- 017f_patents_homogenised.dta (Observations are patents along with their associated original name, associated clean name, data source indicator, and indicators for the methods used to alter the associated clean name.)
- 019e_dynamicNamesClean.dta (A dynamic mapping of names, as cleaned by the Dyèvre-Seager algorithm, to gvkeys)
- 019d_whoOwnsWhomAndWhen_gvkeys.dta (A list of child-ultimate_parent relationships between gvkeys, at the gvkey-gvkey level)
- 019a_cstatPresence.dta (Each gvkey in Compustat with their first and last years present in the dataset)
- 019d_chainsOfOwnership.dta (A list of all chains of ownership between gvkeys, with years of validity and an indicator on later divorce from parent for each constituent member)


Outfiles:
- 019g_dynamicNamesCleanManualAdd_matched.dta (A dynamic mapping of names, as cleaned by the Dyèvre-Seager algorithm, to gvkeys, augmented with high-patent firms erroneously unmatched to publicly-listed firms by the automated procedure)
- 019g_cstatPresenceByUltimateOwner.dta (Inclusive *only* of gvkeys associated with clean names that also feature in our patent data, gvkey in Compustat with their first and last years present in the dataset by ultimate owner gvkeys)
- 019g_whoOwnsWhomAndWhen_nameUOs.dta.dta (A mapping of clean names to ultimate parent gvkeys, with the original names that produced them and the gvkeys they are mapped through, at the clean_name-gvkey level)
- 019g_whoOwnsWhomAndWhen_ReassignmentFriendly.dta (A mapping of clean names to ultimate parent gvkeys, but with a "for reassignment" gvkey that allows the transfer of ownership of patents away from the ultimate owner)


Called .do Files:
None


External Packages:
None


*/

********************************************************************************
********************* MANUALLY INCORPORATE UNMATCHED FIRMS *********************
********************************************************************************

/*
The below code gets the top 500 *unmatched* patenting names from the data *with original names in "inspection1.csv"* or just in general in "inspection2.csv"...

use "$data/019e_dynamicNamesClean_matched.dta", clear
keep clean_name
duplicates drop
append using "$data/019f_subsidiariesCleanedAndCutAgain.dta"
keep clean_name
duplicates drop
merge 1:m clean_name using "$data/019e_patentsHomogenised_wDates.dta", keep(2) keepusing(appYear patentName)
gen patent_count = 1
collapse (sum) patent_count (min) appYear1 = appYear (mean) appYearMean = appYear (max) appYearN = appYear, by(clean_name patentName)
bysort clean_name: egen cnPc = sum(patent_count)
gen cnWeight = patent_count/cnPc
bysort clean_name: egen cnAYm = sum(appYearMean*cnWeight)
drop cnWeight
bysort clean_name (appYear1): gen cnAY1 = appYear1[1]
bysort clean_name (appYearN): gen cnAYN = appYearN[_N]
replace appYearMean = round(appYearMean)
replace cnAYm = round(cnAYm)
gsort -cnPc clean_name -patent_count patentName
gen withinCNrawRank = 1 if _n == 1 | clean_name != clean_name[_n-1]
replace withinCNrawRank = withinCNrawRank[_n-1] + 1 if clean_name == clean_name[_n-1]
gen withinCNrank = withinCNrawRank if withinCNrawRank == 1 | (clean_name == clean_name[_n-1] & patent_count < patent_count[_n-1])
replace withinCNrank = withinCNrank[_n-1] if clean_name == clean_name[_n-1] & patent_count == patent_count[_n-1]
drop withinCNrawRank
gen cnRankRaw = 1 if _n == 1
replace cnRankRaw = cnRankRaw[_n-1] + (clean_name != clean_name[_n-1]) if _n > 1
gen cnRank = cnRankRaw if _n == 1 | (clean_name != clean_name[_n-1] & cnPc < cnPc[_n-1])
replace cnRank = cnRank[_n-1] if _n > 1 & cnPc == cnPc[_n-1]
drop cnRankRaw
drop if cnRank > 500
order clean_name cnPc cnAY1 cnAYm cnAYN cnRank patentName patent_count appYear1 appYearMean appYearN withinCNrank
export delimited "$data/inspection1.csv", replace
drop patentName patent_count appYear1 appYearMean appYearN withinCNrank
duplicates drop
export delimited "$data/inspection2.csv", replace
*/


// Following this, we basically just run through the process used to generate 019e_dynamicNamesClean_matched.dta but, for each manually resolved unmatched name from the patent-side, peg it to a "mirror name" from the accounting-side (matched or unmatched, it doesn't matter). The ownership of the mirror name also becomes the ownership of the unmatched name from the patent-side.

* Import Homogenised Patent Data *

use "$data/017f_patents_homogenised.dta", clear


* Keep Only Clean Names, Reduce to Clean Name Level *

keep clean_name

duplicates drop


* Merge to Cleaned Dynamic Names Dataset, Retain Mirror Names *

merge 1:m clean_name using "$data/019e_dynamicNamesClean.dta"
/*

    Result                      Number of obs
    -----------------------------------------
    Not matched                       669,767
        from master                   621,816  (_merge==1) -- Clean names that feature in our patent dataset, but not our listed firms dataset
        from using                     47,951  (_merge==2) -- Clean names that feature in our listed firms dataset, but not our patent dataset

    Matched                            14,668  (_merge==3) -- Clean names that feature in the intersection of the patent dataset and the listed firms dataset
    -----------------------------------------

*/
gen mirror_name = (clean_name == "FUJIFILM" | clean_name == "MICROSOFT" | clean_name == "HEWLETTPACKARD" | clean_name == "TOYOTAMOTOR" | clean_name == "MATSUSHITAELECINDL" | clean_name == "FORDMOTOR" | clean_name == "MONSANTO" | clean_name == "LUCENTTECH" | clean_name == "NOKIA" | clean_name == "CISCOSYS" | clean_name == "NOVARTIS" | clean_name == "STMICROELECTRONICS" | clean_name == "SCHLUMBERGER" | clean_name == "VERIZON" | clean_name == "PPGIND" | clean_name == "GLOBALFOUNDRIES" | clean_name == "EXXON" | clean_name == "ITT" | clean_name == "ALLIED" | clean_name == "NXPSEMICONDUCTORS" | clean_name == "SPRINT" | clean_name == "WESTINGHOUSEAIRBRAKE" | clean_name == "ROCKWELLMFG" | clean_name == "CNHIND" | clean_name == "WESTERNDIGITAL" | clean_name == "GRACEWR" | clean_name == "BAXTERINT" | clean_name == "CHEVRON" | clean_name == "AIRPRODANDCHEM" | clean_name == "AMERNCAN" | clean_name == "CONTINENTALCAN" | clean_name == "TOSHIBA" | clean_name == "JOHNSONANDJOHNSON" | clean_name == "SEARLEGD" | clean_name == "SQUIBB" | clean_name == "ABBASEABROWNBOVERIGP" | clean_name == "UNILEVER" | clean_name == "ANSALDOSIGNAL" | clean_name == "ROCKWELLAUTOMATION" | clean_name == "SMITHKLINEBEECHAM" | clean_name == "TYCOELECTRONICS" | clean_name == "ROCHE" | clean_name == "SUNOCO" | clean_name == "SUBARU" | clean_name == "FAIRCHILDSEMICONDUCTORINT" | clean_name == "GULF" | clean_name == "ALCOA" | clean_name == "DISNEYWALT" | clean_name == "EASTMANCHEM" | clean_name == "BEAZER" | clean_name == "JOHNSONCONTROLS" | clean_name == "SYNTEX" | clean_name == "ALSTOM" | clean_name == "AMERNSTANDARD" | clean_name == "COURTAULDS" | clean_name == "VISTEON" | clean_name == "HARTFORDNATL" | clean_name == "LAIRLIQUIDE" | clean_name == "SEMICONDUCTORMFGINT" | clean_name == "SMITHAO" | clean_name == "GLAXO" | clean_name == "ASMINT" | clean_name == "SUNBEAM" | clean_name == "BARDCR" | clean_name == "COMMSCOPE" | clean_name == "BAESYS" | clean_name == "REXNORD" | clean_name == "BALLYTECH" | clean_name == "NIELSENAC" | clean_name == "AMERNSTEELFOUNDRIES" | clean_name == "MALLORY" | clean_name == "NATLSTARCHANDCHEM" | clean_name == "STEWARTWARNER" | clean_name == "ZENECAGP" | clean_name == "SCM" | clean_name == "GOODMANMFG" | clean_name == "REGALBELOIT" | clean_name == "ARMOUR" | clean_name == "ADVANCEDSEMICONDUCTORENGR" | clean_name == "WEYERHAEUSER" | clean_name == "MASTERCARD" | clean_name == "JOYMFG" | clean_name == "TELEDYNE" | clean_name == "FRESENIUSMEDCARE" | clean_name == "AMERNEXPRESS" | clean_name == "VLSITECH" | clean_name == "KENDALL" | clean_name == "REYNOLDSRJTOBACCO" | clean_name == "VISA" | clean_name == "SQUARED" | clean_name == "STATEFARMINS" | clean_name == "STORAGETECH" | clean_name == "INTMINERALSANDCHEM" | clean_name == "WMSIND" | clean_name == "CORDANTTECH" | clean_name == "WALMART" | clean_name == "AVENTIS" | clean_name == "MERCEDESBENZGP" | clean_name == "GULFOIL" | clean_name == "LOGITECHINT" | clean_name == "SINCLAIROIL") // The accounting-side names used as mirrors for the unmatched patent-side names

label var mirror_name "clean_name whose ownership structure adopted for unmatched patenting name"

keep if _merge == 3 | mirror_name == 1


* Copy Mirror Name Observations for Unmatched Patent-side Names *

foreach mapping in "FUJI:FUJIFILM" "MICROSOFTTECH:MICROSOFT" "HEWLETTPACKARDDEV:HEWLETTPACKARD" "TOYOTAJIDOSHA:TOYOTAMOTOR" "MATSUSHITAIND:MATSUSHITAELECINDL" "FORDGLOBALTECH:FORDMOTOR" "MONSANTOTECH:MONSANTO" "LUCENTMEDICALSYS:LUCENTTECH" "NOKIATECH:NOKIA" "CISCOTECH:CISCOSYS" "CIBAGEIGY:NOVARTIS" "STMICROELECTRONICSGRENOBLE2:STMICROELECTRONICS" "SCHLUMBERGERTECH:SCHLUMBERGER" "VERIZONPATENT:VERIZON" "PPGTECH:PPGIND" "GLOBALFOUNDRIESUS:GLOBALFOUNDRIES" "EXXONRESEARCHANDENG:EXXON" "ITTMFGENTPR:ITT" "ALLIEDTRADINGANDMARKETING:ALLIED" "NXP:NXPSEMICONDUCTORS" "SPRINTCOMM:SPRINT" "WESTINGHOUSEAIRBRAKETECH:WESTINGHOUSEAIRBRAKE" "ROCKWELL:ROCKWELLMFG" "CNHINDUS:CNHIND" "WESTERNDIGITALTECH:WESTERNDIGITAL" "WRGRACE:GRACEWR" "BAXTER:BAXTERINT" "CHEVRONHK:CHEVRON" "AIRPROD:AIRPRODANDCHEM" "AMERNPAN:AMERNCAN" "CONTINENTALELEC:CONTINENTALCAN" "TOKYOSHIBAURADENKI:TOSHIBA" "JOHNSONANDJOHNSONVISIONCARE:JOHNSONANDJOHNSON" "GDSEARLE:SEARLEGD" "ERSQUIBBANDSONS:SQUIBB" "BBCBROWNBOVERI:ABBASEABROWNBOVERIGP" "CONOPCO:UNILEVER" "ANSALDOSTSUS:ANSALDOSIGNAL" "ROCKWELLAUTOMATIONTECH:ROCKWELLAUTOMATION" "SMITHKLINEBEECHAMCORK:SMITHKLINEBEECHAM" "TYCOELECTRONICSSHANGHAI:TYCOELECTRONICS" "ROCHEDIAGNOSTICS:ROCHE" "SUNOCODEV:SUNOCO" "FUJIJUKOGYO:SUBARU" "FAIRCHILDSEMICONDUCTOR:FAIRCHILDSEMICONDUCTORINT" "GULFRESEARCHANDDEV:GULF" "ALCOALTEE:ALCOA" "DISNEYENTPR:DISNEYWALT" "EASTMAN:EASTMANCHEM" "BEAZERWEST:BEAZER" "JOHNSONCONTROLSTECH:JOHNSONCONTROLS" "SYNTEXUS:SYNTEX" "ALSTOMTECH:ALSTOM" "AMERNSTANDARDMFG:AMERNSTANDARD" "COURTAULDSENG:COURTAULDS" "VISTEONGLOBALTECH:VISTEON" "HARTFORDNATLBK:HARTFORDNATL" "LAIRLIQUIDESOCITANONYMEPOURLETUDEETLEXPLOITATIONDESPROCDSGEORGESCLAUDE:LAIRLIQUIDE" "SEMICONDUCTORMFGINTBEIJING:SEMICONDUCTORMFGINT" "AOSMITH:SMITHAO" "GLAXOGP:GLAXO" "ASM:ASMINT" "SUNBEAMPROD:SUNBEAM" "CRBARD:BARDCR" "COMMSCOPETECH:COMMSCOPE" "BAESYSINFORMATIONANDELECTRONICSYSINTEGRATION:BAESYS" "REXNORDIND:REXNORD" "BALLYGAMING:BALLYTECH" "NIELSENUS:NIELSENAC" "ASFKEYSTONE:AMERNSTEELFOUNDRIES" "MALLORYIND:MALLORY" "NATLSTARCH:NATLSTARCHANDCHEM" "STEWARTWARNERELECTRONICS:STEWARTWARNER" "ZENECA:ZENECAGP" "SPCM:SCM" "GOODMAN:GOODMANMFG" "BELOITTECH:REGALBELOIT" "ARMOURTECH:ARMOUR" "ADVANCEDSEMICONDUCTORENG:ADVANCEDSEMICONDUCTORENGR" "WEYERHAEUSERNR:WEYERHAEUSER" "MASTERCARDINT:MASTERCARD" "JOYFACTORY:JOYMFG" "TELEDYNEENERGYSYS:TELEDYNE" "FRESENIUSMEDICAL:FRESENIUSMEDCARE" "AMERNEXPRESSTRAVELRELATEDSVCS:AMERNEXPRESS" "VLSIRESEARCH:VLSITECH" "KENDALLENTPR:KENDALL" "RJREYNOLDSTOBACCO:REYNOLDSRJTOBACCO" "VISAINTSVCASS:VISA" "IPSQUAREDTECH:SQUARED" "STATEFARMMUTUALAUTOMOBILEINS:STATEFARMINS" "STORAGE:STORAGETECH" "IMCCHEMGP:INTMINERALSANDCHEM" "WMSGAMING:WMSIND" "CORDANTRESEARCHSOLTNS:CORDANTTECH" "WALMARTAPOLLO:WALMART" "AVENTISPHARM:AVENTIS" "MERCEDESBENZ:MERCEDESBENZGP" "GULFOILPENNSYLVANIA:GULFOIL" "LOGITECH:LOGITECHINT" "SINCLAIRREFINING:SINCLAIROIL"{ // This has the structure "{unmatched patent name}:{mirror name}"
	
	local pcn `=substr("`mapping'", 1, strpos("`mapping'", ":") - 1)' // Unmatched patent-side clean name. Extracts everything from the string before the colon
	
	local mirror_name `=substr("`mapping'", strpos("`mapping'",":") + 1, .)' // Accounting-side clean name used as mirror. Extracts everything from the string after the colon
	
	di "`pcn' -- `mirror_name'"
	
	expand 2 if clean_name == "`mirror_name'", gen(mirrored_obs) // Duplicate each observation containing the mirrored name
	
	label var mirrored_obs "Observation is a duplicate of mirror name observation"
	
	replace clean_name = "`pcn'" if mirrored_obs == 1 // Gets the patent-side clean name into the duplicates
	
	replace _merge = . if mirrored_obs == 1 // So the patent-side name doesn't get dropped below
	
	replace name_source = "High-patent Name" if mirrored_obs == 1
	
	drop mirrored_obs
	
}


* Drop The "Mirror Names" which Do Not Themselves Map to Patents *

drop if _merge == 2 // If a mirror-name on the accounting-side doesn't actually match to patents, it will have (_merge == 2) and be dropped here.

drop _merge mirror_name // No longer needed


* Export *

order gvkey wb_date1 wb_dateN name clean_name name_linkDay1 name_linkDayN name_source

compress

save "$data/019g_dynamicNamesCleanManualAdd_matched.dta", replace





********************************************************************************
********** GET COMPUSTAT PRESENCE OF EACH GVKEY BY ULTIMATE OWNERSHIP **********
********************************************************************************

* Import Cleaned and Matched Dynamic Names *

use "$data/019g_dynamicNamesCleanManualAdd_matched.dta", clear


* Reduce to gvkey Level *

keep gvkey

duplicates drop


* 1:m Merge to All Ultimate Owner gvkeys *

merge 1:m gvkey using "$data/019d_whoOwnsWhomAndWhen_gvkeys.dta"
/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                        31,452
        from master                         0  (_merge==1)
        from using                     31,452  (_merge==2) -- Recall that we're only using gvkeys that are associated with clean names that feature in our patent dataset. These are all observations for gvkeys that don't meet this criterion.

    Matched                            12,397  (_merge==3) -- Everything from the master merges.
    -----------------------------------------
*/
drop if _merge == 2 // Not needed. See above

drop _merge // No longer informative


* Merge Ultimate Owner gvkeys to their Active Years in Compustat *

rename gvkey PH // We need this variable name for the merge

rename gvkeyUO gvkey // Facilitates merge

merge m:1 gvkey using "$data/019a_cstatPresence.dta"
/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                        29,874
        from master                         8  (_merge==1) -- gvkeys that we map to "000000" after they're sold to a privately-held firm
        from using                     29,869  (_merge==2) -- Again, we're only using gvkeys that are associated with clean names that feature in our patent dataset. These are all observations for gvkeys that don't meet this criterion.

    Matched                            12,389  (_merge==3) -- Everything from the master, except mappings to "000000", merges
    -----------------------------------------
*/
drop if _merge == 2 // Not needed. See above

drop _merge // No longer informative

rename gvkey gvkeyUO // Return to original names

rename PH gvkey


* Get Last Year of Presence for gvkey or Any Owner Thereof *

bysort gvkey: egen gvkey_lastYear = max(yPresentN)

label var gvkey_lastYear "Last year (calendar or fiscal) gvkey or owner thereof is present in Compustat"


* Drop Extraneous Variables *

drop gvkeyUO year1 yearN yPresent1 yPresentN // No longer needed

duplicates drop // Created by varied ownership of gvkeys


* Export *

compress

save "$data/019g_cstatPresenceByUltimateOwner.dta", replace





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

use "$data/019g_dynamicNamesCleanManualAdd_matched.dta", clear


* Get First Year of Association for Each Clean Name *

bysort gvkey clean_name: egen gvkeyCNyear1 = min(yofd(name_linkDay1))

label var gvkeyCNyear1 "First year clean name is (immediately) associated with gvkey"


* Reduce to gvkey x Clean Name Level *

keep gvkey clean_name gvkeyCNyear1 

duplicates drop


* Merge to gvkey Final Year of Presence in Compustat by Ownership *

merge m:1 gvkey using "$data/019g_cstatPresenceByUltimateOwner.dta"
/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                             0
    Matched                            12,415  (_merge==3) -- All merge by construction.
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
drop if gvkey == "002338" & clean_name == "BOWATER"
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
drop if clean_name == "MONARCHMACHINETOOL" & year > 2000
drop if gvkey == "007699" & clean_name == "NAC"
drop if (gvkey == "008173" | gvkey == "014057") & clean_name == "ORANGE"

drop if gvkey == "008488" & clean_name == "PERKINELMER"
drop if gvkey == "160237" & clean_name == "PHARMACOPEIA"
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
drop if gvkey == "027638" & clean_name == "ALCOA" & year <= 2015

drop if gvkey == "001067" & clean_name == "ATI" & year <= 1976
drop if gvkey == "001254" & clean_name == "ALEXANDERANDBALDWIN" & year >= 2011
drop if gvkey == "001995" & clean_name == "BALTIMOREGASANDELEC" & year == 1999
drop if (gvkey == "002135" | gvkey == "060893") & clean_name == "BELLANDHOWELL" & year >= 2001
drop if gvkey == "002401" & clean_name == "BRISTOL" & year >= 1989

drop if gvkey == "012791" & clean_name == "BROADCASTINT" & year <= 1994
drop if gvkey == "002812" & clean_name == "CASTLEANDCOOKE" & year == 1991
drop if gvkey == "065006" & clean_name == "CALDIVEINT" & year == 2006
drop if gvkey == "003255" & clean_name == "COMMONWEALTHEDISON" & year == 1994
drop if gvkey == "003853" & clean_name == "DELTAUS" & year >= 1984

drop if gvkey == "121819" & clean_name == "DIADEXUS" & year <= 2004
drop if gvkey == "009177" & clean_name == "ENDEVCO" & year <= 1995
drop if gvkey == "060874" & clean_name == "ENRON" & year <= 1985
drop if gvkey == "011300" & clean_name == "GRAHAM"
drop if gvkey == "006877" & clean_name == "LOEWS" & year >= 1960

drop if gvkey == "007745" & clean_name == "NATLSTEEL" & year == 1983
drop if gvkey == "026061" & clean_name == "IACINTERACTIVECORP" & year >= 2018
drop if gvkey == "010484" & clean_name == "UNITEDAIRLINES" & year < 2010
drop if gvkey == "017269" & clean_name == "USBANCORP" & year == 2001
drop if gvkey == "005342" & clean_name == "VIAD" & year >= 2003

drop if gvkey == "011300" & clean_name == "WASHINGTONPOST" & year >= 2013


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
           only in using data |     31,492       70.10       70.10 -- The ownership of gvkeys not associated with any clean names that feature in the patent data
both in master and using data |     14,886       29.90      100.00 -- All data from the master merge
------------------------------+-----------------------------------
                        Total |     45,050      100.00
*/
drop if _merge == 2

drop _merge


* Drop Extemporaneous Ultimate Owner Data *

drop if year1 > gvkeyCNyearN // M&A event takes place after both parties delist or name manually unlinked from gvkey

drop if yearN < gvkeyCNyear1 // Ownership ends before association with clean name begins


* Get Feasibility Boundaries of Association Between Clean Name and Ultimate Owner gvkey via Immediate Owner gvkey *

gen gvkeyUOCNyear1 = max(year1, gvkeyCNyear1)

label var gvkeyUOCNyear1 "First year of association between clean name and gvkeyUO via gvkey"

gen gvkeyUOCNyearN = min(yearN, gvkeyCNyearN)

label var gvkeyUOCNyearN "Last year of *feasible* association between clean name and gvkeyUO via gvkey"


* Expand to gvkeyUO x clean_name x Feasible Year Level *

keep gvkeyUO clean_name gvkeyUOCNyear1 gvkeyUOCNyearN // At this point we aren't bothered about which immediate owner gvkey the clean name links to the ultimate owner gvkey through

duplicates drop

expand (gvkeyUOCNyearN - gvkeyUOCNyear1 + 1)

bysort gvkeyUO clean_name gvkeyUOCNyearN gvkeyUOCNyear1: gen year = gvkeyUOCNyear1 - 1 + _n

label var year "Year of feasible association between gvkeyUO and clean name"

drop gvkeyUOCNyearN gvkeyUOCNyear1

duplicates drop


* Get Run of Feasible Ownership for Each Ultimate Owner gvkey x Clean Name Pair *

bysort gvkeyUO clean_name (year): gen gvkeyUOCNyear1ofRun = year if _n == 1

bysort gvkeyUO clean_name (year): replace gvkeyUOCNyear1ofRun = max(gvkeyUOCNyear1ofRun[_n-1]*(year <= year[_n-1] + 1), year*(year > year[_n-1] + 1)) if _n > 1

label var gvkeyUOCNyear1ofRun "First year of consecutive-years clean_name-gvkeyUO association"


* Assign Each Clean Name x Year to the Ultimate Owner Gvkey with the Most Recently Commenced Run of Feasible Ownership *

bysort clean_name year (gvkeyUOCNyear1ofRun): drop if gvkeyUOCNyear1ofRun < gvkeyUOCNyear1ofRun[_N] // Observations are now unique at the clean_name-year level


* Drop Another Round of Post-Gap Years within the Same "Ownership Run" *

// For example, VIACOM is associated with gvkeyUO 013714 for 1987-2005, and then with gvkeyUO 165675 for 2006-2018. In 2018 165675 delists. Thus, we don't want VIACOM to be associated with 013714 for 2019-2020 unless this is through genuine ownership (whereby we would have gvkeyUOCNyear1ofRun == 2019)

bysort clean_name gvkeyUO gvkeyUOCNyear1ofRun (year): gen postGap = 0 if _n == 1

bysort clean_name gvkeyUO gvkeyUOCNyear1ofRun (year): replace postGap = (year > year[_n-1] + 1) if _n > 1

bysort clean_name gvkeyUO gvkeyUOCNyear1ofRun (year): replace postGap = 1 if postGap[_n-1] == 1

label var postGap "gvkeyUO x clean_name x year requires dropping"

drop if postGap == 1 

drop postGap


* Reduce to gvkeyUO x Clean Name x Ownership Run Level *

bysort clean_name gvkeyUO gvkeyUOCNyear1ofRun: egen cnLink_y1 = min(year)

label var cnLink_y1 "First year of link between gvkeyUO and clean name"

bysort clean_name gvkeyUO gvkeyUOCNyear1ofRun: egen cnLink_yN = max(year)

label var cnLink_yN "Last year of link between gvkeyUO and clean name"

drop year gvkeyUOCNyear1ofRun // No longer needed

duplicates drop


* Joinby to All gvkeys Owned (Including Self) by gvkeyUO *

joinby gvkeyUO using "$data/019d_whoOwnsWhomAndWhen_gvkeys.dta", unmatched(both)
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


* Drop gvkey-gvkeyUO Links That Start After the Clean Name Link *

drop if year1 > cnLink_yN


* Joinby to the Relevant gvkey-clean_name Pairs *

joinby gvkey clean_name using "$data/019g_dynamicNamesCleanManualAdd_matched.dta", unmatched(both)
/*
                       _merge |      Freq.     Percent        Cum.
------------------------------+-----------------------------------
          only in master data |      3,686       16.38       16.38 -- gvkeys that are owned by the gvkeyUO at the relevant time, but are not associated with the given clean_name
           only in using data |         67        0.35       16.72 -- Those links that were manually dropped above
both in master and using data |     16,333       83.28      100.00 -- Note that all 13,018 clean_name-gvkeyUO-cnLink_y1-cnLink_yN groupings from the master merge at least once
------------------------------+-----------------------------------
                        Total |     20,086      100.00
*/
keep if _merge == 3 // To reiterate, we don't lost any of the 12,793 clean_name-gvkeyUO-cnLink_y1-cnLink_yN groupings from the master here

drop _merge // No longer needed


* Drop if The Clean Name is Not Associated with the gvkey Until After the Gvkey's Ownership *

drop if yofd(name_linkDay1) > cnLink_yN // Again, we still have all 12,793 clean_name-gvkeyUO-cnLink_y1-cnLink_yN groupings after this


* Drop Extraneous Variables *

drop year1 yearN wb_date1 wb_dateN

duplicates drop // Created by gvkeyUOs that own a gvkey twice


* Get Years of Links Between name and gvkey *

gen name_year1 = yofd(name_linkDay1)

label var name_year1 "First year 'name' strictly links to gvkey"

gen name_yearN = yofd(name_linkDayN)

label var name_yearN "Last year 'name' strictly links to gvkey"

drop name_linkDay1 name_linkDayN


* Reshape to clean_name-gvkeyUO-cnLink_y1-cnLink_yN Level *

bysort clean_name gvkeyUO cnLink_y1 cnLink_yN (name_year1 gvkey): gen _j = _n

label var _j "Reshape facilitator"

quietly summ _j // Gets the future width of the dataset into `=r(max)'

local width = `=r(max)'

reshape wide gvkey name name_year1 name_yearN name_source, i(clean_name gvkeyUO cnLink_y1 cnLink_yN) j(_j)

forvalues i = 1/`width'{
	
	label var gvkey`i' "gvkey through which name`i' maps to gvkeyUO, producing the clean name link"
	
	label var name`i' "Name #`i' producing link between gvkeyUO and clean_name"
	
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

save "$data/019g_whoOwnsWhomAndWhen_nameUOs.dta", replace



/*
use "$data/019g_whoOwnsWhomAndWhen_nameUOs.dta", clear
keep gvkey*
drop gvkeyUO
duplicates drop
gen obs_nr = _n
reshape long gvkey, i(obs_nr)
drop _j obs_nr
duplicates drop
drop if missing(gvkey)
rename gvkey gvkey_secondary
merge 1:m gvkey_secondary using "$data/019d_chainsOfOwnership.dta"
keep if _merge == 3
rename gvkey_primary gvkey1
rename gvkeyIntTier1 gvkey2
rename gvkeyIntTier2 gvkey3
rename gvkeyIntTier3 gvkey4
rename gvkeyIntTier4 gvkey5
rename gvkey_secondary gvkey6
keep gvkey*
duplicates drop
gen obs_nr = _n
reshape long gvkey, i(obs_nr)
drop obs_nr _j
duplicates drop
drop if missing(gvkey)
*/



********************************************************************************
********************* GET REASSIGNABLE OWNERSHIP OF NAMES **********************
********************************************************************************

// Suppose a patent is applied for under the name "ALPHACORP" in 1982, the trading name of gvkey 51. Suppose that in 1982 gvkey 51 is owned by gvkey 62, but in 1985 gvkey 62 sells it to gvkey 73. We then want, for 1985, the patent to be part of gvkey 73's patent stock but not gvkey 62. We achieve this by using our gvkeyFR variable.

* Import Who Owns Whom and When Ultimate Owner Data *

use "$data/019g_whoOwnsWhomAndWhen_nameUOs.dta", clear


* Flag Whether Clean Name Mapped to gvkey Through Single Subsidiary *

local singleSubsBool = ""

foreach V of varlist gvkey*{ // Loop over all 
	
	if("`V'" == "gvkeyUO" | "`V'" == "gvkey1"){
		
		continue
		
	}
	
	if("`singleSubsBool'" != ""){
		
		local singleSubsBool = "`singleSubsBool' & "
		
	}
	
	local singleSubsBool = "`singleSubsBool'(gvkey1 == `V' | missing(`V'))"
	
}

gen singleSubs = (`singleSubsBool')

label var singleSubs "Clean name mapped to gvkeyUO via single subsidiary gvkey (possibly self)"


* Get Single Subsidiary Variable *

gen gvkey_secondary = gvkey1 if singleSubs == 1

label var gvkey_secondary "Sole subsidiary (possibly self) mapping clean_name to gvkeyUO"


* Merge to Later Divorced Data *

rename gvkeyUO gvkey_primary

joinby gvkey_primary gvkey_secondary using "$data/019d_chainsOfOwnership.dta", unmatched(both)
/*
                       _merge |      Freq.     Percent        Cum.
------------------------------+-----------------------------------
          only in master data |        529        1.16        1.16 -- Every observation where the clean_name maps to gvkeyUO through multiple subsidiary gvkeys
           only in using data |     32,548       71.41       72.57 -- Chains of ownership that don't concern any clean_names that feature in our patent data
both in master and using data |     12,505       27.43      100.00 -- Every observation with singleSubs == 1
------------------------------+-----------------------------------
                        Total |     45,582      100.00
*/
drop if _merge == 2 // Not needed

drop _merge // Can be inferred from singleSubs

rename gvkey_primary gvkeyUO


* Initiate gvkeyFR Variable *

local gfrc = ""

foreach V of varlist *_laterDivorced{
	
	if("`gfrc'" != ""){
		
		local gfrc = "`gfrc' & "
		
	}
	
	local gfrc = "`gfrc'(`V' == 0 | missing(`V'))"
	
}

gen gvkeyFR = gvkeyUO if singleSubs == 0 | (`gfrc') // If no subsidiaries are later divorced, or multiple subsidiaries map the same clean name to gvkeyUO, we use this as the gvkey for reassignment

label var gvkeyFR "gvkey-like identifier used for patent reassignment"


* Replace gvkeyFR with Lowest Tier Later-divorced gvkey Where Appropriate *

local loopCounter = 0

foreach V of varlist gvkeyIntTier*{ // Loop over gvkeyIntTier* variables
	
	local loopCounter = `loopCounter' + 1
		
	replace gvkeyFR = `V' if gvkT`loopCounter'_laterDivorced == 1
	
}

replace gvkeyFR = gvkey_secondary if gvkS_laterDivorced == 1


* Resolve Groupings of clean_name-gvkeyUO-gvkey_secondary-cnLink_y1-cnLink_yN with multiple gvkeyFRs *

bysort clean_name gvkeyUO gvkey_secondary cnLink_y1 cnLink_yN: gen multiOwnershipStructure = (gvkeyFR[1] != gvkeyFR[_N])

label var multiOwnershipStructure "Multiple ownership structures within clean_name-gvkeyUO-cnLink_y1-cnLink_yN"

bysort clean_name gvkeyUO gvkey_secondary cnLink_y1 cnLink_yN (year1): gen new_cnLink_y1 = year1 if _n > 1 & multiOwnershipStructure == 1

label var new_cnLink_y1 "Replacement startpoint of clean name link due to multiple ownership structures"

bysort clean_name gvkeyUO gvkey_secondary cnLink_y1 cnLink_yN (year1): gen new_cnLink_yN = yearN if _n < _N & multiOwnershipStructure == 1

label var new_cnLink_yN "Replacement endpoint of clean name link due to multiple ownership structures"

replace cnLink_y1 = new_cnLink_y1 if !missing(new_cnLink_y1)

replace cnLink_yN = new_cnLink_yN if !missing(new_cnLink_yN)

drop if cnLink_yN < cnLink_y1 // Shouldn't drop anything

drop *_laterDivorced year1 yearN multiOwnershipStructure new_cnLink_y1 new_cnLink_yN

duplicates drop // Drops made due to gvkeyUOs owning gvkeyFRs twice


* Re-name, Re-label, Re-order Variables *

rename gvkey_secondary gvkeyCNoriginator

label var cnLink_y1 "First year of link between gvkeyUO, gvkeyFR, and clean_name"

label var cnLink_yN "Last year of link between gvkeyUO, gvkeyFR, and clean_name"

local loopTop = 0 // Counts the number of intermediary tiers in the dataset 

foreach V of varlist gvkeyIntTier*{
	
	local loopTop = `loopTop' + 1
	
}

local i = 0 // Counts iterations

forvalues j = `loopTop'(-1)1{
	
	local i = `i' + 1
	
	label var gvkeyIntTier`j' "Intermediary gvkey `i' generations above gvkeyCNoriginator"
	
}

local orderString = "" // Used to order variables

foreach V of varlist gvkey*{
	
	if("`V'" == "gvkeyUO" | "`V'" == "gvkeyFR" | "`V'" == "gvkeyCNoriginator" | strpos("`V'", "gvkeyIntTier")){ // We don't want this one
		
		continue
		
	}
	
	local orderString = `"`orderString' `V' name`=substr("`V'",6,1)'"'
	
	quietly ds, has(varl *`V'*)
	
	foreach V2 in `=r(varlist)'{
		
		local orderString = "`orderString' `V2'"
		
	}
	
}

order clean_name gvkeyUO gvkeyFR cnLink_y1 cnLink_yN `orderString' singleSubs gvkeyIntTier* gvkeyCNoriginator


* Change gvkeyFR for Firms Later Subject to Reverse Spin-Off *

replace gvkeyFR = "012796A" if gvkeyUO == "012796" & clean_name == "1STAMERNFIN"

replace gvkeyFR = "011427A" if gvkeyUO == "011427" & clean_name == "WESTERNUNION" // Western Union/New Valley

replace gvkeyFR = "179605A" if gvkeyUO == "179605" & clean_name == "RXIPHARM" // RXi/Galena

drop if gvkeyUO == "032901" & clean_name == "RXIPHARM"

replace gvkeyFR = "004988A" if gvkeyUO == "004988" & clean_name == "GANNETT" // Gannett/Tegna

replace gvkeyFR = "003243A" if gvkeyUO == "003243" & clean_name == "TRAVELERS" // Travelers/Citigroup

replace gvkeyFR = "005742A" if gvkeyUO == "005742" & clean_name == "RELIANTENERGY"

replace gvkeyFR = "008818A" if gvkeyUO == "008818" & clean_name == "PUGETSOUNDENERGY" // Puget/Puget Sound

replace gvkeyFR = "011218A" if gvkeyUO == "011218" & clean_name == "VODAVITECH" // Vodavi/Executone

replace gvkeyFR = "009728A" if gvkeyUO == "009728" & clean_name == "USGOLD" // US Gold/McEwen Mining

replace gvkeyFR = "024937A" if gvkeyUO == "024937" & (clean_name == "MAJESCO" | clean_name == "MAJESCOENTMT") // Majesco/Polarity TE

replace gvkeyFR = "005639A" if gvkeyUO == "005639" & clean_name == "HILLENBRANDINDS" // Hillenbrand/Hill-Rom. No patents.

replace gvkeyFR = "005342A" if gvkeyUO == "005342" & (clean_name == "GREYHOUND" | clean_name == "VIAD") // Viad/Moneygram
replace cnLink_yN = 2002 if gvkeyUO == "005342" & (clean_name == "GREYHOUND" | clean_name == "VIAD")

set obs `=(_N + 1)' // Because Greyhound is an old name of 005342, we need a new observation for it. This isn't required for any other reverse spin-offs
replace clean_name = "GREYHOUND" if _n == _N 
replace cnLink_y1 = 2003 if _n == _N
replace cnLink_yN = 2020 if _n == _N
replace gvkeyUO = "160785" if _n == _N
replace gvkeyFR = "160785" if _n == _N
replace name1 = "GREYHOUND CORP" if _n == _N
replace name1_source = "Manual" if _n == _N

replace gvkeyFR = "007745A" if gvkeyUO == "007745" & clean_name == "NATLSTEEL"

replace gvkeyFR = "005776A" if gvkeyUO == "005776" & clean_name == "HUMANA" // Humana/Galen Healthcare

replace gvkeyFR = "026061A" if gvkeyUO == "026061" & clean_name == "HSN" // HSN/US Networks

replace gvkeyFR = "026061B" if gvkeyUO == "026061" & clean_name == "IACINTERACTIVECORP" //IAC Interactive/Match Group

replace gvkeyFR = "007536A" if gvkeyUO == "007536" & (clean_name == "MONSANTO" | clean_name == "MONSANTOTECH") // Monsanto/Pharmacia
drop if gvkeyUO == "008530" & (clean_name == "MONSANTO" | clean_name == "MONSANTOTECH")
replace cnLink_yN = 2015 if (clean_name == "MONSANTO" | clean_name == "MONSANTOTECH") & gvkeyUO == "140760"

replace gvkeyFR = "001254A" if gvkeyUO == "001254" & clean_name == "ALEXANDERANDBALDWIN" // Alexander & Baldwin/Matson

replace gvkeyFR = "002812A" if gvkeyUO == "002812" & clean_name == "CASTLEANDCOOKE" // Castle & Cooke/Dole Food


* Compress, Export *

compress

save "$data/019g_whoOwnsWhomAndWhen_ReassignmentFriendly.dta", replace