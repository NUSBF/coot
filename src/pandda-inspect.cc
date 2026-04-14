
#include <optional>
#include <string>
#include <map>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <unordered_map>

#include "graphics-info.h"

class pandda_event_store_t {

   public:
   std::map<std::string, std::unordered_map<std::string, std::string> > events;

   void add_tagged_event(const std::string &dtag, const std::string &key, const std::string &data) {

      std::map<std::string, std::unordered_map<std::string, std::string> >::iterator it;
      it = events.find(dtag);
      if (it != events.end()) {
         std::cout << "found dtag: " << dtag << " in events map" << " for key: " << key << " data:" << data << std::endl;
         auto &event = it->second;
         event[key] = data;
      } else {
         std::cout << "failed to find dtag: " << dtag << " in events map" << " for key: " << key << " data: " << data << std::endl;
         std::unordered_map<std::string, std::string> u;
         u[key] = data;
         events[dtag] = u;
      }
   }

   std::optional<std::string> get_data(const std::string &dtag, const std::string &key) const {

      std::cout << "events.size() " << events.size() << std::endl;

      std::map<std::string, std::unordered_map<std::string, std::string> >::const_iterator it;
      it = events.find(dtag);
      if (it != events.end()) {
         auto &event = it->second;
         std::unordered_map<std::string, std::string>::const_iterator itm;
         itm = event.find(key);
         if (itm == event.end()) {
            std::cout << "Fail B" << std::endl;
            return std::nullopt;
         } else {
            return itm->second;
         }
      } else {
         std::cout << "Fail A" << std::endl;
         return std::nullopt;
      }
   }
};

pandda_event_store_t parse_pandda_analyse_events(const std::string &file_name) {

   pandda_event_store_t pes;
   std::filesystem::path p(file_name);
   if (std::filesystem::exists(p)) {
      std::ifstream f(file_name);
      if (f) {
         std::string line;
         while (std::getline(f, line)) {
               std::vector<std::string> parts = coot::util::split_string_no_blanks(line, ",");
               if (parts.size() == 26) {
                  std::string dtag = parts[0];
                  pes.add_tagged_event(dtag, "event_idx",    parts[1]);
                  pes.add_tagged_event(dtag, "bdc",          parts[2]);
                  pes.add_tagged_event(dtag, "cluster_size", parts[3]);
                  pes.add_tagged_event(dtag, "global_correlation_to_average_map", parts[4]);
                  pes.add_tagged_event(dtag, "global_correlation_to_mean_map",    parts[5]);
                  pes.add_tagged_event(dtag, "local_correlation_to_average_map",  parts[6]);
                  pes.add_tagged_event(dtag, "local_correlation_to_mean_map",     parts[7]);
                  pes.add_tagged_event(dtag, "site_idx", parts[8]);
                  pes.add_tagged_event(dtag, "x",        parts[9]);
                  pes.add_tagged_event(dtag, "y",        parts[10]);
                  pes.add_tagged_event(dtag, "z",        parts[11]);
                  pes.add_tagged_event(dtag, "z_mean",   parts[12]);
                  pes.add_tagged_event(dtag, "z_peak",   parts[13]);
                  pes.add_tagged_event(dtag, "applied_b_factor_scaling", parts[14]);
                  pes.add_tagged_event(dtag, "high_resolution", parts[15]);
                  pes.add_tagged_event(dtag, "low_resolution",  parts[16]);
                  pes.add_tagged_event(dtag, "r_free",          parts[17]);
                  pes.add_tagged_event(dtag, "r_work",          parts[18]);
                  pes.add_tagged_event(dtag, "analysed_resolution", parts[19]);
                  pes.add_tagged_event(dtag, "map_uncertainty", parts[20]);
                  pes.add_tagged_event(dtag, "analysed",        parts[21]);
                  pes.add_tagged_event(dtag, "interesting",     parts[22]);
                  pes.add_tagged_event(dtag, "exclude_from_z_map_analysis",   parts[23]);
                  pes.add_tagged_event(dtag, "exclude_from_characterisation", parts[24]);
                  pes.add_tagged_event(dtag, "1-BDC", parts[25]);
               } else {
                  std::cout << "Failed to parse " << line << std::endl;
               }
         }
      }
   }
   return pes;
}

void pandda() {

   std::cout << "starting pandda inspect" << std::endl;

   std::string dtag = "0";
   pandda_event_store_t pes = parse_pandda_analyse_events("pandda_analyse_events.csv");

   auto get_float = [&](const std::string &key) -> float {
      auto s = pes.get_data(dtag, key);
      if (s) {
         try { return std::stof(s.value()); } catch (...) {}
      }
      return 0.5f;
   };

   float bdc        = get_float("1-BDC");
   float rfree      = get_float("r_free");
   float resolution = get_float("high_resolution");
   float zpeak      = get_float("z_peak");
   float map_sigma  = get_float("map_uncertainty");

   graphics_info_t g;
   g.show_pandda_inspect_hud_buttons();
   g.update_pandda_inspect_hud_stats_bars(bdc, rfree, resolution, zpeak, map_sigma);
   g.graphics_draw();
}


