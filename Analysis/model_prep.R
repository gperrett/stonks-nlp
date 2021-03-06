library(tidyverse)
library(ggridges)
options(mc.cores = parallel::detectCores())
theme_set(theme_minimal())
set.seed(44)

setwd("~/stonks-nlp/")
setwd("~/Dropbox/Data/Projects/stonks-nlp/")

# read the data containing the posts, scores, and tickers
posts_df <- read_csv("Analysis/scored_named_posts.csv", 
                     col_types = cols(date = col_datetime(format = "%Y-%m-%d %H:%M:%S")))

# munge the data to long format
posts_df <- posts_df %>% 
  separate_rows("all_found_companies", sep = " ") %>% 
  select(post_id = id, date, ticker = all_found_companies, 
         sentiment_score, n_comments = comms_num, url) %>% 
  mutate(date = as.Date(date))


# EDA ---------------------------------------------------------------------

# plot the distributions of the top tickers 
tmp <- posts_df %>% 
  count(ticker) %>% 
  slice_max(n, prop = 0.05) %>%
  left_join(posts_df, by = 'ticker') %>%
  group_by(ticker) %>% 
  mutate(mean_score = mean(sentiment_score))
tmp %>% 
  mutate(ticker = factor(ticker, levels = unique(tmp$ticker[order(tmp$mean_score)]))) %>% 
  ggplot(aes(x = sentiment_score, y = ticker, fill = ticker)) +
  geom_density_ridges(alpha = 0.9, color = 'grey40') +
  labs(title = "Distribution of sentiment scores of top 5% mentioned securities in r/wallstreetbets",
       caption = paste0(range(posts_df$date), collapse = " to "),
       x = "Sentiment score (VADER)",
       y = NULL) +
  theme(legend.position = 'none')
rm(tmp)
ggsave("Plots/scores_by_top_mentions.png",
       width = 20,
       height = 16,
       units = 'cm')


# add in sample of tickers that were not found ----------------------------

tickers_searched_for <- read_csv("Data/ticker_names.csv")
tickers_not_found <- anti_join(tickers_searched_for, distinct(posts_df[, 'ticker']))

# # create an equal sized sample of tickers not found in the reddit data
# counter_sample_df <- slice_sample(posts_df, n = nrow(posts_df), replace = TRUE) %>% 
#   mutate(ticker = sample(tickers_not_found$ticker, size = nrow(posts_df), replace = TRUE),
#          sentiment_score = NA,
#          n_comments = NA) %>% 
#   select(date, ticker, sentiment_score, n_comments)

# stack the dataframe with posts_df and change sentiment score to a categorical
# based on the absoluete value of sentiment
# final_df <- counter_sample_df %>% 
#   bind_rows(posts_df %>% select(date, ticker, sentiment_score, n_comments))

# read in the robinhood usage data ----------------------------------------
final_df <- posts_df %>% select(date, ticker)
# get the names of the csvs that match the tickers in posts_df 
files_to_read <- list.files("Data/Robinhood_usage") %>%
  enframe() %>% 
  mutate(ticker = str_remove(value, ".csv")) %>% 
  right_join(final_df[, 'ticker']) %>% 
  pull(value) %>% 
  unique()

# read in the data into one dataframe
RH_usage <- map_dfr(files_to_read, function(filename){
  df <- read_csv(paste0("Data/Robinhood_usage/", filename))
  df$ticker <- str_remove(filename, ".csv")
  return(df)
})

# capture only the usage at the end of the day
RH_usage <- RH_usage %>% 
  mutate(date = as.Date(timestamp)) %>% 
  group_by(ticker, date) %>% 
  filter(timestamp == max(timestamp)) %>% 
  ungroup() %>% 
  select(-timestamp)

# overall RH usage
RH_usage %>% 
  group_by(date) %>% 
  summarize(n = sum(users_holding)) %>% 
  ggplot(aes(x = date, y = n)) + 
  geom_line(color = 'grey10') +
  geom_area(alpha = 0.8, fill = 'grey40') + #'#487861') +
  geom_vline(xintercept = as.Date('2020-02-19')) +
  annotate(geom = 'text', x = as.Date('2020-02-15'), y = 2.0e+7,
           label = "Market peak: 2/19", hjust = 1) +
  geom_vline(xintercept = as.Date('2020-03-20')) +
  annotate(geom = 'text', x = as.Date('2020-03-26'), y = 5.0e+6, color = 'white',
           label = "NY stay-at-\nhome order: \n3/20", hjust = 0) +
  geom_vline(xintercept = as.Date('2020-03-23')) +
  annotate(geom = 'text', x = as.Date('2020-03-28'), y = 1.3e+7, color = 'white',
           label = "Market\nbottom: 3/23", hjust = 0) +
  scale_y_continuous(labels = scales::label_number(scale = 1 / 1e6, suffix = "M")) +
  labs(title = "Total unique securities owned by Robinhood users",
       subtitle = 'Data only includes the top ~700 securities',
       x = NULL,
       y = NULL)
ggsave("Plots/RH_usage.png",
       width = 20,
       height = 12,
       units = 'cm')


# identify wsb status
final_df <- final_df %>% mutate(wsb = 1)
tickers <- final_df %>% select(ticker)
dates <- final_df %>% select(date)

final_df <- crossing(tickers, dates) %>% left_join(final_df)
final_df$day <- weekdays(final_df$date)
final_df <- final_df %>% distinct()

# merge back with posts_df
final_df <- final_df %>% 
  left_join(RH_usage, by = c("date", "ticker")) 

final_df <- final_df %>% mutate(wsb = if_else(is.na(wsb), 0, 1))

# remove weekends
final_df <- final_df %>% filter(day != "Sunday", day != "Saturday")

# save dataset
write_csv(final_df, 'Analysis/cleaned_data.csv')
