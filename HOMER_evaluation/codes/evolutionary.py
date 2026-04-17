# Import libraries
import pandas as pd
import os

HOMER_MOTIF_SUFFIX = "/Homer"


def short_motif_label(name):
    """Strip HOMER's trailing database tag for display (e.g. plots, CSV); optional."""
    if isinstance(name, str) and name.endswith(HOMER_MOTIF_SUFFIX):
        return name[: -len(HOMER_MOTIF_SUFFIX)]
    return name


def parse_known_results(filepath, top_n=20):
    """
    Parse the knownResults.txt file and return the top N TFs.
    Args:
        filepath: The path to the knownResults.txt file.
        top_n: The number of top TFs to return.
    Returns:
        A list of the top N TFs.
    """
    print(f"\nFirst 10 lines of {filepath}:")
    with open(filepath, 'r') as f:
        for i in range(10):
            print(f.readline().rstrip())

    df = pd.read_csv(filepath, sep='\t')
    df = df.copy()

    df['Log P-value'] = pd.to_numeric(df['Log P-value'], errors='coerce')
    df = df.sort_values(by='Log P-value', ascending=True)

    return df.head(top_n)

def compare_tfs(table1, table2, table3, name_list):
    """
    Compare the top N TFs of two peak sets, need list and two original table.
    for each TF in the combined name list, and the for shared, huamn_specific, mouse_specific, and mouse_specific, if TF in the corresponding table, add yes in the final output table.
    Args:
        table1: The original table of the first peak set.
        table2: The original table of the second peak set.
        table3: The original table of the third peak set.
        name_list: The name list of the three peak sets.
    Returns:
        A list of the comparison results.
    """
    # create a new dataframe to store the comparison results

    total_name_list = name_list["shared"] + name_list["human_specific"] + name_list["mouse_specific"]
    # empty table with known row length and deflaut value ""
    comparison_results = pd.DataFrame(columns=['TF', 'shared', 'human_specific', 'mouse_specific'], index=range(len(total_name_list)))
    comparison_results['TF'] = total_name_list
    comparison_results['shared'] = ''
    comparison_results['human_specific'] = ''
    comparison_results['mouse_specific'] = ''
    names1 = set(table1['Motif Name'])
    names2 = set(table2['Motif Name'])
    names3 = set(table3['Motif Name'])
    for idx, name in enumerate(total_name_list):
        if name in names1:
            comparison_results.at[idx, 'shared'] = '✔'
        if name in names2:
            comparison_results.at[idx, 'human_specific'] = '✔'
        if name in names3:
            comparison_results.at[idx, 'mouse_specific'] = '✔'
    # Shorter TF labels: full strings stay in HOMER files; matching above used those.
    comparison_results['TF'] = comparison_results['TF'].map(short_motif_label)
    return comparison_results


if __name__ == "__main__":
   # Define motif result file paths for each peak set
   base_dir = "/ocean/projects/bio230007p/wli27/repo/looking_spleentacular/HOMER/homer_results"
   peak_sets = {
      "shared": os.path.join(base_dir, "shared_peaks/knownMotifs.txt"),
      "human_specific": os.path.join(base_dir, "human_specific/knownMotifs.txt"),
      "mouse_specific": os.path.join(base_dir, "mouse_specific/knownMotifs.txt"),
   }

   # Parse top 20 TFs for each peak set
   top_tfs_shared = parse_known_results(peak_sets["shared"], 20)
   top_tfs_human_specific = parse_known_results(peak_sets["human_specific"], 20)
   top_tfs_mouse_specific = parse_known_results(peak_sets["mouse_specific"], 20)

   def _motifs_for_display(df):
      out = df.copy()
      out['Motif Name'] = out['Motif Name'].map(short_motif_label)
      return out

   # Print top TFs with short motif labels (no trailing /Homer)
   print(_motifs_for_display(top_tfs_shared))
   print(_motifs_for_display(top_tfs_human_specific))
   print(_motifs_for_display(top_tfs_mouse_specific))

   # Full HOMER IDs for set membership; display labels optional for debug
   total_name_list = {
      "shared": top_tfs_shared['Motif Name'].tolist(),
      "human_specific": top_tfs_human_specific['Motif Name'].tolist(),
      "mouse_specific": top_tfs_mouse_specific['Motif Name'].tolist(),
   }
   print({k: list(map(short_motif_label, v)) for k, v in total_name_list.items()})

   # compare the top N TFs of three peak sets, need list and three original table
   comparison_results = compare_tfs(top_tfs_shared, top_tfs_human_specific, top_tfs_mouse_specific, total_name_list)
   comparison_results.to_csv('comparison_results.csv', index=False)
   print(comparison_results)




   