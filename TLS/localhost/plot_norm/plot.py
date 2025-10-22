import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.ticker import ScalarFormatter
from matplotlib.ticker import FuncFormatter
import numpy as np
import os

# move to the directory where the script is located
base_directory = os.path.dirname(os.path.realpath(__file__))
os.chdir(base_directory)

pi5=False

# read the CSV files
df = pd.read_csv(f"../results{'_pi5' if pi5 else ''}/results_norm.csv")
df['cat'] = df['cat'].replace(2, 1) # cat 2 = cat 1
df = df.sort_values(by=['cat', '0ms'], ascending=[True, False]).reset_index(drop=True)
df1 = df[df["cat"].isin([0, 1])].iloc[:, 1:]
df2 = df[df["cat"].isin([3, 5])].iloc[:, 1:]

# insert empty rows as horizontal spacers
empty_row = pd.DataFrame([['', '0', '0', '0', '0']], columns=df1.columns)
insert_idx = 3
insert_repetitions = len(df2) - len(df1)
rows_to_insert = pd.concat([empty_row]*insert_repetitions, ignore_index=True)
df1 = pd.concat([df1.iloc[:insert_idx], rows_to_insert, df1.iloc[insert_idx:]]).reset_index(drop=True)


# set latex font
plt.rcParams.update({
    "pgf.texsystem": "pdflatex",
    "font.family": "serif",
})

# set up the figure with two subplots
fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 9)) # width, height

# define the latency columns and colors
cols = ['0ms', '2ms', '20ms', '120ms']
colors = ['#6c8ebf', '#82b366', '#d79b00', '#b85450']

# category separation indices for demarcation lines over the plot
idx_cat_sep = [2, 16]
idx_cat_end = [31, 31]
separator_rows = [insert_repetitions, 0] # number of separator rows in each subplot
cat_name_left  = [r'\textbf{Classical}',
                  r'\textbf{NIST Category 3}']
cat_name_right = [r'\textbf{NIST Category 1 and 2}',
                  r'\textbf{NIST Category 5}']

def plot_histogram(df, ax, title):

    n_algs = len(df)
    positions = np.arange(n_algs)
    bar_width = 0.2

    if (ax==ax1):
        subplot_idx = 0
    else:
        subplot_idx = 1
    
    # create bars
    for i, (col, color) in enumerate(zip(cols, colors)):
        offset = (i - 1.5) * bar_width
        for j in range(n_algs):
            # classical algorithms are more transparent
            if (subplot_idx==0 and j < 3):
                alpha = 0.5
            else:
                alpha = 1
            # bar properties
            ax.bar(
                positions[j] + offset,
                df[col].iloc[j],
                bar_width,
                label=col if j == 0 else "",
                color=color,
                alpha=alpha,
            )
    
    # Customize the plot
    ax.set_ylabel('Normalized TLS Handshakes')
    ax.set_title(title)
    ax.set_xticks(positions)
    ax.set_xticklabels(df['sig'], rotation=45, ha='right')
    # ax.set_yscale('log')
    # not log
    ax.set_yscale('linear')
    # 1000 instead of 10^3 to make latex happy
    # ax.yaxis.set_major_formatter(ScalarFormatter())


    # ax.set_ylim(0, 24)

    # diifernt ylim for both subplots
    ymax_hard = 0
    if (subplot_idx==0):
        ymax_hard = 55 if pi5 else 20
    else:
        ymax_hard = 65 if pi5 else 25
    
    ymax_hard_max = 65 if pi5 else 25
    
    ax.set_ylim(0, ymax_hard)
    
    ax.grid(True, alpha=0.3)
    ax.grid(True, which='minor', linestyle=':', alpha=0.3)

    # Add group lines and labels above the bars
    y_max = ymax_hard * 1.05  # a bit above the top
    dash_height = 0.006 * ymax_hard_max  # length of the vertical dash
    text_offset = 0.01 * ymax_hard_max  # vertical offset for the text

    LW = 1.5

    # left group
    x_start1 = positions[0] - 0.3
    x_end1 = positions[idx_cat_sep[subplot_idx]] + 0.3
    ax.plot([x_start1, x_end1], [y_max, y_max], color='grey', lw=LW, clip_on=False)
    ax.plot([x_start1, x_start1], [y_max - dash_height, y_max + dash_height], color='grey', lw=LW, clip_on=False)
    ax.plot([x_end1, x_end1], [y_max - dash_height, y_max + dash_height], color='grey', lw=LW, clip_on=False)
    ax.text((x_start1 + x_end1) / 2, y_max + text_offset, cat_name_left[subplot_idx], ha='center', va='bottom', fontsize=12)

    # right group
    x_start2 = positions[idx_cat_sep[subplot_idx]+separator_rows[subplot_idx]+1] - 0.3
    x_end2 = positions[idx_cat_end[subplot_idx]] + 0.3
    ax.plot([x_start2, x_end2], [y_max, y_max], color='grey', lw=LW, clip_on=False)
    ax.plot([x_start2, x_start2], [y_max - dash_height, y_max + dash_height], color='grey', lw=LW, clip_on=False)
    ax.plot([x_end2, x_end2], [y_max - dash_height, y_max + dash_height], color='grey', lw=LW, clip_on=False)
    ax.text((x_start2 + x_end2) / 2, y_max + text_offset, cat_name_right[subplot_idx], ha='center', va='bottom', fontsize=12)
    
    # legend only on one subplot
    if (subplot_idx>=0): 
        ax.legend(
            fontsize=9,           # smaller text
            handlelength=1.0,     # shorter legend lines
            handletextpad=0.3,    # less space between handle and text
            borderpad=0.3,        # less padding inside the legend box
            loc='best'
        )
        # legend handles to 0 transparency
        for lh in ax.get_legend().legend_handles:
            lh.set_alpha(1)

# plot both histograms
plot_histogram(df1, ax1, r'')
plot_histogram(df2, ax2, r'')

# ax1.yaxis.set_major_formatter(FuncFormatter(lambda x, _: f"{int(x)}"))
# ax2.yaxis.set_major_formatter(FuncFormatter(lambda x, _: f"{int(x)}"))

# adjust layout to prevent overlap
plt.tight_layout()

# add vertical space between subplots
# plt.subplots_adjust(hspace=0.3)

# display the plot or export
exporting = True
exporting = False

if(not exporting):
    plt.show()

if (exporting):
    plt.savefig(f"tls{'_pi5' if pi5 else ''}_norm.pgf")