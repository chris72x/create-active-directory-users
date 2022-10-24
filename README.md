# create-active-directory-users
Create student users in Active Directory

This script uses a csv file exported from the student information system.  The script checks if the user exist in Active Directory and if the account doesn't exist, an AD account will be created, a password will be set, the account will be placed in the appropriate OU, appropriate Group Memberships will be assigned, and logfiles will be written.

Soon to be added will be a function to send email to particular people to inform them that the accounts have been created and will include login information.
