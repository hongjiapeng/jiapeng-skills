# Copy this file to a private location before adding machine-specific values.
# Do not commit the populated copy to a public repository.

@{
    # Set an absolute path or a path relative to this configuration file.
    RootPath = ""

    Directories = @{
        Work = "Work"
        Personal = "Personal"
        Additional = @(
            "Lab"
            "Sandbox"
        )
        PersonalGroups = @()
    }

    Git = @{
        # Leave blank to store generated identity files in local application data.
        ConfigDirectory = ""

        # Provide both values or leave both empty.
        Personal = @{
            Name = ""
            Email = ""
        }

        # Provide both values or leave both empty.
        Work = @{
            Name = ""
            Email = ""
        }
    }

    # Add private repository records only in the copied configuration file.
    # Destination is optional and is relative to Directories.Personal.
    Repositories = @()
}
