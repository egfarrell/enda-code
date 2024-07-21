# coding: utf-8

# In[2]:

# E. Farrell 2019
# E. Farrell 2019
# E. Farrell 2019
# E. Farrell 2019
# E. Farrell 2019
# E. Farrell 2019

import os

import folium
import pandas as pd
import geopandas as gpd
from string import Template
import numpy as np

from folium.plugins import HeatMap
from folium.plugins import MarkerCluster

# 'pyproj' needs extra files from a 'share' folder
os.environ["PROJ_LIB"] = "~/pyproj-data-folder"
resource_folder        = os.path.join(os.path.expanduser('~'), 'repos', 'resources')

pd.set_option('display.width', 200)
pd.set_option('display.max_colwidth', 20)
pd.set_option('display.max_columns', 50)
pd.set_option('display.max_rows', 15)

# In[]

# 199 different wards
application_file = 'data/Application Data-input.csv'
applications     = pd.read_csv(application_file)

applications.rename(columns={'ILK App. Conv. %': 'Conv' }, inplace=True)
applications.rename(columns={'Sum of Enrolled at ILK (number)': 'Enrolled' }, inplace=True)
applications.rename(columns={'Applied to ILK': 'Applications' }, inplace=True)


# how many learners do we have AT THE START?
applications.groupby(by=['Funding Type'])['Applications'].sum().sort_values()

# How many learners after removing low wards?
# Change to greater than 4...
ward_totals             = applications.groupby(by=['Ward'], as_index=False).sum()
big_wards               = ward_totals.query('Applications >= 4')
big_ward_codes          = big_wards['Ward'].unique().tolist()
mask                    = applications['Ward'].isin(big_ward_codes)
applications            = applications[mask]
applications.groupby(by = ['Ward'])['Applications'].sum().sort_values()

# 97 different wards
learner_file  = 'data/ilkeston-students-with-coords.csv'
learners      = pd.read_csv(learner_file)
ward_file     = os.path.join(resource_folder, 'ONSPD_NOV_2018_UK-ward-lookup.csv')
ward_lookup   = pd.read_csv(ward_file)
shapefile     = os.path.join(resource_folder, 'uk-wards-shapefiles', 'Clipboundaries.shp')
uk_wards_geo  = gpd.read_file(shapefile)

# In[]

# try and find a ward code
# for each application row

merged = pd.merge(applications, ward_lookup[['WD18NM', 'WD18CD']],
                  # how='inner',
                  how='left',
                  left_on=['Ward'],
                  right_on=['WD18CD'],
                  indicator=True)

# In[]

application_ward_codes  =  merged['WD18CD'].unique().tolist()

mask      = uk_wards_geo['wd16cd'].isin(application_ward_codes)
app_wards_geo = uk_wards_geo[mask]

shapefiles_found  =  app_wards_geo['wd16cd'].unique().tolist()

have_shapefile = [x for x in application_ward_codes if x in set(shapefiles_found)]

# bad wards
# ['S13002884',
# 'N08000101',
# 'N08001001',
# 'E05011121',
# 'E05011298',
# 'E05011428',
# 'E05011432']

good_wards            = merged['WD18CD'].isin(have_shapefile)
bad_wards             = ~merged['WD18CD'].isin(have_shapefile)
fixed_applications    = merged[good_wards]
applications_no_wards = merged[bad_wards]


# In[]

# setup a shorter funding name
short_names = ['CLL', 'School', 'App']
long_names  = fixed_applications['Funding Type'].unique().tolist()
name_dict   = dict(zip(long_names, short_names))

def set_short_name(f):
    return name_dict[f]

fixed_applications['funding'] = fixed_applications['Funding Type'].map(set_short_name)

# show totals
fixed_applications.groupby(by=['funding', 'Funding Type']).sum()

# In[]

# remove un-needed columns
# fixed_applications.drop(['WD18NM'], axis=1, inplace=True)
fixed_applications.drop(['_merge'], axis=1, inplace=True)
fixed_applications.drop(['Funding Type'], axis=1, inplace=True)

# In[]

summary = pd.pivot_table(fixed_applications,
                         index=['WD18CD', 'Ward'],
                         columns=['funding', 'Year'],
                         values=['Conv', 'Applications', 'Enrolled'],
                         aggfunc=lambda x: x, # <--- dont aggregate, just use conversion rate unchanged
                         fill_value='0')

# change multi-index into columns
summary.reset_index(inplace=True)

# flatten the columns
summary.columns = ['-'.join(col).strip() for col in summary.columns.values]
summary.columns = [col.replace('/', '') for col in summary.columns.values]
summary.columns = [col.replace('-', '') for col in summary.columns.values]

# In[]

# now attach the conversion summary to the wards geo shapefile

app_wards_geo_summary = pd.merge(app_wards_geo, summary,
                                 how='inner',
                                 left_on=['wd16cd'],
                                 right_on=['WD18CD'],
                                 indicator=True)

app_wards_geo_summary.drop(['_merge'], axis=1, inplace=True)

# In[]

number_cols = [
             'ApplicationsSchool1718',
             'ApplicationsCLL1718',
             'ApplicationsApp1718',
             'ApplicationsSchool1819',
             'ApplicationsCLL1819',
             'ApplicationsApp1819',
             'EnrolledSchool1718',
             'EnrolledCLL1718',
             'EnrolledApp1718',
             'EnrolledSchool1819',
             'EnrolledCLL1819',
             'EnrolledApp1819' ]

# force nice clean strings!
app_wards_geo_summary[number_cols] = app_wards_geo_summary[number_cols].astype(int).astype(str)

# In[]

# Create a (brittle) HTML template.
# This template will be injected with values from the ward dataframes.
app_wards_geo_summary['display_panel'] = '<style>' + \
                                                        'table, td, th {  ' + \
                                                        '  text-align: center;' + \
                                                        '}' + \
                                                        'table {' + \
                                                        '  border-collapse: collapse;' + \
                                                        '  width: 100%;' + \
                                                        '}' + \
                                                        'th, td {' + \
                                                        '  padding: 3px;' + \
                                                        '}' + \
                                                        '</style>' + \
                                         '<table>' + \
                                         '<caption style="font-weight: bold; font-size: 120%;">' + app_wards_geo_summary['wd16nm'] + '</caption>' + \
                                            '<tr> ' + \
                                                '<th>        </td> ' + \
                                                '<th> School  Leavers   </td> ' + \
                                                '<th> Career  Ladder    </td> ' + \
                                         '</tr>' + \
                                         ' <tr> ' + \
                                            '<td>17/18</td> ' + \
                                            '<td  style="color: darkgray;">  <div style="font-weight: bold; color:black;font-size: 120%;">' + app_wards_geo_summary['ConvSchool1718']  + '</div>  ' + app_wards_geo_summary['EnrolledSchool1718']  + '&nbsp;/&nbsp;' + app_wards_geo_summary['ApplicationsSchool1718'] + ' </td>' + \
                                            '<td  style="color: darkgray;">  <div style="font-weight: bold; color:black;font-size: 120%;">' + app_wards_geo_summary['ConvCLL1718']     + '</div>  ' + app_wards_geo_summary['EnrolledCLL1718']     + '&nbsp;/&nbsp;' + app_wards_geo_summary['ApplicationsCLL1718']    + ' </td>' + \
                                         '</tr>' + \
                                            '<td>18/19</td> ' + \
                                            '<td style="color: darkgray;">  <div style="font-weight: bold; color:black;font-size: 120%;">' + app_wards_geo_summary['ConvSchool1819']  + '</div>  ' + app_wards_geo_summary['EnrolledSchool1819']  + '&nbsp;/&nbsp;' + app_wards_geo_summary['ApplicationsSchool1819'] + ' </td>' + \
                                            '<td style="color: darkgray;">  <div style="font-weight: bold; color:black;font-size: 120%;">' + app_wards_geo_summary['ConvCLL1819']     + '</div>  ' + app_wards_geo_summary['EnrolledCLL1819']     + '&nbsp;/&nbsp;' + app_wards_geo_summary['ApplicationsCLL1819']    + ' </td>' + \
                                         '</tr>' + \
                                         '</table>'

# In[]

# Some Pandas magic...
ward_conversion_overall = fixed_applications.groupby(by=['WD18CD', 'Ward'], as_index=False) \
                                            .agg({'Applications': np.sum,
                                                  'Enrolled':     np.sum  })

ward_conversion_overall['conversion'] = ward_conversion_overall['Enrolled'] / ward_conversion_overall['Applications'] * 100

# ward_conversion_overall.query('conversion != conversion')

        # WD18CD       Ward  Applications  Enrolled  conversion
# 34   E05002461  E05002461             0         0         NaN
# 51   E05003300  E05003300             0         0         NaN
# 86   E05006917  E05006917             0         0         NaN
# 100  E05007054  E05007054             0         0         NaN
# 102  E05007060  E05007060             0         0         NaN
# 105  E05008521  E05008521             0         0         NaN
# 146  E05010102  E05010102             0         0         NaN
# 192  E05010674  E05010674             0         0         NaN

ward_conversion_overall['conversion'] = ward_conversion_overall['conversion'].astype(int)

# In[]

ward_conversion_by_year = fixed_applications.groupby(by=['WD18CD', 'Ward', 'Year'], as_index=False) \
                    .agg({'Applications': np.sum,
                          'Enrolled': np.sum  })

# application conversion for year: 17/18

ward_conversion_1718 = ward_conversion_by_year.query('Year == "17/18"')
ward_conversion_1718.reset_index(drop=True, inplace=True)
ward_conversion_1718['conversion'] = ward_conversion_1718['Enrolled'] / ward_conversion_1718['Applications'] * 100
ward_conversion_1718['conversion'] = ward_conversion_1718['conversion'].astype(int)

wards_1718 = ward_conversion_1718['WD18CD'].unique().tolist()
mask = app_wards_geo['wd16cd'].isin(wards_1718)
wards_geo_1718 = app_wards_geo[mask]

# application conversion for year: 18/19

ward_conversion_1819 = ward_conversion_by_year.query('Year == "18/19"')
ward_conversion_1819.reset_index(drop=True, inplace=True)
ward_conversion_1819['conversion'] = ward_conversion_1819['Enrolled'] / ward_conversion_1819['Applications'] * 100
ward_conversion_1819['conversion'] = ward_conversion_1819['conversion'].astype(int)

wards_1819 = ward_conversion_1819['WD18CD'].unique().tolist()
mask = app_wards_geo['wd16cd'].isin(wards_1819)
wards_geo_1819 = app_wards_geo[mask]

# In[]

student_ward_codes =  learners['osward'].unique().tolist()

mask              = uk_wards_geo['wd16cd'].isin(student_ward_codes)
student_wards_geo = uk_wards_geo[mask]

# In[7]:

start_lat = learners['lat'].mean()
start_lon = learners['long'].mean()

# blank base map
# m = DualMap(
m = folium.Map(
               location=[start_lat, start_lon],
                prefer_canvas=True,
               tiles=None
            )

# Normal OSM Layer
osm_base = folium.TileLayer(
               zoom_start=10,
               min_zoom=7,
               prefer_canvas=True,
               location=[start_lat, start_lon],
               name='Base Map',
                   tiles='OpenStreetMap'
                # tiles='CartoDB positron'
                # tiles='Stamen Terrain'
                )

# # transport layer
transport_layer = folium.TileLayer(
               zoom_start=7,
               min_zoom=3,
               prefer_canvas=True,
               location=[52.95, -1.5],
               name='Transport Map',
               attr='Open Street Maps',
               tiles='https://tile.thunderforest.com/transport/{z}/{x}/{y}.png?apikey=1ac0a1c84a184bbb80187821157dc0ff '
                )

osm_base.add_to(m)
transport_layer.add_to(m)

rh = folium.Marker(
            location=[52.9166, -1.4606],
            tooltip='RoundHouse',
            icon=folium.Icon(color='black', icon='graduation-cap', prefix='fa'),
            )

il = folium.Marker(
            location=[52.9716, -1.3123],
            tooltip='Ilkeston',
            icon=folium.Icon(color='black', icon='graduation-cap', prefix='fa'),
            )

jw = folium.Marker(
            location=[52.9257, -1.4819],
            tooltip='Joseph Wright',
            icon=folium.Icon(color='black', icon='graduation-cap', prefix='fa'),
            )

br = folium.Marker(
            location=[52.9570, -1.4255],
            tooltip='Broomfield',
            icon=folium.Icon(color='black', icon='graduation-cap', prefix='fa'),
            )

sj = folium.Marker(
            location=[52.9085 , -1.4696],
            tooltip='St James Centre',
            icon=folium.Icon(color='black', icon='graduation-cap', prefix='fa'),
            )

rh.add_to(m)
jw.add_to(m)
br.add_to(m)
il.add_to(m)
sj.add_to(m)

westknots   = folium.Marker(
                    location=[53.1216, -1.1923],
                    tooltip='West Nottinghamshire College',
                    icon=folium.Icon(color='purple', icon='university', prefix='fa'),
                    )

nott        = folium.Marker(
                    location=[52.9528, -1.1439],
                    tooltip='Nottingham College',
                    icon=folium.Icon(color='purple', icon='university', prefix='fa'),
                    )

bilborough  = folium.Marker(
                    location=[52.9667, -1.2350],
                    tooltip='Bilborough College',
                    icon=folium.Icon(color='purple', icon='university', prefix='fa'),
                    )

stephenson  = folium.Marker(
                    location=[52.7373, -1.3741],
                    tooltip='Stephenson College',
                    icon=folium.Icon(color='purple', icon='university', prefix='fa'),
                    )

burton     = folium.Marker(
                    location=[52.7998, -1.6308],
                    tooltip='Burton and South Derbyshire College',
                    icon=folium.Icon(color='purple', icon='university', prefix='fa'),
                    )

# Add various college markers
westknots.add_to(m)
nott.add_to(m)
bilborough.add_to(m)
stephenson.add_to(m)
burton.add_to(m)

# In[]

def ward_highlight(feature):
    return {
        'fillColor': 'yellow',
#         'fillOpacity': 0.2,
        'fillOpacity': 0.3
    }

def ward_boundary_style(feature):
    return {
        'fillColor': 'blue',
        'fillOpacity': 0.0,
        'weight' : 3,
        'opacity': 0.5, # line opacity
        # 'color': 'white'
        'color': 'blue'
    }

def app_ward_boundary_style(feature):
    return {
        'fillColor': 'black',
        'fillOpacity': 0.0,
        'weight' : 3,
        'opacity': 0.2, # line opacity
        # 'color': 'white'
        'color': 'black'
    }

# In[]

student_wards_layer = folium.GeoJson(
                        student_wards_geo,
                        name = 'Show Student Wards',
                        tooltip = folium.GeoJsonTooltip(
                                                        # fields=['ward_display_name'],
                                                        fields=['wd16nm'],
                                                        aliases=['Ward'],
                                                        sticky=True, # follow mouse?
                                                        labels=False, # show aliases?
                                                        opacity=0.7
                        ),
                        style_function = ward_boundary_style,
                        highlight_function = ward_highlight
                    )

# student_wards_layer.add_to(m)

# In[]

# nice tips
#   https://nbviewer.jupyter.org/github/jtbaker/folium/blob/geojsonmarker/examples/GeoJsonMarkersandTooltips.ipynb
#   https://nbviewer.jupyter.org/github/python-visualization/folium/blob/master/examples/Colormaps.ipynb

def add_choropleth(geo_data, data, fill_color, name, show):
    new_layer = folium.Choropleth(
                                  name=name,
                                  geo_data=geo_data,
                                  key_on='feature.properties.wd16cd',
                                  data=data,
                                  columns=['WD18CD', 'conversion'],
                                  # bins=5,
                                  bins=[0,20,40,60,80,100],
                                  fill_color=fill_color,
                                  fill_opacity=0.6,
                                  line_opacity=0.6,
                                  overlay=True,
                                  show=show,
                                  highlight=False,
                                  legend_name='Conversion %'
                                      )
    new_layer.add_to(m)

add_choropleth(app_wards_geo,  ward_conversion_overall, 'YlOrRd', 'Conversion Rate - Overall', True)
add_choropleth(wards_geo_1718, ward_conversion_1718,    'Blues',  'Conversion Rate - 17/18',   False)
add_choropleth(wards_geo_1819, ward_conversion_1819,    'Greens', 'Conversion Rate - 18/19',   False)


# In[]

app_layer = folium.FeatureGroup(name = 'Show Ward Summary')

for idx, row in app_wards_geo_summary.iterrows():
    this_ward = app_wards_geo_summary.iloc[idx:idx+1, :]

    application_ward = folium.GeoJson(
                            this_ward,
                            name = this_ward['wd16nm'],
                            overlay=True,
                            control=False,
                            style_function = app_ward_boundary_style,
                            highlight_function = None
                        )

    popup = folium.Popup(html=row['display_panel'])
    popup.add_to(application_ward)

    application_ward.add_to(app_layer)

app_layer.add_to(m)

# In[]

# show learner numbers as a heatmap

coords_list = list(zip(learners['lat'], learners['long']))

heatmap = HeatMap(coords_list,
                    name='Show Heatmap',
                    overlay=True,
                    control=True,
                    radius=14,
                    # blur=10,
                    show=False)

m.add_child(heatmap)

# In[]

# Add layer control
folium.LayerControl(collapsed=False).add_to(m)

# Create HTML file
m.save('output/ilkeston-conversion-rates.html')

# In[]
