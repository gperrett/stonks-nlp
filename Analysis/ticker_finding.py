import pandas as pd
import datetime as dt
import os
import numpy as np
#import tidytext
from nltk.tokenize import word_tokenize
import matplotlib.pyplot as plt
import seaborn as sns

# set working directory
os.chdir("/home/joemarlo/Dropbox/Data/Projects/stonks-nlp")
#os.chdir("/Users/joemarlo/Dropbox/Data/Projects/stonks-nlp")

# read in the scored posts
posts_df = pd.read_csv("Analysis/scored_posts.csv")

# read in the tickers df and make lower case
tickers_df = pd.read_csv("Data/tickers.csv")
tickers_df.ticker = tickers_df.ticker.str.lower()
tickers_df.name = tickers_df.name.str.lower()

# first tokenize the words
tokens = [word_tokenize(body) for body in posts_df.body]

# need to parse out LLC etc; first figure out which are most frequent
# tokenize and count most frequent tokens in company names
names_tokens = [word_tokenize(name) for name in tickers_df.name]
flat_names_tokens = [item for sublist in names_tokens for item in sublist]
pd.Series(flat_names_tokens).value_counts()[0:50]
del flat_names_tokens

words_to_remove = [
'corp',
'inc',
'.',
'ltd',
'holdings',
'group',
'co',
'trust',
'financial',
'lp',
'plc',
'international',
'pharmaceuticals',
'partners',
'technologies',
'bancorp',
'capital',
'therapeutics',
'the',
'energy',
'tech'
]

# remove the words
clean_names = []
for sentence in names_tokens:
    clean_tokens = [word for word in sentence if word not in words_to_remove]
    clean_names.append(' '.join(clean_tokens))

# need to remove $ as sometimes those are before a ticker

# TODO: issue is that some companies are multiple words_to_remove
# need some sort of ngram approach
# check to see if word is in the ticker list
ticker_boolean = []
for sentence in tokens:
    for word in sentence:
        ticker_boolean.append(word.lower() in tickers_df.ticker)

name_boolean = []
for sentence in tokens:
    for word in sentence:
        name_boolean.append(word.lower() in tickers_df.name)
