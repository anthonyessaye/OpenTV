package com.anthonyessaye.opentv.Models

import java.io.Serializable

class CrewMember : Serializable {
    var id: Int = 0
        private set
    var job: String? = null
        private set
    var name: String? = null
        private set
    var department: String? = null
        private set
    var profile_path: String? = null
        private set

    fun setId(id: Int): CrewMember {
        this.id = id
        return this
    }

    fun setJob(job: String?): CrewMember {
        this.job = job
        return this
    }

    fun setName(name: String?): CrewMember {
        this.name = name
        return this
    }

    fun setDepartment(department: String?): CrewMember {
        this.department = department
        return this
    }

    fun setProfilePath(profile_path: String?): CrewMember {
        this.profile_path = profile_path
        return this
    }
}
