#
# Example R program
#

print(packrat::status())

library("stringr")
x <- c("why", "video", "cross", "extra", "deal", "authority")
str_length(x)
str_c(x, collapse = ", ")
str_sub(x, 1, 2)
