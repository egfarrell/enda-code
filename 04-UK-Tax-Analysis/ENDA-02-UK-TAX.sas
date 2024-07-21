
/* Enda Farrell 2016 */
/* Enda Farrell 2016 */
/* Enda Farrell 2016 */
/* Enda Farrell 2016 */
/* Enda Farrell 2016 */

/* stage 6 */
%macro harmonise_repex(endd=);

        /*

        ef-note: In the end, these macros were too big to
        run on my local PC, so I took the output files from
        the network archive.

        File(s): rx_467.sas7bdat
                 rx_468.sas7bdat
                 rx_469.sas7bdat
                 ...
                 rx_515.sas7bdat
                 rx_516.sas7bdat

                Purpose:
                    These files are the main output of macro: %harmonise_repex

                Extracted from zip:
                    rx_467_516.7z

                Network location:
                    \\nsdata1\VAT\GDPO-Backup-run\Data following Mar 2016 run

                Extra Note:
                    If you want the "base" files that these "rx_"
                    files are created from then look in:
                    \\nsdata7\IDBR_DATA\IDBRDATA\REPEXTS\2016



        File: repunit_201603.sas7bdat

                Purpose:
                    Used to identify dead businesses

                Extracted from zip:
                    repunit_201603.7z

                Network location:
                    \\nsdata1\VAT\GDPO-Backup-run\Data following Mar 2016 run

        */


        /*
            This macro harmonises the layouts of the REPEX extracts
            from IDBR and introduces the categories of:
                - section,
                - division,
                - employment band
                - class.

            It also creates the datasets (one for each reference
            period) summing the RU employment by enterprises.

            These are used to calculate the proportions for the
            apportioning of the VAT turnover to reporting units as
            well as, later on, to populate the enterprises in the
            VATunit extracts with employment
         */


        /*
            EF Notes:

            need paramter file: "VAT.vat_per_lookup"

            need input file: "VAT.repunit&endd."
                             eg:  VAT.repunitYYYYMM
                             eg:  VAT.repunit201603
                             see: \\nsdata1\VAT_ARCHIVE\repunit\2016 for examples


            need file:      VAT.rx&&full_per&i..              <---- key input file - where is it!
                            need file: transite
                            need file: rx&&vat_per&i..
                            need file: rx2&&vat_per&i..
                            need file: rx3&&vat_per&i..       <--- created by 'topping_up_sic07'
                            need file: rx_t&&vat_per&i..

            output file:    vat.rx_&&vat_per&i                <---- key output file

        */



        data _null_;
            set MISC.vat_per_lookup end=finish;

            /*
                Sample File: misc.Vat_ent_lookup

                extract_period      extract_layout      period_vat
                --------------------------------------------------
                201506              2                   507
                201507              2                   508
                201508              2                   509
                201509              2                   510
                201510              2                   511
                201511              2                   512
                201512              2                   513
                201601              2                   514
                201602              2                   515
                201603              2                   516
            */

            call symput('vat_per'      !! compress(_N_),  trim(left(period_vat)));
            call symput('full_per'     !! compress(_N_),  trim(left(full_period)));
            call symput('repex_layout' !! compress(_N_),  trim(left(repex_layout)));

            if finish = 1
            then call symputx('period_num', _N_);

            /*
               EF TEMP CODE: just process one period for the
               moment to save disk space
            */
            call symputx('period_num', 1);
        run;

        %debug ("harmonise_repex: read MISC.vat_per_lookup")
        %debug ("   period_num:     &period_num")


        %do i = 1 %to  &period_num.;

            %debug (' ');
            %debug ("harmonise_repex: VAT.rx_&&vat_per&i");
            %debug ("    vat_per&i:      &&vat_per&i.");
            %debug ("    full_per&i:     &&full_per&i.");
            %debug ("    repex_layout&i: &&repex_layout&i.");


            %if %sysfunc(exist(STAGE06.rx_&&vat_per&i)) %then
            %do;
                %debug ("    file exists already: STAGE06.rx_&&vat_per&i");
                %debug ("    No more processing needed. ");
            %end;
            %else
            %do;

                /*
                   Execute loads of steps to create an "RX.rx_&&vat_per&i" file ...
                   The final desired file output is listed below.
                */
                %create_rx_file;

                /*
                output: "rx_&&vat_per&i"
                output: eg. "rx_493.sas7bdat"


                entref          ruref            current_    current_     current_   legal_  live_lu  frozen_   frozen_   frozen_   current_  frozen_    inq_stop    gor   ssr   division  section   empband   class     ent_       emp_
                                                 empment     reg_to       SIC07      status           empment   SIC07     SIC03     SIC03     reg_to                                                                     empment    proportion
                -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                9900000034      49900000034      1           22235        24510      1       1        1         24510     27510     27510     22235      8           F     E     24        C         1         C_1       1          1
                9900000050      49900000050      1           111          82990      1       1        1         82990     74879     74879     111        8           F     E     82        N         1         N_1       1          1
                9900000062      49900000062      1           111          82990      1       1        1         82990     74879     74879     111        8           F     E     82        N         1         N_1       1          1
                9900000064      49900000064      0           0            64202      1       1        0         64202     74158     74158     0          8           F     E     64        K         1         K_1       0          0
                9900000101      49900000101      1           103          74909      1       1        1         74909     74879     74879     103        8           F     E     74        M         1         M_1       1          1
                9900000102      49900000102      0           10138        70100      1       1        0         70100     74158     74158     10138      5           F     E     70        M         1         M_1       0          0
                9900000103      49900000103      0           0            64202      1       1        0         64202     74158     74158     0          8           F     E     64        K         1         K_1       0          0
                9900000118      49900000118      82          11111        29320      1       2        82        29320     34300     34300     11111      5           F     E     29        C         3         C_3       82         1
                9900000126      49900000126      127         37394        33120      1       5        127       33120     29522     29522     37394      5           G     G     33        C         4         C_4       127        1
                9900000127      49900000127      2           300          42990      1       0        2         42990     45213     45213     300        5           Y     Y     42        F         1         F_1       2          1
                9900000144      50000060105      149         108294       49410      1       1        149       49410     60249     60249     108294     5           Y     Y     49        H         4         H_4       329        0.452887538
                9900000144      50000060104      180         42865        49410      1       5        180       49410     60249     60249     42865      5           G     F     49        H         4         H_4       329        0.547112462
                9900000145      49900000145      1           99           64910      1       1        1         64910     65210     65210     99         8           J     G     64        K         1         K_1       1          1
                9900000148      49900000148      223         105127       66290      1       5        223       66290     67200     67200     105127     5           H     H     66        K         4         K_4       223        1
                9900000153      49900000153      0           0            64209      1       1        0         64209     74159     74159     0          8           J     G     64        K         1         K_1       0          0
                9900000177      49900000177      0           0            64209      1       1        0         64209     74159     74159     0          8           J     G     64        K         1         K_1       0          0
                */

            %end;

        %end;

        /*
            EF: Dont delete files at the moment!
           These files created in : '%topping_up_sic07'

           proc delete data = Rx_03tr07;    run;
           proc delete data = Rx_03tr07_f;  run;
           proc delete data = Rx_03tr07_i;  run;
           proc delete data = Rx_03tr07_l;  run;
           proc delete data = Rx_03tr07_ll; run;
        */

%mend harmonise_repex;



/* stage 7 */
%macro vatent_read_in;


    /*
        Reads in the 'vat unit' extract from IDBR, which is
        one of the tables prepared for other Goverment
        departments and is used:
            - for the link between VAT units from the VAT register
            - and the Enterprise reference from IDBR

       Need the following files:
           - "&task_path.\STAGE07\vatunit_&&extract_per&i..";
           - MISC.Vat_ent_lookup (this is "IDBR extracts  period lookup.xls")
    */

    data _null_;
        /* MISC.Vat_ent_lookup = "IDBR extracts  period lookup.xls" */
        set MISC.Vat_ent_lookup end=finish;

        call symput('extract_per' !! compress(_N_),   trim(left(extract_period)));
        call symput('vat_per'     !! compress(_N_),   trim(left(period_vat)));
        call symput('layout'      !! compress(_N_),   trim(left(extract_layout)));

        if finish = 1
        then call symputx('period_num',_N_);

        /* EF TEMP CODE: just process one period */
        call symputx('period_num', 1);
    run;

    %debug ("period_num is: &period_num.")

    %do i = 1 %to &period_num.;

            %debug ('');
            %debug ("vatent_read_in: read Vat_ent_lookup:");
            %debug ("   extract_per&i:     &&extract_per&i");
            %debug ("   vat_per&i:         &&vat_per&i");
            %debug ("   layout&i:          &&layout&i");

            %if %sysfunc(exist(STAGE07.vatent_&&extract_per&i..)) %then
            %do;
                %debug ("    file already exists: STAGE07.vatent_&&extract_per&i..");
                %debug ("    No more processing needed. ");
            %end;
            %else
            %do;

                    /* %put file to be imported vatunit_&&extract_per&i.. ; */
                    %debug ("file to be imported: vatunit_&&extract_per&i.." ) ;

                /*                                                |||||||||||||||||||||||                     */
                /*                                                VVVVVVVVVVVVVVVVVVVVVVV                     */
                        filename ve&&extract_per&i.. "&task_path.\stage-07-vatent_read_in\vatunit_&&extract_per&i..";
                /* OLD: filename ve&&extract_per&i.. "&task_path.\vatunit_&&extract_per&i.."; */

                    /*

                        sample data from vatunit_201404:
                                        9900000002:100293034000:8

                        sample data from vatunit_201602:
                                        9900000002:100293034000:8:07/09/2009
                    */

                    data STAGE07.vatent_&&extract_per&i..;
                        infile ve&&extract_per&i..;
                        input
                        entref    $ 1-10
                        vatref9   $ 12-20;
                        vat_period = &&vat_per&i..;
                    run;

            %end;

    %end;

/*
    Sample output:
    vatent_&&extract_per&i

    entref:         vatref9:        vat_period:
    -------------------------------------------
    9900000002      100293034       493
    9900000007      100328630       493
    9900000009      100328630       493
    9900000013      100328630       493
    9900000014      100328630       493
    9900000017      100328630       493
    9900000017      655130064       493
    9900000017      655130064       493
    9900000022      100328630       493
    9900000034      100328630       493
    9900000034      100328630       493

*/


%mend vatent_read_in;



/* stage 8 */
%macro ve_tidy_up;

    /*

        This macro is the key to the resolving the *many to
        many* relationship between the VAT units and
        Enterprises introduced by the practice of *GROUP
        REPORTING*.

        The VAT Turnover ("to") is reported to HMRC by the
        representative VAT traders who report for themselves
        and for the rest (if any) of the VAT traders in
        their group (called 'non-representatives').

        All first 9 digits in the VAT reference for VAT
        traders belonging to one group are the same and they
        are distinguished by the last 3 digits of their 12
        digit reference.

        Each 12 digit VAT reference belongs to one and only
        one Enterprise unit in the IDBR.

        This macro creates an artificial reference made of
        the 'vat9' reference concatenated with the
        'Enterprise reference'.

        Only records with unique artificial references are
        left for further treatment as the rest are creating
        noise, and hence, not needed for the following
        calculations
    */


    data _null_;
        /* vat.Vat_ent_lookup = "IDBR extracts  period lookup.xls" */
        set misc.Vat_ent_lookup end=finish;
        call symput('extract_per' !! compress(_N_),   trim(left(extract_period)));

        if finish = 1
        then call symputx('period_num',_N_);

        /* EF TEMP CODE: just process one period */
        /* call symputx('period_num', 1); */
    run;

    %debug ("Stage08");
    %debug ("   ve_tidy_up: read lookup table Vat_ent_lookup:");

    %do i = 1 %to &period_num.;

        %debug ('');
        %debug ("   extract_per&i:     &&extract_per&i");


        %if %sysfunc(exist(STAGE08.vatent_&&extract_per&i..)) %then %do;
                %debug ("     file already exists: STAGE08.vatent_&&extract_per&i..");
                %debug ("     No more processing needed. ");
        %end;
        %else
        %do;
                %debug ("      creating file: STAGE08.vatent_&&extract_per&i..");


                proc sql;
                    create table
                    stage08.ve_&&extract_per&i..    as
                                                    select    *,
                                                              compress(vatref9 || '_' || entref) as veref
                                                    from      stage07.vatent_&&extract_per&i
                                                    order by  calculated veref;
                quit;


                data stage08.vatent_&&extract_per&i.. (drop = marker);

                    set stage08.ve_&&extract_per&i..;

                    by veref;

                    /* "First." is SAS code for "first" observation */

                    if FIRST.veref
                        then marker = 0;
                        else marker = 1;

                    if marker = 0;

                run;

                /* EF question: */
                /* EF question: */
                /* EF question: */
                /* delete stage08.ve_&&extract_per&i..; now??? not used anymore? */

        %end;

    %end;

/*

    Sample Output:
    vatent_&&extract_per&i

    entref:         vatref9:        vat_period:     veref:
    --------------------------------------------------------------------
    9907535001      100000132       493             100000132_9907535001    <--- combination "vatref9" + "entref"
    9907535002      100000230       493             100000230_9907535002
    9900100464      100000285       493             100000285_9900100464
    9907626895      100000328       493             100000328_9907626895
    9900325199      100000383       493             100000383_9900325199
    9903544387      100000426       493             100000426_9903544387

*/

%mend ve_tidy_up;



/* stage 09 */
%macro ent_emp_in_ve;

    /*
        This macro:

        - populates VAT unit extracts with enterprise employment;

        - calculates the proportion of the employment in each
            enterprise as part of a vat representative

        All the REPEX files have to be already read in and
        enterprise employment summaries ("ent_emp_&period")
        created from them.

        VAT unit extracts are created at different time and lesser
        frequency than REPEXT files, so the minimum time distance
        will be used when populating the 'VATent' tables with
        'ent_empment'.

        An 'rx_pool' will be created containing the entrefs
        and the corresponding employment at each point in
        time from all the repext files covering the period
        of interest (2007 - 2013)

        The VAT ent table will pick the 'ent_empment' from the pool
        for the corresponding 'entref' and min distance between the
        period of the VAT unit extract and the REPEXT.
    */



    data _null_;
        /* vat.Vat_ent_lookup = "IDBR extracts  period lookup.xls" */
        set MISC.Vat_ent_lookup end=finish;

        call symput('vat_period'  !! compress(_N_),   trim(left(period_vat)));
        call symput('extract_per' !! compress(_N_),   trim(left(extract_period)));

        if finish = 1
        then call symputx('period_num',_N_);

        /* EF TEMP CODE: just process one period */
        /* call symputx('period_num', 1); */
    run;

    %debug ("Stage 09:")
    %debug ("   period_num is: &period_num.")



    %do i = 1 %to &period_num;

        %if &i. = 1 %then
        %do;
            %let b = &i ;
            %let f = %eval(&i + 1);
        %end;

        %if (&i. gt 1) and (&i. lt &period_num.) %then
        %do;
            %let b = %eval(&i. - 1);
            %let f = %eval(&i. + 1);
        %end;

        %if &i. = &period_num. %then
        %do;
            %let b = %eval(&i. - 1) ;
            %let f = &i.;
        %end;


        /*                          'b'                 'f'         */
        /*                           |                   |          */
        /*                           |                   |          */
        /*                           V                   V          */
        %put start from &&vat_period&b.. to &&vat_period&f..;
        %debug ("");
        %debug ("   outer loop:");
        %debug ("   b is:                &b");
        %debug ("   f is:                &f");
        %debug ("   extract_per&i is:    &&extract_per&i..");
        %debug ("   vat_period&b..is:    &&vat_period&b..");
        %debug ("   vat_period&f..is:    &&vat_period&f..");


        proc sql;

            create table stage09.rx_pool_&&extract_per&i..
                        (
                          entref          char(12),
                          ent_empment     num,
                          rx_period       num,
                          ve_rx_dist      num
                         );
        quit;



        /* %do period = 493              %to 493; */
     %do period = &&vat_period&b.. %to &&vat_period&f..;

            %debug ("       inner loop: period        is: &period");
            %debug ("                   vat_period-i  is: &&vat_period&i");

            proc sql;
                /* populate rx_pool */
                insert into stage09.rx_pool_&&extract_per&i..
                            select  distinct entref                               as entref,
                                             ent_empment                          as ent_empment,
                                             &period.                             as rx_period,
                                             %eval(&&vat_period&i.. - &period.)   as ve_rx_dist
                            from             stage06.rx_&period.;
            quit;


        /*
            Sample file:
            rx_pool_&&extract_per&i..

            entref:          ent_empment:   rx_period:      ve_rx_dist:
            -----------------------------------------------------------
            9900000007       0              493             0
            9900000009       0              493             0
            9900000034       1              493             0
            9900000050       1              493             0
            9900000062       1              493             0
            9900000064       0              493             0
            9900000101       1              493             0
            9900000102       0              493             0
            9900000103       0              493             0
            9900000118       86             493             0
            9900000126       219            493             0
            9900000128       1              493             0
            9900000144       394            493             0
            9900000145       1              493             0
            9900000148       182            493             0
        */


            proc sql;
                create table ents_in_&&extract_per&i..     as
                                                           select    entref,
                                                                     min(abs(ve_rx_dist)) as min_dist
                                                           from      stage09.rx_pool_&&extract_per&i..
                                                           group by  entref;

                                            /*
                                                entref:         min_dist:
                                                9900000007      0
                                                9900000009      0
                                                9900000034      0
                                                9900000050      0
                                                9900000062      0
                                                9900000064      0
                                                9900000101      0
                                                9900000102      0
                                                9900000103      0
                                            */


                /* work out "min_dist" */
                create table rx_data_&&extract_per&i..     as
                                                           select     b.entref,
                                                                      a.ent_empment,
                                                                      a.rx_period,
                                                                      b.min_dist * sign(a.ve_rx_dist) as min_dist
                                                           from       ents_in_&&extract_per&i..           b
                                                           left join  stage09.rx_pool_&&extract_per&i..   a
                                                           on         b.entref = a.entref
                                                           and        b.min_dist * sign(a.ve_rx_dist) = a.ve_rx_dist;



                /*
                   work out "best_dist" by taking the MAX
                   "min_dist" from the previous step
                */
                create table ents_in_&&extract_per&i..     as
                                                           select     entref,
                                                                      max(min_dist) as best_dist
                                                           from       rx_data_&&extract_per&i..
                                                           group by   entref;


                /*
                   try to take the "min_dist"

                  Question: its creating table
                  "rx_pool_&&extract_per&i" again!? (that it
                  just created at the top of the loop)
                */

                create table stage09.rx_pool_&&extract_per&i..    as
                                                                  select     b.entref,
                                                                             a.ent_empment,
                                                                             a.rx_period,
                                                                             b.best_dist
                                                                  from       ents_in_&&extract_per&i.. b
                                                                  left join  rx_data_&&extract_per&i.. a
                                                                  on         b.entref    = a.entref
                                                                  and        b.best_dist = a.min_dist;


                create table ve_&&extract_per&i..                 as
                                                                  select      a.*,
                                                                              b.*
                                                                  from        stage08.vatent_&&extract_per&i..   a
                                                                  left join   stage09.rx_pool_&&extract_per&i..  b
                                                                  on          a.entref = b.entref;


                /*
                    ve_&&extract_per&i..
                    ve_201404

                    entref          vatref9     vat_period      veref                   ent_empment     rx_period    best_dist
                    ----------------------------------------------------------------------------------------------------------
                    9900000002      100293034   493             100293034_9900000002    .               .            .
                    9900000007      100328630   493             100328630_9900000007    0               493          0
                    9900000009      100328630   493             100328630_9900000009    0               493          0
                    9900000013      100328630   493             100328630_9900000013    .               .            .
                    9900000014      100328630   493             100328630_9900000014    .               .            .
                    9900000017      100328630   493             100328630_9900000017    .               .            .
                    9900000017      655130064   493             655130064_9900000017    .               .            .
                    9900000022      100328630   493             100328630_9900000022    .               .            .
                    9900000034      100328630   493             100328630_9900000034    1               493          0
                    9900000044      100328630   493             100328630_9900000044    .               .            .
                    9900000055      100328630   493             100328630_9900000055    .               .            .
                */



            quit;


            /* save a copy of the SQL table to disk */
            data stage09.ve_&&extract_per&i..;          set ve_&&extract_per&i..;       run;


        %end; /* %do period = &&vat_period&b %to &&vat_period&f */



        proc delete data = ents_in_&&extract_per&i..;   run;
        proc delete data = rx_data_&&extract_per&i..;   run;


    %end; /* i = 1 %to &period_num */


%mend ent_emp_in_ve;



/* stage 10 */
%macro ve_employment;

        /*
           This macro calculates the *proportions* for the
           apportioning of the VAT turnover to the Enterprises
        */

        data _null_;
            /* vat.Vat_ent_lookup = "IDBR extracts  period lookup.xls" */
            set misc.Vat_ent_lookup end=finish;

            call symput('extract_per' !! compress(_N_),     trim(left(extract_period)));
            if finish = 1 then call symputx('period_num',_N_);

            /* EF TEMP CODE: just process one period */
            /* call symputx('period_num', 1); */
        run;

    %debug ("Stage 10:")
    %debug ("   period_num is: &period_num.")

     /* %do i = 1 %to 25; */
        %do i = 1 %to &period_num.;

            %debug ('   in i loop')
            proc sql;

                /*
                   SUM enterprise employment
                   for all the 'vatref9's


                   NOTE!

                   Note: the 'ent_empment' here originally comes from:
                        stage09.rx_pool_&&extract_per&i..

                   which comes from:
                        stage06.rx_&period.
                */
                create table stage10.vat9_employment   as
                                                       select   vatref9,
                                                             /* SUM! */
                                                                SUM(ent_empment) as vat9_employment
                                                             /* SUM! */
                                                       from     stage09.ve_&&extract_per&i..
                                                       group by vatref9;



                /*
                    EF note: add new column:
                    'case_ve' and default to 'simple'
                        key field: 'emp_proportion'

                */
                create table
                stage10.vatent_&&extract_per&i..    as
                                                    select     a.*,

                                                               case
                                                                   when b.vat9_employment not in (0, .)
                                                                    then
                                                                        a.ent_empment / b.vat9_employment
                                                                    else
                                                                        0
                                                               end
                                                               /* ------------------------------------  */
                                                               as emp_proportion,
                                                               /* ------------------------------------  */

                                                               'simple'    as case_ve length=7

                                                    from       stage09.ve_&&extract_per&i..  a
                                                    left join  stage10.vat9_employment       b

                                                    on         a.vatref9 = b.vatref9
                                                    where      rx_period ne .;


        /*
            SAMPLE files:
            vat9_employment

            vatref9         vat9_
                            empment
            -----------------------
            100000132       .
            100000230       15
            100000285       90
            100000328       10
            100000383       .
            100000524       .
            100000622       4
            100000775       .
            100000818       2


            SAMPLE OUTPUT:
            vatent_&&extract_per&i..

            entref           vatref9     vat        veref                   ent_        rx_         best_dist   emp_
                                        _period                            empment     period                  proportion
            --------------------------------------------------------------------------------------------------------------
            9907535002       100000230   493        100000230_9907535002    15          493         0           1
            9900100464       100000285   493        100000285_9900100464    90          493         0           1
            9907626895       100000328   493        100000328_9907626895    10          493         0           1
            9907535426       100000622   493        100000622_9907535426    4           493         0           1
            9907536020       100000818   493        100000818_9907536020    2           493         0           1
            9907535431       100001227   493        100001227_9907535431    1           493         0           1
            9900100467       100001380   493        100001380_9900100467    24          493         0           1
            9902057336       100001913   493        100001913_9902057336    1           493         0           1

        */

                /*
                   classify VAT-Enterprise relation as SIMPLE or COMPLEX!
                */


                /*
                   - one     VAT unit is linked to      one and only one  Enterprise  (one-to-one)
                   - one     VAT unit is linked to      many              Enterprises (one-to-many)   "group registration"
                   - *many*  VAT units are linked to    one and only one  Enterprise  (many-to-one)
                   - *many*  VAT units are linked to    many              Enterprises (many-to-many)   (eg enterprise in group registration also linked to other vat units in divisional registration)
                */




                /* all '****ENTREFS****' with only 1 'vatref' */
                /* all '****ENTREFS****' with only 1 'vatref' */
                /* all '****ENTREFS****' with only 1 'vatref' */
                /* all '****ENTREFS****' with only 1 'vatref' */

                create table stage10.m_to_1         as
                                                    select    entref,
                                                              count(vatref9) as vat9_instances
                                                    from      STAGE10.vatent_&&extract_per&i..
                                                    group by  entref
                                                    having    calculated vat9_instances = 1;


                /*
                   for all the entrefs with only 1 'vatref',
                   attach the actual 'vatref' beside the
                   column 'vat9_instances'
                */
                create table stage10.m_to_one       as
                                                    select     a.*,
                                                               b.vatref9
                                                    from       stage10.m_to_1                    a
                                                    left join  STAGE10.vatent_&&extract_per&i..  b
                                                    on         a.entref = b.entref;

                /* all '***VATREF9s***' with only 1 'vatref' */
                /* all '***VATREF9s***' with only 1 'vatref' */
                /* all '***VATREF9s***' with only 1 'vatref' */
                /* all '***VATREF9s***' with only 1 'vatref' */

                create table stage10.one_to_m       as
                                                    select    vatref9,
                                                              count(vatref9) as vat9_instances
                                                    from      STAGE10.vatent_&&extract_per&i..
                                                    group by  vatref9
                                                    having    calculated vat9_instances = 1;


                create table stage10.one_to_one     as
                                                    select  *
                                                    from    stage10.m_to_one
                                                    where   vatref9 in (select vatref9
                                                                        from   stage10.one_to_m);

                /*
                                                  vat9_
                               entref         instances
                m_to_1:        9900000002             1
                m_to_1:        9900000007             1
                m_to_1:        9900000009             1
                m_to_1:        9900000013             1
                m_to_1:        9900000014             1
                m_to_1:        9900000034             1
                m_to_1:        9900000050             1
                m_to_1:        9900000057             1
                m_to_1:        9900000062             1
                m_to_1:        9900000064             1



                                                  vat9_
                               entref         instances      vatref9
                m_to_one:      9900000002             1      100293034
                m_to_one:      9900000007             1      100328630
                m_to_one:      9900000009             1      100328630
                m_to_one:      9900000013             1      100328630
                m_to_one:      9900000014             1      100328630
                m_to_one:      9900000034             1      100328630
                m_to_one:      9900000050             1      100328630
                m_to_one:      9900000057             1      100328630
                m_to_one:      9900000062             1      100328630
                m_to_one:      9900000064             1      100328630



                                                 vat9_
                               vatref9       instances
                one_to_m:      100000132             1
                one_to_m:      100000230             1
                one_to_m:      100000285             1
                one_to_m:      100000328             1
                one_to_m:      100000426             1
                one_to_m:      100000524             1
                one_to_m:      100000622             1
                one_to_m:      100000720             1
                one_to_m:      100000775             1
                one_to_m:      100000818             1



                                                  vat9_
                               entref         instances      vatref9
                one_to_one:    9900000002             1      100293034
                one_to_one:    9900000124             1      100711341
                one_to_one:    9900000408             1      109657943
                one_to_one:    9900000417             1      683795377
                one_to_one:    9900000516             1      112253227
                one_to_one:    9900000517             1      112481994
                one_to_one:    9900000518             1      112991377
                one_to_one:    9900000519             1      113142037
                one_to_one:    9900000520             1      113720805
                one_to_one:    9900000524             1      114363304


                */



                /*
                   Finally Set an enterprise to 'complex' if they
                   *ARE NOT* in the 'one_to_one' table
                */
                update stage10.vatent_&&extract_per&i..
                        set
                            case_ve = 'complex'
                        where
                            entref NOT in (select entref
                                           from   stage10.one_to_one) ;

            quit;

        %end;

                /*
                   EF: dont delete intermediate files!
                   old file: vat.ve_&&extract_per&i..;
                   proc delete data = stage09.ve_&&extract_per&i..;
                   run;
                */


        /* intermediate files */


        /*
            EF: dont delete intermediate files
           proc delete data = stage10.vat9_employment;  run;
           proc delete data = stage10.m_to_1;           run;
           proc delete data = stage10.m_to_one;         run;
           proc delete data = stage10.one_to_m;         run;
           proc delete data = stage10.one_to_one;       run;
        */


%mend ve_employment;
