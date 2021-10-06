#
# Example R program
#


library(RPostgreSQL)

drv <- dbDriver("PostgreSQL")

## don't have a database to connect to
#
# # open the connection using user, passsword, etc., as
# con <- dbConnect(drv, dbname = "postgres")
#
# df <- dbGetQuery(con, statement = paste(
#                          "SELECT itemCode, itemCost, itemProfit",
#                          "FROM sales",
#                          "SORT BY itemName"));
#
# # Run an SQL statement by creating first a resultSet object
# rs <- dbSendQuery(con, statement = paste(
#                          "SELECT itemCode, itemCost, itemProfit",
#                          "FROM sales",
#                          "SORT BY itemName"));
#
# # we now fetch records from the resultSet into a data.frame
# df <- fetch(rs, n = -1) # extract all rows
#
# dim(df)
