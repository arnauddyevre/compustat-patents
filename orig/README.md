# compustat-patents\orig

___

This subdirectory contains nine small manually constructed datasets used in the production of our final data.

This README also provides instructions on how to obtain the several external datasets used to construct our data, and describes our manually constructed datasets.

### Instructions to Obtain Data from External Sources

Below are listed datasets that are either very large (e.g. USPTO Patentsview) or proprietary (e.g. Compustat). Each is required for a full running of the code we use to construct our final data.

#### Fleming, Greene, Li, Marx, and Yao (2019)
- The individual OCR files (used in script 014)
- UPSTO Government Reliance Metadata (used in scripts 017a, 017c, 017d, 017e, 017f, 019e)
    
#### USPTO PatentsView
- patent.tsv (used in scripts 017a, 019e)
- patent_assignee.tsv (used in scripts 017a, 017c, 017d, 017e, 017f)
- assignee.tsv (used in script 017a)
- rawassignee.tsv (used in script 017c)
- application.tsv (used in script 019e)
    
#### Duke Innovation and Scientific Enterprises Research Network (DISCERN) A.K.A. Arora, Belenzon, and Sheer (2017)
- DISCERN_Panal_Data_1980_2015.dta (The full Compustat-based panel of firms constructed and used by Arora, Belenzon, and Sheer (2018a)) (used in script 018a)
- DISCERN_SUB_name_list.dta (The full list of subsidiaries found by ABS, in their preferred structural format) (used in script 018a)
- permno_gvkey.dta (ABS' crosswalk between their identifier - permno_adj - and gvkeys) (used in scripts 018a, 019b)
    
#### Wharton Research Data Services (WRDS)
- WRDS Company Subsidiary Data (Beta), 1993/12-2020/12 (used in script 018c)

#### Center for Research in Security Prices (CRSP)
- CRSP Daily Stock, 1926/01/01-2020/12/31 (used in script 019a)
- CRSP/Compustat Merged Database - Linking Table (used in script 019a)

#### S&P Global Market Intelligence Compustat
- North America Fundamentals Annual, 1950/06-2020/12 (used in scripts 019a, 019d)
    
#### Thomson/Refinitiv Securities Data Company (SDC) Platinum
- Mergers and Acquisitions Events (used in script 019c)


### Manually Constructed Data

Below we describe nine small datasets provided in this subdirectory. These have been produced through extensive general research and manual review. The datasets are essential to running the code that produces our final data.

#### Patent-side Manually Constructed Data

The below seven datasets are produced as a result of manually reviewing the output of automated matching procedures we employ on the patent-side of the data.

- *fglmyReparse_mapping_manuallyReviewed.csv*, enclaved by script *017b* (Observations are manually confirmed mappings from an original FGLMY name of the form "ASSIGNORSTOCOMPANYNAME..." to "COMPANYNAME")
- *resolve_flemToPview_errors.csv*, enclaved by script *017c* (Observations are correct mappings from FGLMY to PatentsView for those FGLMY clean names whose automated mapping to PatentsView is erroneous)
- *resolve_flemToPview_manualAdditions.csv*, enclaved by script *017c* (Observations are FGLMY-to-PatentsView mappings from top patenters in the FGLMY data who have no automated mapping to PatentsView)
- *jvManualRemap.csv*, enclaved by script *017d* (Observations are mappings from a clean name representing a joint venture between two companies to the clean name chosen to associate this joint venture with)
- *substring_match_manuallyReviewed.csv*, enclaved by script *017d* (Observations are clean_name-to-clean_name mappings from the internal substring match process that are retained following manual review)
- *lowPat_vacuumNames.csv*, enclaved by script *017e* (Observations are the appropriate substring and clean name for top patenters for whom we can automatically match subsidiaries (with fewer than 50 patents) using the start of the subsidiary's clean name)
- *subsidiaryManualRemap.csv*, enclaved by script *017e* (Observations are clean_name-to-clean_name mappings from the subsidiaries (with 50 or more patents) of top patenters to the central clean name of said patenter)

#### Accounting-side Manually Constructed Data

On the accounting (Compustat) side, we provide two datasets documenting "effective acquisitions" - events that necessitate the transferral of patent ownership in Compustat. These are...
- *effectiveAcq_listedPrivate.csv*, which contains instances of listed (Compustat) firms effectively acquiring privately-held firms. Constructed through extensive general research into major M&A events across our sample period, as well as systematic reference to the M&A activity documented by Lev and Mandelker (1972). Observations consist of the acquiror gvkey, acquiree firm name, and year of effective acquisition.
    - These data are used in script *018b*.
- *effectiveAcq_listedListed_final.csv*, which contains instances of listed (Compustat) firms effectively acquiring other listed (Compustat) firms. Constructed through extensive general research, M&A activity documented by Lev and Mandelker (1972), 6-character CUSIP matching between *gvkeys* in Compustat, M&A activity from SDC Platinum, implied M&A activity from crosswalks between *gvkeys* and other firm identifiers, SEC 10-K subsidiary data from WRDS, manually reviewed outputs of scripts *019b* and *019c*, and manually reviewed instances in which a clean name maps to multiple gvkeys. Observations consist of the acquiror gvkey, acquiree gvkey, year of effective acquisition, and nature of effective acquisition. 
    - These data are used in script *019d*.