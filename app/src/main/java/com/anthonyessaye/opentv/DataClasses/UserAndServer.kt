package com.anthonyessaye.opentv.DataClasses

import com.anthonyessaye.opentv.Persistence.Server.Server
import com.anthonyessaye.opentv.Persistence.User.User

// Using this to make parsing data from the backend easier
// Later on might add functionality to parse server data
// However I don't feel I need it atm.
data class UserAndServer(var user_info: User, var server_info: Server)