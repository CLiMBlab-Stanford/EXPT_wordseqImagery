import pandas as pd
import os

# read all csv files in the directory

for files in os.listdir():
    if files.endswith(".tsv"):
        print (files)
        df = pd.read_csv(files, sep="\t")
        # change column name onset_s to onset
        df = df.rename(columns={"onset_s": "onset"})

        #delete rows where event is pre_fix
        df = df[df["event"] != "pre_fix"]
        df = df[df["event"] != "covert"]
        df = df[df["trial"] != 2]
        df = df[df["trial"] != 3]

        df["event"] = df["event"].replace('listen','imagine')

        #new column called duration, and is difference between this line and the next line
        df["duration"] = df["onset"].shift(-1) - df["onset"]
        #add duration for last cell as 10
        df.loc[df.index[-1], "duration"] = 10
        #keep only the columns of interest
        df = df[[ "onset", "duration", "event"]]

        df = df.rename(columns={"event": "trial_type"})
        new_filename = files.replace("events", "wordseqcovert")
        #save the cleaned dataframe to replace tsv file
        df.to_csv(f'cleaned/{new_filename}', sep="\t", index=False)
  
