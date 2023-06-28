# compustat-patents\code

___

This subdirectory contains all code used to map publicly listed firms from Compustat to patents from the U.S. Patents and Trademark Office, from 1950 to 2020.


### Inputs

Several external datasets are required to run our Stata code. Instructions for obtaining these can be found in the subdirectory **compustat-patents\orig**. 

In addition, the **orig** subdirectory contains nine small files produced by our own general research and manual review of the data, each of which is also required to run our Stata code.

### Python Code

For a single script - *014_FGLMYappYears.ipynb* - we utilise Python. This script parses the text in each OCR *.txt* patent file from Fleming, Greene, Li, Marx and Yao (2019) for the patent's application date.

### Stata Code

#### Tier 1 *.do* File

All Stata code can be run from the master file *stataMain.do*. This calls four *.do* files, one for each section of our data pipeline.

#### Tier 2 *.do* Files

Called by *stataMain.do* are...
- *017_patentHomogenisation.do* - calls six *.do* files to construct a 1926-2020 patent database with cleaned and homogenised firm names.
- *018_privateSubsidiaries.do* - calls four *.do* files to work data on privately held subsidiaries from various sources into a unified format.
- *019_compustatSide.do* - calls seven *.do* files to produce a dynamic mapping of firm names to Compustat gvkeys. 
- *020_staticDynamicMatch.do* - calls two *.do* files to produce the output of our match - a static patent-firm match and data facilitating the dynamic reassignment of patents - that can be found in the **compustat-patents\data** subdirectory.

#### Tier 3 *.do* Files

Called by *017_patentHomogenisation.do* are...
- *017a_nameCleaningPatents.do* - cleans all original names associated with patents in both FGLMY and PatentsView.
    - This script calls the Tier 4 .do file *500_nameCleaning.do* 
- *017b_fglmyReparse.do* - addresses some parsing errors in the FGLMY data.
    - This script enclaves one instance of manual review
- *017c_fglmyToPview_autoMapping.do* - homogenises firm names *across* datasets, replacing clean names in FGLMY with automatically matched clean names in PatentsView.
    - This script enclaves two instances of manual review
- *017d_substringMatchRun.do* - considering all clean names associated with patents, looks for substring matches amongst patenters with 50 or more associated patents.
    - This script enclaves two instances of manual review
- *017e_furtherManualCleaning.do* - takes care of large (manually matched) and small (automatically matched) subsidiaries of high-patenting firms, as well as of joint ventures amongst high-patenting firms.
    - This script enclaves two instances of manual review
- *017f_fullData_patentHomogenisation.do* - collates all patent-side data following name cleaning, homogenisation, and review.

Called by *018_privateSubsidiaries.do* are...
- *018a_elongateABS.do* - restructures subsidiary data provided by Arora, Belenzon, and Sheer (2017).
- *018b_MandAprivate.do* - processes data compiled by our own manual research, as well as the M&A activity documented by Lev and Mandelker (1972).
- *018c_WRDS_SEC.do* - processes data on subsidiaries reported in SEC 10-K filings, as compiled by WRDS on top of the original effort by Corpwatch.
- *018d_collateSubsidiaries.do* - collates the data from 018a, 018b, and 018c into a unified format.
    - This script calls the Tier 4 .do file *500_nameCleaning.do*

Called by *019_compustatSide.do* are...
- *019a_dynamicNames.do* - collates all names currently or formerly associated with a gvkey.
- *019b_listedListed.do* - identifies and collates all M&A activity from firm identifier crosswalks.
    - This script calls the Tier 4 .do file *500_nameCleaning.do*
- *019c_SDCplatinum.do* - identifies all M&A activity pertinent to our data from SDC platinum.
    - This script calls the Tier 4 .do file *500_nameCleaning.do*
- *019d_whoOwnsWhom_gvkeys.do* - maps subsidiary gvkeys to their ultimate owner gvkeys.
- *019e_patentsDatesGvkeys.do* - adds information to various intermediary datasets.
    - This script calls the Tier 4 .do file *500_nameCleaning.do*
- *019f_whoOwnsWhom_names.do* - maps names associated with public firms to their ultimate owner gvkeys.
- *019g_whoOwnsWhom_subsidiaries.do* - maps names associated with private firms to their ultimate owner gvkeys.

Called by *020_staticDynamicMatch.do* are...
- *020a_staticMatch.do* - produces the static match between patents and gvkeys for the 1950-2020 period.
- *020b_dynamicReassignment.do* - produces the data which facilitates the dynamic reassignment of patents.

#### Tier 4 *.do* File

We centralise the algorithm we use to clean firm names under *500_nameCleaning.do*.