# Load mwstr functions:
# source("~/uomShare/wergStaff/ChrisW/mwstr_v13/mwstr_network_functions.R")
library(terra)
library(sf)
library(igraph)
library(DBI)

tiff_dir <- "~/uomShare/wergStaff/ChrisW/mwstr_v13/"

# Read in TIFF file:
veg_tiff <- "~/uomShare/wergProj/W12 - Revegetation/RMIT project/predicted_masked.tif"

# Connect to mwstr database:
mwstr <- DBI::dbConnect(RSQLite::SQLite(), 
                        "~/uomShare/wergStaff/ChrisW/mwstr_v13/mwstr_v1.3.1.gpkg")


subcs <- sf::st_read(mwstr, 
                     query = paste0("SELECT subcs.reach, subcs.site, subcs.nextds, subcs.nus, ",
                                    "subcs.agg_order, subc_env.d2ol_pp, subcs.geom, subcs.tot_length_m FROM subcs ",
                                    "JOIN subc_env ON subcs.site = subc_env.site ",
                                    "ORDER BY subcs.agg_order, subcs.nus, subcs.reach;"))


sf::st_crs(subcs) <- 7855 # Set CRS to EPSG:7855 (GDA2020 / MGA zone 55)
subcs_t <- terra::vect(subcs) # Convert to terra vector
sf::st_geometry(subcs) <- NULL # Remove geometry from subcs to save memory
subcs_ig <- apply(subcs[c("site","nextds")], 2, as.character) # Create graph dataframe from subcs
subcs_ig <- igraph::graph_from_data_frame(subcs_ig) # Convert to igraph object
rm(subcs) # Remove subcs to save memory

subc_pps <- sf::st_read(mwstr, query = "SELECT * FROM subc_pps;") # Read in subc_pps table
subc_pps <- subc_pps[match(subcs_t$site, subc_pps$site),] # Reorder subc_pps to match subcs_t
subc_pps <- terra::vect(subc_pps) # Convert to terra vector

# Rasterize stream network tiffs:
r_site <- terra::rast(paste0(tiff_dir, "/r_site.tif"))
d2str <- terra::rast(paste0(tiff_dir, "/r_d2str.tif"))
d2ol <- terra::rast(paste0(tiff_dir, "/r_d2ol.tif"))

# Cropping vegq to match the extent of r_site:
vegq <- terra::rast(veg_tiff)
if(terra::crs(r_site) != terra::crs(vegq)) {
  vegq <- project(vegq, terra::crs(r_site))
}
vegq_cropped <- terra::crop(vegq, r_site)
vegq_cor <- resample(vegq_cropped, r_site, method = "bilinear")
veg_4 <- c(r_site, d2str, d2ol, vegq_cor)
names(veg_4)[1:3] <- c("site","d2str","d2ol")
prepared_vq_list <- list(subcs = subcs_t, subcs_ig = subcs_ig, 
                         subc_pps = subc_pps, veg_4 = veg_4)
gc() 
rm(r_site, d2str, d2ol)
