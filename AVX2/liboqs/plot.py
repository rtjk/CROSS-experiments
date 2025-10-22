import pandas as pd
import matplotlib.pyplot as plt
import os
from adjustText import adjust_text
from matplotlib.ticker import LogFormatter

# move to the directory where the script is located
base_directory = os.path.dirname(os.path.realpath(__file__))
os.chdir(base_directory)

# load CSV
df = pd.read_csv("data.csv")

plt.figure(figsize=(9, 6)) # width, height

# set latex font
plt.rcParams.update({
    "pgf.texsystem": "pdflatex",
    "font.family": "serif",
})

texts = []  # collect text objects for adjustText

for fam, group in df.groupby("fam"):
    plt.scatter(group["s"], group["v"], label=fam)
    for _, row in group.iterrows():
        texts.append(plt.text(row["s"], row["v"], row["sig"], fontsize=8, alpha=0.8))

plt.xscale("log")
plt.yscale("log")
# plt.xlabel(r'\textbf{Signing cycles}')
# plt.ylabel(r'\textbf{Verification cycles}')
plt.xlabel("Signing cycles")
plt.ylabel("Verification cycles")
# plt.legend(loc='lower right')
plt.legend(borderpad=0.3)
plt.grid(True, which="both", linewidth=0.3, alpha=0.4)

# adjust text labels
adjust_text(texts, only_move={'points':'y', 'texts':'xy'}, 
            arrowprops=dict(arrowstyle='->', color='gray', lw=0.5))

# Use plain numbers instead of 10^x
plt.gca().xaxis.set_major_formatter(LogFormatter(base=10, labelOnlyBase=False))
plt.gca().yaxis.set_major_formatter(LogFormatter(base=10, labelOnlyBase=False))

plt.tight_layout()

# display the plot or export
exporting = False
exporting = True

if(not exporting):
    plt.show()

if (exporting):
    plt.savefig('liboqs.pgf')
