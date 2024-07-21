
#   Enda Farrell 2017
#   Enda Farrell 2017
#   Enda Farrell 2017

import os
import sys
import time
import shutil
import xlrd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

from xlrd.sheet  import ctype_text
from matplotlib  import ticker

plt.style.use('seaborn-darkgrid')

sns.set()
sns.set_style("darkgrid")

def rotate_folder(dirname, verbose=False):
    # Create a new directory 'dirname', but first
    # backup any pre-existing 'dirname'.

    if os.path.exists(dirname):
        # Folder exists already - dont overwrite it.
        # Just move it to a new location.

        # note: remove any trailing slashes from
        # 'dirname'. It messes up 'copytree' if you 
        # have a slash...
        dirname = dirname.rstrip(os.sep)
        now     = time.strftime('%Y%m%d_%H%M%S')
        new_dir = dirname + '_old_' + str(now)

        # create copy of existing folder, then delete it
        if verbose:
            print ("\nMoving '{source}' to '{target}' ...".format(source=dirname, target=new_dir))

        shutil.copytree(dirname, new_dir)
        shutil.rmtree(dirname)

    if verbose:
        print ("(Re)creating '{original}' ...".format(original=dirname))

    # Finally (re)create the folder
    os.mkdir(dirname)

def do_question_boxplot(dealers, question_num, dealer_order, plot_folder):

    df_question = dealers[dealers.question == question_num]

    title    = str(question_num)
    plotname = str(question_num) + '-boxplot.jpg'

    sns.set_style("whitegrid")
    fig = plt.figure(figsize=(10, 10))

    # -----------------------------------------------------------
    ax = sns.boxplot(x='RUReference',    
                     y='value',          
                     data=df_question,   
                     showmeans=True,     
                     order=dealer_order) 

    ax = sns.swarmplot(x='RUReference',    
                       y='value',          
                       data=df_question,   
                       order=dealer_order) 
    # -----------------------------------------------------------

    ax.set_title(title, fontsize=50)

    ax.get_yaxis().set_major_formatter(
            ticker.FuncFormatter(lambda x, p: format(int(x), ',')))

    ax.tick_params(axis='x', which='major', labelsize=10)
    ax.tick_params(axis='y', which='major', labelsize=10)

    for label in ax.get_xticklabels():
            label.set_rotation(75)

    plt.savefig(os.path.join(plot_folder, plotname ), format='jpg')
    print ('\nCreated plot: ' + plotname)

    # plt.show()

    # stop "out of memory" errors
    plt.close(fig)

def process_boxplots(df_dealers, all_questions, dealer_refs, plot_folder):

    # Create a boxplot for each question
    for question in all_questions:
        do_question_boxplot(df_dealers, question, dealer_refs, plot_folder)

def create_stats_csv(dealer_df, output_folder, display_order, output_file):

    # Create a CSV file with the max/min/mean etc 
    #       - for each question 
    #       - for each dealer
    

    summary_df = dealer_df.groupby(by=['RUReference', 'question'], as_index=False) \
                          .agg({'value': [np.min, np.max, np.median, np.mean, np.std]}) 

    # Use the 'display_order' DICTIONARY to create a new column 
    # which controls the order questions are listed in the output 
    # CSV file. Makes manual construction easier for the accounts team...
    summary_df['display_order'] = summary_df['question'].map(lambda x: display_order[x])

    # Now re-sort questions according to "display order"
    summary_df.sort_values(['RUReference', 'display_order'], ascending=True, inplace=True)

    # Convert multi-index column names 
    # into flat column names
    summary_df.columns = [' '.join(col).strip() for col in summary_df.columns.values]

    # Define user-friendly column names
    col_headers = [
                   'RU Reference', 
                   'Question', 
                   'Min Response',
                   'Max Response',
                   'Median Response',
                   'Mean Response',
                   'Standard Deviation',
                   '(Display Order)'
                  ]

    summary_df.to_csv(os.path.join(output_folder, output_file), 
                      float_format='%.2f',
                      mode='w',
                      header=col_headers,
                      index=False)

    print('\nCreated summary statistics file: \n\t' + os.path.join(output_folder, output_file) )

def excel_read_col(workbook, sheet, col_idx, skip_header=True):
    # read all rows for a specific column
    rows = []

    if not os.path.exists(workbook):
        print ('Excel Workbook not found: ' + workbook)

    else:
        xl_workbook = xlrd.open_workbook(workbook)
        xl_sheet    = xl_workbook.sheet_by_name(sheet)

        print ('\nReading column [%s] from sheet [%s]' % (str(col_idx), sheet))

        if skip_header:
            start_row = 1
        else:
            start_row = 0

        for row_idx in range(start_row, xl_sheet.nrows):
            cell_obj = xl_sheet.cell(row_idx, col_idx)
            cell_type_str = ctype_text.get(cell_obj.ctype, 'unknown type')
            print('(%s) %s %s' % (row_idx, cell_type_str, cell_obj.value))
            rows.append(cell_obj.value)

    return rows

def barchart_grid(df_dealers, plot_questions, dealer_refs, plot_folder, share_yaxis=True):

    # Define grid size
    if len(dealer_refs) <= 9:
        # Only a small number of dealers,
        # set default subplot grid to 3 by 3
        grid_cols = 3
        grid_rows = 3
    else:
        # try to guess a reasonable grid-size 
        # based on the number of dealers
        grid_cols = 3
        grid_rows = int(np.ceil(len(dealer_refs) / grid_cols))

    print ('\nCreating a grid with %s columns and %s rows...' % (grid_cols, grid_rows))

    # create a Grid for each question
    for question in plot_questions:
        df_question = df_dealers[(df_dealers.question == question)]

        if share_yaxis:
            plotname  = question + '_scaled.jpg'
        else:
            plotname  = question + '.jpg'

        # Create a grid of plots
        fig, axes = plt.subplots(nrows=grid_rows,
                                 ncols=grid_cols,
                                 sharex=True,
                                 sharey=share_yaxis,
                                 figsize=(12, 15))

        # initialise grid co-ordinates
        col = 0
        row = 0
        width = 1/1.5

        # periods =['Q1','Q2', 'Q3', 'Q4', 'Q5', 'Q6']
        periods = df_question.periodnumber.unique().tolist()

        # Create subplot for each dealer
        for (i, ru_ref) in enumerate(dealer_refs):

            # which subplot are we on?
            if col > 2:
                # go back to first column
                # and move down to next row
                col =  0
                row += 1

            mask      = (df_question['RUReference'] == ru_ref)
            df_dealer = df_question[mask]

            period_grouped = df_dealer.groupby(by=['periodnumber'], as_index=False)['value'].sum()

            x_values = period_grouped['periodnumber']
            y_values = period_grouped['value']

            colors = np.array(['mediumpurple'] * len(y_values))

            negatives = np.array(y_values < 0, dtype = bool)
            colors[negatives] = 'red'

            axes[row, col].set_title('RU: ' + str(ru_ref), bbox={'facecolor':'sienna', 'alpha':0.5, 'pad':3})

            if share_yaxis:
                # Use same y-axis scale for all subplots.
                # First try to figure out a sensible scale.
                min_value = np.min(df_question['value'])
                max_value = np.max(df_question['value'])

                # just start y-axis from zero 
                # if the minimum is positive
                if min_value > 0:
                    min_value = 0

                # now add a little bit above and below
                # the max/min values. Makes plot look better
                min_value = min_value - (abs(max_value - min_value) * 0.10)
                max_value = max_value + (abs(max_value - min_value) * 0.10)

                # set the scale
                axes[row, col].set_ylim([min_value, max_value])
            else:
                # Dont set an explict range on the y axis.
                # Each subplot has its own y-axis limits.
                pass

            # ----------------------------------------------------------------------------
            axes[row, col].bar(x_values, y_values, width,  align='center', color=colors)
            # ----------------------------------------------------------------------------

            plt.xticks(x_values, periods)

            if row+1 == grid_rows:
                # we're on the bottom row
                axes[row, col].set_xlabel('Responses', fontsize=12)

            # Draw a thin line along y=0
            axes[row, col].axhline(y=0.0, linewidth=0.75, color='0.75')

            axes[row, col].tick_params(axis='x', which='both', labelsize=10)
            axes[row, col].tick_params(axis='y', which='both', labelsize=10)

            # move to next subplot
            col += 1

        fig.suptitle(plotname, fontsize=35)
        fig.tight_layout(pad=7, w_pad=8, h_pad=2.5)

        plt.savefig(os.path.join(plot_folder, plotname ), format='jpg')
        print ('\nCreated Plot: %s ' % os.path.join(plot_folder, plotname) )

        # plt.show()

        # stop "out of memory" errors
        plt.close(fig)
