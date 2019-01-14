# Created on 03/23/2018 by Christopher Christiansen.
# This script uses the file exported from our Student Information Systemv (SIS), W:\StudentsFile.csv" and
# checks the SIS login name to see if the name already
# exists in Active Directory.  If it doesn't already exist, a new account 
# is created, the student is placed in the appropriate OUs, and the student
# is created as a member of the appropriate groups.  There are two logfiles -
# one records if an AD account was created, the other records if an AD was 
# not created.

(Import-Module ActiveDirectory)

# Arrays

    $SchoolNameArray = @{
        "100"  = "Elementary School 1"; # Elementary School 1
        "200"  = "Elementary School 2"; # Elementary School 2
        "300"  = "Elementary School 3"; # Elementary School 3
        "400"  = "Middle School";       # Middle School
        "500"  = "High School";         # High School
    }

    $SecondaryPrimaryArray = @{
        "100"  = "Elementary";          # Elementary School 1
        "200"  = "Elementary";          # Elementary School 2
        "300"  = "Elementary";          # Elementary School 3
        "400"  = "Secondary";           # Middle School
        "500"  = "Secondary";           # High School
    }
    $groupMembershipArray1 = @{
  
        "100"  = "ElemSchool1";         # Elementary School 1
        "200"  = "ElemSchool2";         # Elementary School 2
        "300"  = "ElemSchool3";         # Elementary School 3
        "400"  = "Middle School";       # Middle School
        "500"  = "High School";         # High School
  
    }

# Actions

    $SourceFile = ("W:\StudentsFile.csv")
    $csv = Import-Csv $SourceFile

    foreach($_ in $csv) {

       $CheckSamAccountName = $_."Stu Acces Login"
        
        function CheckIfADUserExists {
            $Check = $(try{Get-ADUser $CheckSamAccountName} catch {$null})
            if ($Check -ne $Null)
                {
                $UserExists = $true
                }

            else {
                $UserExists = $false
                }
            return $UserExists
        }
        function CreateUserAccount {

            $StuAccessLogin = $_."Stu Acces Login"
            $StuAccessLogin = ($StuAccessLogin.substring(0,2)).ToUpper()+($StuAccessLogin.substring(2)).ToLower()  
            $Name = $StuAccessLogin                                                                                     # ASmith28
            $GivenName = $_."Stu First Name"                                                                            # Alex
            $Surname = $_."Stu Last Name"                                                                               # Smith
            $DisplayName = $Name                                                                                        # ASmith28
            $UserPrincipalName = ($Name + "@our.school.org")                                                            # ASmith28@our.school.org
            $EmailAddress = ($Name + "@our.school.org")                                                                 # ASmith28@our.school.org
#            $firstPwd = ($GivenName.substring(0,1)).ToLower()+($Surname.substring(0,1)).ToLower()                      # as
#               OR
#            $firstPwd = $_."LocalID"                                                                                   # 1234567 (seven digit LocalID)
#               OR
#            $firstPwd = "generic_password"                                                                             # generic_password
            $PASID = $_."StateStuNum"
            $SamAccountName = $Name                                                                                     # ASmith28
            $Desciption = "Student"                                                                                     # Student
            $ScriptPath = "logon.bat"                                                                                   # logon.bat
            $SchoolOU = $SchoolNameArray[$_."School Code"]                                                              # Elementary School 1
            $SecondaryPrimaryOU = $SecondaryPrimaryArray[$_."School Code"]                                              # Elementary
            $Path = ("OU="+$_."Stu Grad Yr"+",OU="+$SchoolOU+",OU="+$SecondaryPrimaryOU+",OU=Students,OU=Members,DC=Ourschool,DC=k12,DC=st,DC=us") # "OU=2028,OU=ElementarySchool1,OU=Elementary,OU=Students,OU=Members,DC=Ourschool,DC=k12,DC=st,DC=us"
            $GroupMembership1 = $groupMembershipArray1[$_."School Code"]                                                # MCKStudent
            $GroupMembership3 = "HS Students"                                                                           # HS Students

            if ($_."School Code" -eq 500 -or $_."School Code" -eq 400) {
                $CannotChangePassword = $false
                $ChangePasswordAtLogon = $true
                $PasswordNeverExpires = $false
                } else {                
                $CannotChangePassword = $true
                $ChangePasswordAtLogon = $false
                $PasswordNeverExpires = $true
            }


            switch ($_."School Code")
            {
                100 { $Groups = $GroupMembership1 }
                200 { $Groups = $GroupMembership1 }
                300 { $Groups = $GroupMembership1 }
                400 { $Groups = $GroupMembership1 }
                500 { $Groups = $GroupMembership1, $GroupMembership3 }
            }

            switch ($_."Student Grade")
            {
                "KG" { $firstPwd = ($GivenName.substring(0,1)).ToLower()+($Surname.substring(0,1)).ToLower() }
                "09" { $firstPwd = "Welcome1" }
                "10" { $firstPwd = "Welcome1" }
                "11" { $firstPwd = "Welcome1" }
                "12" { $firstPwd = "Welcome1" }
                default { $firstPwd = $PASID }
            }

            New-ADUser -Name $Name `
                -GivenName $GivenName `
                -Surname $Surname `
                -DisplayName $DisplayName `
                -UserPrincipalName ($UserPrincipalName) `
                -SamAccountName $SamAccountName `
                -EmailAddress $EmailAddress `
                -AccountPassword (ConvertTo-SecureString $firstPwd -AsPlainText -Force) `
                -CannotChangePassword $CannotChangePassword `
                -PasswordNeverExpires $PasswordNeverExpires `
                -ChangePasswordAtLogon $ChangePasswordAtLogon `
                -Enabled $true `
                -Description $Desciption `
                -ScriptPath $ScriptPath `
                -Path $Path `
                -Server main-server-1 `
                -PassThru | Add-ADPrincipalGroupMembership `
                -MemberOf $Groups

               Write-Host "Username:"$Name", Password: "$firstPwd
               Write-Host "Groups:"$Groups
        }

        function PropogateUserToOtherDCs {
        
            $UserToPush = $_."Stu Acces Login"

            Get-ADUser -Identity $UserToPush -server main-server-1 | Sync-ADObject -Destination elementary-server-1
            Get-ADUser -Identity $UserToPush -server main-server-1 | Sync-ADObject -Destination elementary-server-2
            Get-ADUser -Identity $UserToPush -server main-server-1 | Sync-ADObject -Destination elementary-server-3

            Write-Host $UserToPush "has been propogated to elementary-server-1, elementary-server-2, and elementary-server-3."
        }

        function CreateHomeFolder {
            
            $StuAccessLogin = $_."Stu Acces Login"
            $StuAccessLogin = ($StuAccessLogin.substring(0,2)).ToUpper()+($StuAccessLogin.substring(2)).ToLower()  
            $Name = $StuAccessLogin
            $StuGradYr = $_."Stu Grad Yr"

            $HomeFolder = switch ($_."School Code")
            {
                100 { ("\\elementary-server-1\Students\"+$Name) }
                200 { ("\\elementary-server-2\Students\"+$Name) }
                300 { ("\\elementary-server-3\Students\"+$Name) }
                400 { ("\\middleschool-server\Students\"+$Name) }
                500 { ("\\highschool-server\Students\"+$Name) }
            }

            New-Item -ItemType Directory -Path $HomeFolder
            $User = $StuAccessLogin
            $Acl = Get-Acl $HomeFolder
            $Ar = New-Object  system.security.accesscontrol.filesystemaccessrule("$User","Modify","ContainerInherit, ObjectInherit","none","Allow")
            $Acl.SetAccessRule($Ar)
            Set-Acl $HomeFolder $Acl
            
            Write-Host "Home folder for"$HomeFolder" created."
        }


        function LogFileUserCreated {
            $exportlocation = "C:\Logfiles\UsersCreated.csv"
            $LogDate = Get-Date -Format g
            $UserName = $_."Stu Acces Login"
            $FirstName = $_."Stu First Name"
            $LastName = $_."Stu Last Name"
            $SchoolName = $_."School Name"

            $Text = $LogDate + ", " + $UserName + ", " + $FirstName + ", " + $LastName + ", " + $SchoolName

            Add-Content -Path $exportlocation -Value $Text

            Write-Host $UserName" User account created"}

        function LogFileUserNotCreated {
            $exportlocation = "C:\Logfiles\UsersNOTCreated.csv"
            $LogDate = Get-Date -Format g
            $UserName = $_."Stu Acces Login"
            $FirstName = $_."Stu First Name"
            $LastName = $_."Stu Last Name"
            $SchoolName = $_."School Name"

            $Text = $LogDate + ", " + $UserName + ", " + $FirstName + ", " + $LastName + ", " + $SchoolName

            Add-Content -Path $exportlocation -Value $Text

            Write-Host $UserName" User account NOT created"}

        if (CheckIfADUserExists){
            LogFileUserNotCreated

        }

       else {
            
            CreateUserAccount
            PropogateUserToOtherDCs
            CreateHomeFolder
            LogFileUserCreated
 
        }
    }
