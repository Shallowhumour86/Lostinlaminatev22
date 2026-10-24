extends RefCounted
## Hand-authored, non-explicit adaptation. No Harlowe is evaluated.
const ROOMS = {
 "hotel": {"name":"01 / THE GLASS HOTEL", "subtitle":"A borrowed room. A missing past.", "color":"47818d", "size":Vector2i(9,8), "spawn":Vector2(4,5), "objects":[
  {"id":"mirror", "name":"Memory mirror", "at":Vector2(1,2), "kind":"mirror"},
  {"id":"case", "name":"Travel case", "at":Vector2(6,2), "kind":"case"},
  {"id":"concierge", "name":"Hotel concierge", "at":Vector2(6,5), "kind":"person"},
  {"id":"hotel_exit", "name":"Transit concourse", "at":Vector2(4,0), "kind":"door"}]},
 "hub": {"name":"02 / TRANSIT CONCOURSE", "subtitle":"Every journey leaves a record.", "color":"387e92", "size":Vector2i(11,9), "spawn":Vector2(5,7), "objects":[
  {"id":"isabella", "name":"Isabella · transit guide", "at":Vector2(2,3), "kind":"person"},
  {"id":"offworlder", "name":"Offworld researcher", "at":Vector2(8,3), "kind":"person"},
  {"id":"quinn", "name":"Quinn · dispatch", "at":Vector2(8,6), "kind":"person"},
  {"id":"garden_exit", "name":"Convent garden", "at":Vector2(0,5), "kind":"door"},
  {"id":"archive_exit", "name":"Civic archive", "at":Vector2(10,4), "kind":"door"},
  {"id":"terminal_exit", "name":"Way Up terminal", "at":Vector2(5,0), "kind":"door"},
  {"id":"hotel_return", "name":"Glass Hotel", "at":Vector2(5,8), "kind":"door"}]},
 "garden": {"name":"03 / THE QUIET GARDEN", "subtitle":"Some things grow beyond the city's reach.", "color":"4e927b", "size":Vector2i(9,8), "spawn":Vector2(4,6), "objects":[
  {"id":"sister", "name":"Sister Euphoria", "at":Vector2(2,3), "kind":"person"},
  {"id":"dahlia", "name":"Dahlia", "at":Vector2(6,4), "kind":"person"},
  {"id":"fountain", "name":"Reflection pool", "at":Vector2(4,2), "kind":"pool"},
  {"id":"garden_return", "name":"Transit concourse", "at":Vector2(4,7), "kind":"door"}]},
 "archive": {"name":"04 / CIVIC ARCHIVE", "subtitle":"The truth is filed under another name.", "color":"836b9f", "size":Vector2i(9,8), "spawn":Vector2(4,6), "objects":[
  {"id":"records", "name":"Identity terminal", "at":Vector2(2,2), "kind":"terminal"},
  {"id":"parcel", "name":"Research dropbox", "at":Vector2(6,3), "kind":"case"},
  {"id":"malice", "name":"Malice · archivist", "at":Vector2(6,5), "kind":"person"},
  {"id":"archive_return", "name":"Transit concourse", "at":Vector2(4,7), "kind":"door"}]},
 "terminal": {"name":"05 / THE WAY UP", "subtitle":"Above the stack clouds, a new beginning.", "color":"ad8059", "size":Vector2i(10,8), "spawn":Vector2(5,6), "objects":[
  {"id":"cor", "name":"Cor · departures", "at":Vector2(2,3), "kind":"person"},
  {"id":"embassy", "name":"Embassy uplink", "at":Vector2(7,4), "kind":"terminal"},
  {"id":"lift", "name":"Orbital elevator", "at":Vector2(5,0), "kind":"lift"},
  {"id":"terminal_return", "name":"Transit concourse", "at":Vector2(5,7), "kind":"door"}]}
}
const ROUTES = {"hotel_exit":"hub", "hotel_return":"hotel", "garden_exit":"garden", "archive_exit":"archive", "terminal_exit":"terminal", "garden_return":"hub", "archive_return":"hub", "terminal_return":"hub"}
