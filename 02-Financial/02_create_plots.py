#   Enda Farrell 2017
#   Enda Farrell 2017
#   Enda Farrell 2017

# - Read in a CSV file containing FSS survey
#   responses for security dealers for many previous quarters.
#
#
# - For each dealer, and for each question, create summary
#   statistics showing the MAX, MIN, MEAN response etc.
#   Also create Barcharts and Boxplots to visualise the responses.

#   Sample Summary Stats file:
#
#     RU Reference, Question, Max Response, Min Response, Median Response, Mean Response, Standard Deviation
#     49900220794,    q1000,        20.70,         1.90,            4.55,          8.00,               7.55
#     49900220794,    q1001,        30.30,         0.00,            7.65,         12.28,              14.28
#     49900220794,    q1002,         1.30,         0.10,            0.60,          0.66,               0.44
#     49900220794,    q1003,       405.90,       119.20,          171.80,        206.93,             105.05
#     49900220794,    q1004,      1817.30,      1171.10,         1602.45,       1572.77,             244.84
#     49900220794,    q1005,      6039.70,      3308.80,         4730.05,       4624.78,            1185.84
#     49900220794,    q1011,         0.00,         0.00,            0.00,          0.00,               0.00
#     ...........,    .....,         ....,         ....,            ....,          ....,               ....
#     ...........,    .....,         ....,         ....,            ....,          ....,               ....
#     ...........,    .....,         ....,         ....,            ....,          ....,               ....

print ('\nLoading libraries... (may take a minute)...\n')

import os
import pandas as pd
import sys

from plot_utils import utils

# from imp import reload
# reload(utils)



# Define input/output files and folder locations

sas_results_dir   = "_SAS_OUTPUT"
sas_results_csv   = 'dealer_historical_responses.csv'

csv_output_dir    = "_dealer_stats"
plot_dir          = "_dealer_plots"

workbook          = 'parameters.xlsx'
dealer_csv        = 'dealer_summary_stats.csv'

# Define valid responses for yes/no questions
# (Python "input" returns an empty string for [Enter])
yes = set(['yes','y', 'ye'])
no  = set(['no','n', ''])

print ('\nInput Files/Parameters:')
print ('    sas_results_dir    ' + sas_results_dir)
print ('    sas_results_csv:   ' + sas_results_csv)
print ('    workbook:          ' + workbook)

print ('\nOutput Files:')
print ('    plot_dir           ' + plot_dir)
print ('    csv_output_dir     ' + csv_output_dir)
print ('    dealer_csv:        ' + dealer_csv)



# Check input files exist...

if not os.path.exists(workbook):
    print ('\nExcel workbook not found!'
           '\nCannot find: "%s"\n' % workbook)
    sys.exit("Stopped because of Error.")

csv_file = os.path.join(sas_results_dir, sas_results_csv)

if not os.path.exists(csv_file):
    print ('\nCSV File not found!'
           '\nCannot find: "%s"'
           '\n\nDid the SAS program create it successfully?\n' % csv_file)
    sys.exit("Stopped because of Error.")



# Read input parameters from Excel
questions   = utils.excel_read_col(workbook, sheet='QUESTIONS', col_idx=0)
dealer_refs = utils.excel_read_col(workbook, sheet='DEALERS',   col_idx=0)

# When dealer RU references are read from Excel,
# they're in float format. Coerce them into
# integers so they'll look better in the plots...
dealer_refs = list(map(int, dealer_refs))

display_order = {}
for i, question in enumerate(questions):
    display_order[question] = i

print('\nQuestion Display Order:')
for key, value in sorted(display_order.items()):
    print("{} : {}".format(key, value))



# Read CSV file which was
# created by 'extract_questions.sas'
df_dealers = pd.read_csv(csv_file, parse_dates=['IDBRPeriod'])

# display a sample of the dealer data
print ('\nSample of Dealer data:')
print (df_dealers.head())
print ('\nDealer records loaded: ' + str(len(df_dealers)) )



# create new output folder
utils.rotate_folder(csv_output_dir)

# generate a file with summary statistics
utils.create_stats_csv(df_dealers,
                       csv_output_dir,
                       display_order,
                       output_file=dealer_csv)



print("""\n
------------------------------------------
CREATE PLOTS
This could take 20-30 mins...
To terminate at any time: Press [Ctrl+c]
------------------------------------------
""")

# Double-check with user first...
answer = input('Do you want to create Plots? \
                \nPlease press "y" or "n": ').lower()

if answer in yes:
    # create plot folder
    # (backup existing one first)
    utils.rotate_folder(plot_dir)

    # create Barcharts (shows trends of dealer responses)
    utils.barchart_grid(df_dealers, questions, dealer_refs, plot_dir)
    utils.barchart_grid(df_dealers, questions, dealer_refs, plot_dir, share_yaxis=False)

    # create Boxplots (shows magnitude of dealer responses)
    utils.process_boxplots(df_dealers, questions, dealer_refs, plot_dir)

print('\nProcessing Finished.\n\n')
