library(tidyverse)
library(readr)
bumble.dom <- read_csv("BumbleBees experiment-table.csv")

# This assumes the columns are renamed to the format <region letter>-dominance, 
# e.g. c-hi, p-low, o-mid
bumble.dom %>%
    select(!run) %>%
    summarise(across(everything(), list(mean = mean, sd = sd))) %>%
    pivot_longer(everything(),
        names_to=c("dom", ".value") ,
        names_pattern = "([cpo])-(.*)"    
    ) 
