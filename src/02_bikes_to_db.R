# This program is free software.
# You should have received a copy of the GNU General Public License
# along with this program (file COPYING). If not, see <http://www.gnu.org/licenses/>.

# MOVE BIKES DATA TO DATABASE

# load libraries ####
# use 00_install_R_packages.R for installing missing packages
sapply(c("dplyr", "DBI", "RSQLite", "tidyr", "chron", "lubridate"), 
       require, character.only = TRUE)

file <- "data/raw/Fahrradzaehlstellen-Stundenwerte.csv"

bikes <- 
  read.csv(file, sep = ";", na.strings = "technische Störung") %>%
  # renaming columns
  rename(hour = X) %>%
  rename(date = Datum) %>%
	rename(weather = Wetter) %>% 
	rename(temperature = Temperatur...C.) %>% 
	rename(windspeed = Windstärke..km.h.) %>% 
  # wide to long format
  gather(location, count, -date, -hour, -weather, -temperature, -windspeed) %>%
	mutate(date = as.character(dmy(date))) %>% 
	mutate(year = as.integer(year(date))) %>%
  mutate(month = as.integer(month(date))) %>%
  mutate(day = as.integer(day(date))) %>%
  # subtract 1 because sqlite counts Sun = 0 but lubridate Sun = 1
  mutate(weekday = wday(date, label = F) - 1) %>%
  mutate(weekend = is.weekend(date)) %>% 
  mutate(hour = as.integer(substring(hour, 1, 2))) %>% 
	mutate(vehicle = "bike")

# write 'bikes' to SQLite database
dir.create("data/database", showWarnings = F)
con <- dbConnect(SQLite(), dbname = "data/database/traffic_data.sqlite")
dbWriteTable(con, "bikes", bikes, row.names = F, overwrite = T)

dbExecute(con, "CREATE INDEX timestamp_bikes on bikes (date, hour)")
dbExecute(con, "CREATE INDEX year_month_day_bikes on bikes (year, month, day, hour)")

# TODO: make the weather data an own table
# add the same weather to cars table
# cars <- dbGetQuery(conn = con, "SELECT location, count, date, hour, vehicle FROM cars")
# 
# weather_from_bikes <- 
# 	bikes %>% 
# 	select(date, hour, weather, windspeed, temperature) %>% 
# 	filter(weather != "")
# 
# cars <- 
# 	cars %>%
# 	inner_join(., weather_from_bikes, by = c("date", "hour"))
# 
# dbWriteTable(con, "cars", cars, row.names = F, overwrite = T)

# for better performance, DB is read-only in shiny-app
dbExecute(con, "PRAGMA synchronous=OFF; PRAGMA journal_mode=OFF;")

dbDisconnect(con)
