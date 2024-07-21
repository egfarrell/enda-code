
/* Enda Farrell 2016 */
/* Enda Farrell 2016 */
/* Enda Farrell 2016 */
/* Enda Farrell 2016 */
/* Enda Farrell 2016 */

/*
   1.	Verify and Clean 1000 pounds errors
*/
%macro verify_clean_1000p (per=, patt=, case=);

    /*
       Key input file: ruto_&case._&patt.&per

                   eg. ruto_complex_q513    (complex, quarterly)
                       ruto_complex_a513    (complex, annual)
                       ruto_complex_m513    (complex, annual)
                       ruto_simple_q513     (simple, quarterly)
    */

    /*
       This rule is applied to businesses who have possibly
       incorrectly reported their VAT return in thousand
       pounds instead of pounds.

       This rule works by calculating a ratio between
       current VAT return in comparison to their previous
       VAT return.

       If the ratio falls between the values 0.00065 and
       0.00135 it is multiplied by 1000.
    */


    /* &patt = m     Monthly   */
    /* &patt = q     Quarterly */
    /* &patt = a     Annual    */
    %if &patt. = m  %then  %let per_1 = %Eval(&per - 1);
    %if &patt. = q  %then  %let per_1 = %Eval(&per - 3);
    %if &patt. = a  %then  %let per_1 = %Eval(&per - 12);

    %debug ("           macro: verify_clean_1000p")
    %debug ("           patt  is: &patt")
    %debug ("           per_1 is: &per_1")

    %debug ("           creating table: verify_1000p_&per._&patt.")
    %debug ("                   from table: ruto_&case._&patt.&per.     as a")
    %debug ("                   and  table: ruto_&case._&patt.&per_1.     as b")

    proc sql;
        create table STAGE15.verify_1000p_&patt._&per.  as select     new.ruref,
                                                                      new.class,
                                                                      new.ru_vat_to,
                                                                      case
                                                                          when (
                                                                                    (prev.ru_vat_to not in  (., 0)) and
                                                                                    (new.ru_vat_to  between (prev.ru_vat_to * 0.00065) and
                                                                                                            (prev.ru_vat_to * 0.00135))
                                                                                )
                                                                                then 1
                                                                                else 0
                                                                      end as clean_marker
                                                           from       STAGE13.ruto_&case._&patt.&per.   as new
                                                           left join  STAGE13.ruto_&case._&patt.&per_1. as prev
                                                           on         new.ruref = prev.ruref;


        /*
           go back and update 'ruto_' table,
           multiply turnover amount by 1000
        */

            /* vat */

            /* ah here is the double underscore!!! */
            /* ah here is the double underscore!!! */

            /* when &case is blank, then the file will be: */
            /* 'ruto__m516' for example */

        update STAGE13.ruto_&case._&patt.&per.   set   ru_vat_to    = ru_vat_to * 1000,
                                                       clean_marker = 1
                                                 where ruref in (select  ruref
                                                                 from    STAGE15.verify_1000p_&patt._&per.
                                                                 where   clean_marker = 1);


    quit;

%mend verify_clean_1000p;



/*
   3.	Verify and Clean Strange Quarterly Reporting Patterns
*/
%macro verify_clean_Qrep_patterns (per=, case=);


    /*
        John Allcoat article:
        This rule is only applied to businesses reporting
        VAT on a quarterly basis. There are 3 variations for
        the 'quarterly patterns' rule. The aim is to try to
        understand whether these businesses are reporting
        *true* quarterly HMRC turnover, by identifying
        suspicious quarterly patterns.

        If a strange Quarterly pattern is detected, the
        annual value is re-assigned to the corresponding
        quarters using the median proportions between the
        quarters calculated from the businesses in the same
        class with genuine reported values. (A class is
        defined as the industry section as per the UK
        SIC2007 industrial classification and employment
        sizeband.)
    */


    /*
        the key files
            STAGE13.ruto_simple_q&period.    STAGE13.ruto_simple_q513
            STAGE13.ruto_complex_q&period.   STAGE13.ruto_complex_q513
    */


    /*
       this macro only processes
       pattern 'q' (for quarterly)
    */
    %let patt  = q;

    %let per_3 = %eval(&per - 3);
    %let per_6 = %eval(&per - 6);
    %let per_9 = %eval(&per - 9);

    %debug ("           macro: verify_clean_Qrep_patterns")
    %debug ("           patt  is: &patt")
    %debug ("           per_3 is: &per_3")
    %debug ("           per_6 is: &per_6")
    %debug ("           per_9 is: &per_9")


    %debug ("               sorting 4 files:")
    %debug ("               ruto_&case._&patt.&per     ");
    %debug ("               ruto_&case._&patt.&per_3   ");
    %debug ("               ruto_&case._&patt.&per_6   ");
    %debug ("               ruto_&case._&patt.&per_9   ");

                    /* vat. */
    proc sort   data = STAGE13.ruto_&case._&patt.&per;    by ruref;   run;
    proc sort   data = STAGE13.ruto_&case._&patt.&per_3;  by ruref;   run;
    proc sort   data = STAGE13.ruto_&case._&patt.&per_6;  by ruref;   run;
    proc sort   data = STAGE13.ruto_&case._&patt.&per_9;  by ruref;   run;


    data STAGE15.four_quarters_&per
         STAGE15.four_quarters_clean_&per (where = (clean_marker = 0));

        /*
           By default the four files: (ruto_&case._&patt.&per{_,3,6,9})
           have a initial value of 'clean_marker=0' which was assigned in
           the macro: '%linking_with_ru'
        */

        merge STAGE13.ruto_&case._&patt.&per.    (in = in_current)
              STAGE13.ruto_&case._&patt.&per_3.  (keep= ruref ru_vat_to  rename= (ru_vat_to = ru_vat_to_3))
              STAGE13.ruto_&case._&patt.&per_6.  (keep= ruref ru_vat_to  rename= (ru_vat_to = ru_vat_to_6))
              STAGE13.ruto_&case._&patt.&per_9.  (keep= ruref ru_vat_to  rename= (ru_vat_to = ru_vat_to_9));

        by ruref;

        /* calculate total turnover from the 4 quarters */
        four_q_to = ru_vat_to    +
                    ru_vat_to_3  +
                    ru_vat_to_6  +
                    ru_vat_to_9;


        if four_q_to ne 0 then
        do;
            /*  Proportion out Turnover over the 4 quarters */
            prop_1 = ru_vat_to   / four_q_to;
            prop_2 = ru_vat_to_3 / four_q_to;
            prop_3 = ru_vat_to_6 / four_q_to;
            prop_4 = ru_vat_to_9 / four_q_to;
        end;
        else
        do;
            prop_1 = 0;
            prop_2 = 0;
            prop_3 = 0;
            prop_4 = 0;
        end;


       /*
          John Allcoat article:
          If the reporting unit has the exact *same*
          positive value for any 4 consecutive, then this
          implies the business is actually reporting ANNUAL
          values allocated equally between the 4 quarters
       */
        if ( ru_vat_to not in (0, .) ) and
           ( ru_vat_to = ru_vat_to_3 ) and
           ( ru_vat_to = ru_vat_to_6 ) and
           ( ru_vat_to = ru_vat_to_9 )
        then
            clean_marker = 2;



        /* old commented code removed */

        /*
           John Allcoat article:
           Check for reporting units having exactly the same
           positive values in any 3 consecutive quarters and
           then a different value for the fourth quarter.

           This implies the business is assessing its annual
           value and allocating it between the 4 quarters.
           The fourth quarter therefore is allocated the
           residual value to sum to the annual value.
        */

        if ( (ru_vat_to   not in (0, .)) and
             (ru_vat_to_9 not in (0, .))     )
            and
            ( (ru_vat_to    =   ru_vat_to_3) and
              (ru_vat_to_3  =   ru_vat_to_6) and
              (ru_vat_to_6  ne  ru_vat_to_9) )
            then
                clean_marker = 3;


        if ( (ru_vat_to   not in (0, .)) and
             (ru_vat_to_6 not in (0, .))     )
            and
            ( (ru_vat_to    =   ru_vat_to_3) and
              (ru_vat_to_3  =   ru_vat_to_9) and
              (ru_vat_to_9  ne  ru_vat_to_6) )
            then
                clean_marker = 3;


        if ( (ru_vat_to   not in (0, .)) and
             (ru_vat_to_3 not in (0, .))     )
            and
            ( (ru_vat_to    =   ru_vat_to_9) and
              (ru_vat_to_9  =   ru_vat_to_6) and
              (ru_vat_to_6  ne  ru_vat_to_3) )
            then
                clean_marker = 3;


        if ( (ru_vat_to   not in (0, .)) and
             (ru_vat_to_3 not in (0, .))   )
            and
            ( (ru_vat_to_9 =  ru_vat_to_3) and
              (ru_vat_to_3 =  ru_vat_to_6) and
              (ru_vat_to_6 ne ru_vat_to  ) )
            then
                clean_marker = 3;


        /* old clean_marker = 4 code removed */


        /*
           Allcoat article:
           Check for reporting units having zero values in
           *any* (see note) 3 quarters and then a positive value in the
           fourth quarter. This implies the business is
           returning an annual value.

           note: why "any". The code here is "all" 3 quarters, not "any"
        */



        /* this should really check for '0' as well as '.' ??? */
        if  ( ru_vat_to     ne  . )  and
            ( ru_vat_to_3   =   0 )  and
            ( ru_vat_to_6   =   0 )  and
            ( ru_vat_to_9   =   0 )
        then
        do;
            file print notitles;
            put "       Setting clean marker 4!!";
            put "       current period is &per";
            put '       ru_vat_to is '  ru_vat_to;
            file log;
            clean_marker = 4;
        end;


        if in_current;
    run;



    /*
        EF Note:
        prop = "proportion"

        Hold on! which value of 'prop_1' does the 'medians' macro use??
        Each row in the table will have a different 'prop_1' value ...

        Answer: ah 'medians' doesnt care about the *value* of prop_1,
        it just wants to know which *field* to concentrate on...
    */
    %medians(argument = prop_1,  data_set = STAGE15.four_quarters_clean_&per, curr_period=&per);
    %medians(argument = prop_2,  data_set = STAGE15.four_quarters_clean_&per, curr_period=&per);
    %medians(argument = prop_3,  data_set = STAGE15.four_quarters_clean_&per, curr_period=&per);
    %medians(argument = prop_4,  data_set = STAGE15.four_quarters_clean_&per, curr_period=&per);

    /*
    'medians' creates: - medians
                       - nz_medians
                       - med_prop_1
                       - med_prop_2
                       - med_prop_3
                       - med_prop_4
    */


    proc sort data = STAGE15.four_quarters_&per;
        by class;
    run;


    data STAGE15.four_q_medians_&per;

        merge STAGE15.med_prop_1_&per
              STAGE15.med_prop_2_&per
              STAGE15.med_prop_3_&per
              STAGE15.med_prop_4_&per
              STAGE15.four_quarters_&per (in = in_main);

        by class;
        if in_main;
    run;

    %update_q_patterns(update_period=&per_9, n=4, curr_period=&per);
    %update_q_patterns(update_period=&per_6, n=3, curr_period=&per);
    %update_q_patterns(update_period=&per_3, n=2, curr_period=&per);
    %update_q_patterns(update_period=&per,   n=1, curr_period=&per);

%mend verify_clean_Qrep_patterns;





/*
   4.	Verify and Clean Suspicious Values
*/
%macro verify_clean_susp_val (per=, patt=, case=);


    /*
        John Allcoat article:
        This macro identifies reporting units that have suspicious turnover
        for a VAT return.

        A return is deemed suspicious by firstly matching their current VAT
        return to their previous VAT return. (This applies for all the
        reporting schedules).

        A value is deemed suspicious as a reporting unit will be compared
        to all reporting units within that *employment SizeBand* at the UK
        SIC 2007 class level.

        Once the data has been stratified by class and employment sizeband
        the reporting unit’s current and previous VAT returns will be
        tested in comparison to the median value of the class and reporting
        stagger.

        A set of criteria in terms of scores is then produced and if it
        falls outside these scores it will be deemed as a suspicious
        turnover value.

        This is then replaced by a value which is the ratio of the current
        period sum of VAT turnover divided by previous period sum of VAT
        turnover for the total UK SIC 2007 class and employment sizeband
        multiplied by the reporting unit previous period VAT turnover
        figure.
    */

    %if &patt = m  %then  %let  per_1 = %eval(&per - 1);
    %if &patt = q  %then  %let  per_1 = %eval(&per - 3);
    %if &patt = a  %then  %let  per_1 = %eval(&per - 12);

    proc sql;
        create table stage15.neighbour_periods_&case._&patt._&per.       as select  current.class,
                                                                                    current.ruref,
                                                                                    current.freq_rep,
                                                                                    current.ru_vat_to,
                                                                                    previous.ru_vat_to as ru_vat_to_1,
                                                                                    current.clean_marker
                                                                         from       STAGE13.ruto_&case._&patt.&per.   current
                                                                         left join  STAGE13.ruto_&case._&patt.&per_1. previous
                                                                         on         current.ruref = previous.ruref;
                                                                         /* on         current.class = previous.class; */

    quit;


    /* compare to the median of a group in the same employment class */
    %medians(argument = ru_vat_to,   data_set = stage15.neighbour_periods_&case._&patt._&per, curr_period=&per);
    %medians(argument = ru_vat_to_1, data_set = stage15.neighbour_periods_&case._&patt._&per, curr_period=&per);

    /* ef-note: added in "run" statement here here */
    proc sort data = stage15.neighbour_periods_&case._&patt._&per.;
        by class;
    run;


    data STAGE15.verify_susp_val_&per
         STAGE15.clean_&per (where=(clean_marker=0));

        merge STAGE15.neighbour_periods_&case._&patt._&per.
              STAGE15.med_ru_vat_to_&per
              STAGE15.med_ru_vat_to_1_&per;

        by class;

        score_1 = ru_vat_to   / med_ru_vat_to;
        score_2 = ru_vat_to_1 / med_ru_vat_to_1;


        select;
            when (score_1 ge score_2) ratio = score_1 / score_2;
            when (score_2 gt score_1) ratio = score_2 / score_1;
            otherwise;
        end;

        select;
            when ((compress(freq_rep) = 'm') and (ratio gt 7)) clean_marker = 5;
            when ((compress(freq_rep) = 'q') and (ratio gt 5)) clean_marker = 5;
            when ((compress(freq_rep) = 'a') and (ratio gt 4)) clean_marker = 5;
            otherwise;
        end;

    run;


    /*
       when I set all 'ruto_...' clean_markers to '4', then
       this sum couldnt be calculated because there was
       nothing in the 'clean_&per' dataset
    */
    %calculate_sum(argument = ru_vat_to,   dataset = STAGE15.clean_&per);
    %calculate_sum(argument = ru_vat_to_1, dataset = STAGE15.clean_&per);


    data  STAGE15.susp_values_to_update_&per;

        merge STAGE15.verify_susp_val_&per (in = in_main)
              STAGE15.sum_ru_vat_to
              STAGE15.sum_ru_vat_to_1;

        by class;

        if  sum_ru_vat_to_1 ne 0
            then  growth_ratio = sum_ru_vat_to / sum_ru_vat_to_1;
            else  growth_ratio = 0;

        if in_main and clean_marker = 5;
    run;


    /* cap growth_ratio !!! */

    proc sql;
        create table stage15.ruto_susp_&case._&patt.&per.  as select   a.*,
                                                                       b.ru_vat_to_1 * b.growth_ratio as new_vat_to
                                                           /* from        vat.ruto_&case._&patt.&per. a                 */
                                                           from        STAGE13.ruto_&case._&patt.&per.         a
                                                           left join   STAGE15.susp_values_to_update_&per      b
                                                           on          a.ruref = b.ruref;


        update stage15.ruto_susp_&case._&patt.&per.        set    ru_vat_to    = new_vat_to,
                                                                  clean_marker = 5
                                                           where  new_vat_to ne .;

    quit;

    /* ef note: dont bother updating the old ruto file in stage 13 (ie vat) */
    /* data vat.ruto_&case._&patt.&per.; */
        /* set stage15.ruto_susp_&case._&patt.&per. (drop = new_vat_to); */
        /* set ruto_&case._&patt.&per. (drop = new_vat_to); */
    /* run; */

%mend verify_clean_susp_val;



/*
   5.	Putting all verifying and cleaning together
*/
%macro verify_and_clean (minp=, maxp=, case=);

    /*
        John Allcoat article
        (Has summary of Cleaning Rules)
    */

    %debug ("Stage 15")
    %debug ("verify_clean")
    %debug ("   minp = &minp")
    %debug ("   maxp = &maxp")
    %debug ("   case = &case")

    /*
        key input files:
            STAGE13.ruto_simple_a...
            STAGE13.ruto_simple_q...
            STAGE13.ruto_simple_m...

            STAGE13.ruto_complex_a...
            STAGE13.ruto_complex_q...
            STAGE13.ruto_complex_m...
    */

    %do i = 1 %to 3;

        %debug ("   in 'i' loop (1 to 3):  i = &i")

        %if &i = 1 %then  %let  pattern = m;  /* monthly   */
        %if &i = 2 %then  %let  pattern = q;  /* quarterly */
        %if &i = 3 %then  %let  pattern = a;  /* annual    */

        %do period = &minp %to &maxp;

            %debug ("                              ")
            %debug ("        loop: period = &period")
            %debug ("        case = &case")
            %debug ("        patt = &pattern")

            /* test 1 */
            /* %verify_clean_1000p (per=&period, patt=&pattern, case=&case); */

            /* test 2 */
            %if &pattern = q %then
                %verify_clean_Qrep_patterns (per=&period, case=&case);

            /* test 3  - temp change ef!!!! just run for quarterly*/
            /* %if &pattern = q %then */
                /* %verify_clean_susp_val (per=&period, patt=&pattern, case=&case); */

        %end;

    %end;

%mend verify_and_clean;



%macro verify_and_clean2 (minp=, maxp=);

	%do period = &minp. %to &maxp.;
            %debug ("                              ")
            %debug ("        verify_and_clean2     ")
            %debug ("        loop: period = &period")
            %debug ("        case = &case")

        /* EF: where does "case" get passed in here? */
		%verify_clean_1000p    (per=&period, patt=m, case=);
		/* %verify_clean_susp_val (per=&period, patt=m, case=); */

	%end;

%mend;
